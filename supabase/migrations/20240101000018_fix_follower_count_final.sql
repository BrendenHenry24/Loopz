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
    UPDATE profiles 
    SET followers_count = (
      SELECT COUNT(*) FROM follows WHERE following_id = NEW.following_id
    )
    WHERE id = NEW.following_id;

    UPDATE profiles 
    SET following_count = (
      SELECT COUNT(*) FROM follows WHERE follower_id = NEW.follower_id
    )
    WHERE id = NEW.follower_id;

  ELSIF TG_OP = 'DELETE' THEN
    UPDATE profiles 
    SET followers_count = (
      SELECT COUNT(*) FROM follows WHERE following_id = OLD.following_id
    )
    WHERE id = OLD.following_id;

    UPDATE profiles 
    SET following_count = (
      SELECT COUNT(*) FROM follows WHERE follower_id = OLD.follower_id
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

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';