-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS update_follower_counts_trigger ON follows;
DROP FUNCTION IF EXISTS update_follower_counts();
DROP FUNCTION IF EXISTS fix_all_follower_counts();

-- Create a simplified, atomic function to update follower counts
CREATE OR REPLACE FUNCTION update_follower_counts()
RETURNS TRIGGER AS $$
BEGIN
  -- Lock the profiles table to prevent race conditions
  LOCK TABLE profiles IN SHARE ROW EXCLUSIVE MODE;

  IF TG_OP = 'INSERT' THEN
    -- Update followers count for the person being followed
    WITH follower_count AS (
      SELECT COUNT(*) as count
      FROM follows
      WHERE following_id = NEW.following_id
    )
    UPDATE profiles 
    SET followers_count = follower_count.count
    FROM follower_count
    WHERE id = NEW.following_id;

    -- Update following count for the follower
    WITH following_count AS (
      SELECT COUNT(*) as count
      FROM follows
      WHERE follower_id = NEW.follower_id
    )
    UPDATE profiles 
    SET following_count = following_count.count
    FROM following_count
    WHERE id = NEW.follower_id;

  ELSIF TG_OP = 'DELETE' THEN
    -- Update followers count for the person being unfollowed
    WITH follower_count AS (
      SELECT COUNT(*) as count
      FROM follows
      WHERE following_id = OLD.following_id
    )
    UPDATE profiles 
    SET followers_count = follower_count.count
    FROM follower_count
    WHERE id = OLD.following_id;

    -- Update following count for the unfollower
    WITH following_count AS (
      SELECT COUNT(*) as count
      FROM follows
      WHERE follower_id = OLD.follower_id
    )
    UPDATE profiles 
    SET following_count = following_count.count
    FROM following_count
    WHERE id = OLD.follower_id;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER update_follower_counts_trigger
AFTER INSERT OR DELETE ON follows
FOR EACH ROW
EXECUTE FUNCTION update_follower_counts();

-- Function to fix any existing incorrect counts
CREATE OR REPLACE FUNCTION fix_all_follower_counts()
RETURNS void AS $$
BEGIN
  -- Lock the profiles table
  LOCK TABLE profiles IN SHARE ROW EXCLUSIVE MODE;
  
  -- Update all profiles with accurate counts using CTEs
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

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';