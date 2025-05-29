-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS update_follower_counts_trigger ON follows;
DROP FUNCTION IF EXISTS update_follower_counts();
DROP FUNCTION IF EXISTS fix_all_follower_counts();

-- Create a more robust function to update follower counts
CREATE OR REPLACE FUNCTION update_follower_counts()
RETURNS TRIGGER AS $$
DECLARE
  new_followers_count INTEGER;
  new_following_count INTEGER;
BEGIN
  -- Lock the profiles table to prevent concurrent updates
  LOCK TABLE profiles IN SHARE ROW EXCLUSIVE MODE;
  
  IF TG_OP = 'INSERT' THEN
    -- Get accurate counts after insert
    SELECT COUNT(*) INTO STRICT new_followers_count
    FROM follows
    WHERE following_id = NEW.following_id;

    SELECT COUNT(*) INTO STRICT new_following_count
    FROM follows
    WHERE follower_id = NEW.follower_id;

    -- Update the followed user's followers count
    UPDATE profiles
    SET followers_count = new_followers_count
    WHERE id = NEW.following_id;

    -- Update the follower's following count
    UPDATE profiles
    SET following_count = new_following_count
    WHERE id = NEW.follower_id;

  ELSIF TG_OP = 'DELETE' THEN
    -- Get accurate counts after delete
    SELECT COUNT(*) INTO STRICT new_followers_count
    FROM follows
    WHERE following_id = OLD.following_id;

    SELECT COUNT(*) INTO STRICT new_following_count
    FROM follows
    WHERE follower_id = OLD.follower_id;

    -- Update the unfollowed user's followers count
    UPDATE profiles
    SET followers_count = new_followers_count
    WHERE id = OLD.following_id;

    -- Update the unfollower's following count
    UPDATE profiles
    SET following_count = new_following_count
    WHERE id = OLD.follower_id;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER update_follower_counts_trigger
AFTER INSERT OR DELETE ON follows
FOR EACH ROW
EXECUTE FUNCTION update_follower_counts();

-- Function to fix all follower counts
CREATE OR REPLACE FUNCTION fix_all_follower_counts()
RETURNS void AS $$
BEGIN
  -- Lock the profiles table
  LOCK TABLE profiles IN SHARE ROW EXCLUSIVE MODE;
  
  -- Reset all counts first
  UPDATE profiles SET followers_count = 0, following_count = 0;
  
  -- Update all counts in a single transaction
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
END;
$$ LANGUAGE plpgsql;

-- Run the fix
SELECT fix_all_follower_counts();

-- Add constraints and indexes if they don't exist
DO $$ 
BEGIN
  -- Add constraint to prevent self-following if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 
    FROM pg_constraint 
    WHERE conname = 'prevent_self_following'
  ) THEN
    ALTER TABLE follows
    ADD CONSTRAINT prevent_self_following
    CHECK (follower_id != following_id);
  END IF;

  -- Add unique constraint if it doesn't exist
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'follows_unique_pair'
  ) THEN
    ALTER TABLE follows
    ADD CONSTRAINT follows_unique_pair
    UNIQUE (follower_id, following_id);
  END IF;
END $$;

-- Create or replace indexes
DROP INDEX IF EXISTS idx_follows_follower;
DROP INDEX IF EXISTS idx_follows_following;
CREATE INDEX idx_follows_follower ON follows(follower_id);
CREATE INDEX idx_follows_following ON follows(following_id);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';