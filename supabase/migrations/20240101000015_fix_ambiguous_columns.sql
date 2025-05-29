-- Drop existing trigger and function
DROP TRIGGER IF EXISTS update_follower_counts_trigger ON follows;
DROP FUNCTION IF EXISTS update_follower_counts();

-- Create improved function with explicit column references
CREATE OR REPLACE FUNCTION update_follower_counts()
RETURNS TRIGGER AS $$
DECLARE
  new_followers_count INTEGER;
  new_following_count INTEGER;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Get accurate counts using explicit table references
    SELECT COUNT(*) INTO new_followers_count
    FROM follows f
    WHERE f.following_id = NEW.following_id;

    SELECT COUNT(*) INTO new_following_count
    FROM follows f
    WHERE f.follower_id = NEW.follower_id;

    -- Update both counts without column prefix in SET clause
    UPDATE profiles p
    SET followers_count = new_followers_count
    WHERE p.id = NEW.following_id;

    UPDATE profiles p
    SET following_count = new_following_count
    WHERE p.id = NEW.follower_id;

  ELSIF TG_OP = 'DELETE' THEN
    -- Get accurate counts using explicit table references
    SELECT COUNT(*) INTO new_followers_count
    FROM follows f
    WHERE f.following_id = OLD.following_id;

    SELECT COUNT(*) INTO new_following_count
    FROM follows f
    WHERE f.follower_id = OLD.follower_id;

    -- Update both counts without column prefix in SET clause
    UPDATE profiles p
    SET followers_count = new_followers_count
    WHERE p.id = OLD.following_id;

    UPDATE profiles p
    SET following_count = new_following_count
    WHERE p.id = OLD.follower_id;
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