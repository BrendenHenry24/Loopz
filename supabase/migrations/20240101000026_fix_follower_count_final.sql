-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS update_follower_counts_trigger ON follows;
DROP FUNCTION IF EXISTS update_follower_counts();

-- Create a robust function to update follower counts
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
      SELECT COUNT(*) INTO STRICT _followers_count
      FROM follows
      WHERE following_id = NEW.following_id;

      SELECT COUNT(*) INTO STRICT _following_count
      FROM follows
      WHERE follower_id = NEW.follower_id;

      -- Update counts atomically
      UPDATE profiles 
      SET followers_count = _followers_count
      WHERE id = NEW.following_id;

      UPDATE profiles 
      SET following_count = _following_count
      WHERE id = NEW.follower_id;

    ELSIF TG_OP = 'DELETE' THEN
      -- Get accurate counts after delete
      SELECT COUNT(*) INTO STRICT _followers_count
      FROM follows
      WHERE following_id = OLD.following_id;

      SELECT COUNT(*) INTO STRICT _following_count
      FROM follows
      WHERE follower_id = OLD.follower_id;

      -- Update counts atomically
      UPDATE profiles 
      SET followers_count = _followers_count
      WHERE id = OLD.following_id;

      UPDATE profiles 
      SET following_count = _following_count
      WHERE id = OLD.follower_id;
    END IF;

    RETURN NULL;
  EXCEPTION 
    WHEN OTHERS THEN
      RAISE EXCEPTION 'Error in update_follower_counts: %', SQLERRM;
  END;
END;
$$ LANGUAGE plpgsql;

-- Create trigger with immediate timing
CREATE TRIGGER update_follower_counts_trigger
AFTER INSERT OR DELETE ON follows
FOR EACH ROW
EXECUTE FUNCTION update_follower_counts();

-- Clean up any invalid data
DELETE FROM follows
WHERE follower_id IS NULL 
   OR following_id IS NULL
   OR follower_id = following_id;

-- Reset and recompute all follower counts
UPDATE profiles SET followers_count = 0, following_count = 0;

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

-- Add constraints and indexes
ALTER TABLE follows DROP CONSTRAINT IF EXISTS prevent_self_following;
ALTER TABLE follows ADD CONSTRAINT prevent_self_following CHECK (follower_id != following_id);

DROP INDEX IF EXISTS idx_follows_composite;
CREATE UNIQUE INDEX idx_follows_composite ON follows(follower_id, following_id);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';