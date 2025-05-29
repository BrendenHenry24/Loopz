-- Drop existing trigger and function
DROP TRIGGER IF EXISTS update_follower_counts_trigger ON follows;
DROP FUNCTION IF EXISTS update_follower_counts();

-- Create an improved function to handle follower counts
CREATE OR REPLACE FUNCTION update_follower_counts()
RETURNS TRIGGER AS $$
DECLARE
  followers_count INTEGER;
  following_count INTEGER;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Get accurate count for followers
    SELECT COUNT(*) INTO followers_count
    FROM follows
    WHERE following_id = NEW.following_id;

    -- Get accurate count for following
    SELECT COUNT(*) INTO following_count
    FROM follows
    WHERE follower_id = NEW.follower_id;

    -- Update both counts atomically
    UPDATE profiles 
    SET followers_count = followers_count
    WHERE id = NEW.following_id;

    UPDATE profiles 
    SET following_count = following_count
    WHERE id = NEW.follower_id;

  ELSIF TG_OP = 'DELETE' THEN
    -- Get accurate count for followers after deletion
    SELECT COUNT(*) INTO followers_count
    FROM follows
    WHERE following_id = OLD.following_id;

    -- Get accurate count for following after deletion
    SELECT COUNT(*) INTO following_count
    FROM follows
    WHERE follower_id = OLD.follower_id;

    -- Update both counts atomically
    UPDATE profiles 
    SET followers_count = followers_count
    WHERE id = OLD.following_id;

    UPDATE profiles 
    SET following_count = following_count
    WHERE id = OLD.follower_id;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
CREATE TRIGGER update_follower_counts_trigger
AFTER INSERT OR DELETE ON follows
FOR EACH ROW
EXECUTE FUNCTION update_follower_counts();

-- Function to fix any existing incorrect counts
CREATE OR REPLACE FUNCTION fix_all_follower_counts()
RETURNS void AS $$
BEGIN
  -- Update all profiles with accurate counts
  UPDATE profiles p
  SET 
    followers_count = (
      SELECT COUNT(*)
      FROM follows f
      WHERE f.following_id = p.id
    ),
    following_count = (
      SELECT COUNT(*)
      FROM follows f
      WHERE f.follower_id = p.id
    );
END;
$$ LANGUAGE plpgsql;

-- Run an immediate fix
SELECT fix_all_follower_counts();

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';