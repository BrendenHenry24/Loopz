-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS update_follower_counts_trigger ON follows;
DROP FUNCTION IF EXISTS update_follower_counts();

-- Create a simplified, atomic function to update follower counts
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
  
  -- Update all profiles with accurate counts
  UPDATE profiles p
  SET 
    followers_count = COALESCE((
      SELECT COUNT(*)
      FROM follows f
      WHERE f.following_id = p.id
    ), 0),
    following_count = COALESCE((
      SELECT COUNT(*)
      FROM follows f
      WHERE f.follower_id = p.id
    ), 0);
END;
$$ LANGUAGE plpgsql;

-- Run the fix
SELECT fix_all_follower_counts();

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';