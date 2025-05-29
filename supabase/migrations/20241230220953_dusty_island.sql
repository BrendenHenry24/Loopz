-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS update_follower_counts_trigger ON follows;
DROP FUNCTION IF EXISTS update_follower_counts();

-- Create improved function to update follower counts
CREATE OR REPLACE FUNCTION update_follower_counts()
RETURNS TRIGGER AS $$
BEGIN
  -- Lock the profiles table to prevent race conditions
  LOCK TABLE profiles IN SHARE ROW EXCLUSIVE MODE;

  IF TG_OP = 'INSERT' THEN
    -- Update followers count for the person being followed
    UPDATE profiles 
    SET followers_count = (
      SELECT COUNT(*)
      FROM follows
      WHERE following_id = NEW.following_id
    )
    WHERE id = NEW.following_id;

    -- Update following count for the follower
    UPDATE profiles 
    SET following_count = (
      SELECT COUNT(*)
      FROM follows
      WHERE follower_id = NEW.follower_id
    )
    WHERE id = NEW.follower_id;

  ELSIF TG_OP = 'DELETE' THEN
    -- Update followers count for the person being unfollowed
    UPDATE profiles 
    SET followers_count = (
      SELECT COUNT(*)
      FROM follows
      WHERE following_id = OLD.following_id
    )
    WHERE id = OLD.following_id;

    -- Update following count for the unfollower
    UPDATE profiles 
    SET following_count = (
      SELECT COUNT(*)
      FROM follows
      WHERE follower_id = OLD.follower_id
    )
    WHERE id = OLD.follower_id;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for all follow changes
CREATE TRIGGER update_follower_counts_trigger
AFTER INSERT OR DELETE ON follows
FOR EACH ROW
EXECUTE FUNCTION update_follower_counts();

-- Reset and recalculate all follower counts
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

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';