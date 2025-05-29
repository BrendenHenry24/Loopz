-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS update_follower_counts_trigger ON follows;
DROP FUNCTION IF EXISTS update_follower_counts();

-- Create improved function to update follower counts
CREATE OR REPLACE FUNCTION update_follower_counts()
RETURNS TRIGGER AS $$
DECLARE
  _followers_count INTEGER;
  _following_count INTEGER;
BEGIN
  -- Start a transaction block
  BEGIN
    IF TG_OP = 'INSERT' THEN
      -- Lock the relevant rows
      PERFORM pg_advisory_xact_lock(hashtext('follower_count_lock' || NEW.follower_id::text));
      PERFORM pg_advisory_xact_lock(hashtext('follower_count_lock' || NEW.following_id::text));

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
      -- Lock the relevant rows
      PERFORM pg_advisory_xact_lock(hashtext('follower_count_lock' || OLD.follower_id::text));
      PERFORM pg_advisory_xact_lock(hashtext('follower_count_lock' || OLD.following_id::text));

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
  EXCEPTION WHEN OTHERS THEN
    -- Log error and re-raise
    RAISE EXCEPTION 'Error updating follower counts: %', SQLERRM;
  END;
END;
$$ LANGUAGE plpgsql;

-- Create trigger with immediate timing
CREATE TRIGGER update_follower_counts_trigger
AFTER INSERT OR DELETE ON follows
FOR EACH ROW
EXECUTE FUNCTION update_follower_counts();

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

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_follows_follower ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_id);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';