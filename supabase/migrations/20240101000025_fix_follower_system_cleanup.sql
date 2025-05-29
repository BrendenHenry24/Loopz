-- First, clean up any invalid follows records
DELETE FROM follows
WHERE follower_id IS NULL 
   OR following_id IS NULL
   OR follower_id = following_id;

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS update_follower_counts_trigger ON follows;
DROP FUNCTION IF EXISTS update_follower_counts();

-- Create improved function with better error handling
CREATE OR REPLACE FUNCTION update_follower_counts()
RETURNS TRIGGER AS $$
DECLARE
  _followers_count INTEGER;
  _following_count INTEGER;
BEGIN
  -- Start a transaction block
  BEGIN
    IF TG_OP = 'INSERT' THEN
      -- Get accurate counts after insert
      SELECT COUNT(*) INTO _followers_count
      FROM follows
      WHERE following_id = NEW.following_id;

      SELECT COUNT(*) INTO _following_count
      FROM follows
      WHERE follower_id = NEW.follower_id;

      -- Update counts with explicit locking
      UPDATE profiles 
      SET followers_count = _followers_count
      WHERE id = NEW.following_id;

      UPDATE profiles 
      SET following_count = _following_count
      WHERE id = NEW.follower_id;

    ELSIF TG_OP = 'DELETE' THEN
      -- Get accurate counts after delete
      SELECT COUNT(*) INTO _followers_count
      FROM follows
      WHERE following_id = OLD.following_id;

      SELECT COUNT(*) INTO _following_count
      FROM follows
      WHERE follower_id = OLD.follower_id;

      -- Update counts with explicit locking
      UPDATE profiles 
      SET followers_count = _followers_count
      WHERE id = OLD.following_id;

      UPDATE profiles 
      SET following_count = _following_count
      WHERE id = OLD.follower_id;
    END IF;

    RETURN NULL;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Error in update_follower_counts: %', SQLERRM;
  END;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER update_follower_counts_trigger
AFTER INSERT OR DELETE ON follows
FOR EACH ROW
EXECUTE FUNCTION update_follower_counts();

-- Reset all follower counts to ensure accuracy
UPDATE profiles SET followers_count = 0, following_count = 0;

-- Recompute all follower counts from scratch
WITH follower_counts AS (
  SELECT 
    following_id as user_id,
    COUNT(*) as followers
  FROM follows
  GROUP BY following_id
),
following_counts AS (
  SELECT 
    follower_id as user_id,
    COUNT(*) as following
  FROM follows
  GROUP BY follower_id
)
UPDATE profiles p
SET 
  followers_count = COALESCE(f.followers, 0),
  following_count = COALESCE(g.following, 0)
FROM 
  follower_counts f
  FULL OUTER JOIN following_counts g ON f.user_id = g.user_id
WHERE 
  p.id = COALESCE(f.user_id, g.user_id);

-- Add constraints to prevent invalid data
ALTER TABLE follows
DROP CONSTRAINT IF EXISTS prevent_self_following;

ALTER TABLE follows
ADD CONSTRAINT prevent_self_following 
CHECK (follower_id != following_id);

-- Create indexes for better performance
DROP INDEX IF EXISTS idx_follows_follower;
DROP INDEX IF EXISTS idx_follows_following;
DROP INDEX IF EXISTS idx_follows_composite;

CREATE INDEX idx_follows_composite ON follows(follower_id, following_id);
CREATE INDEX idx_follows_follower ON follows(follower_id);
CREATE INDEX idx_follows_following ON follows(following_id);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';