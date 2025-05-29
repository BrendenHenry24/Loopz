-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS update_follower_counts_trigger ON follows;
DROP FUNCTION IF EXISTS update_follower_counts();
DROP FUNCTION IF EXISTS fix_all_follower_counts();

-- Create a simplified, reliable function to update follower counts
CREATE OR REPLACE FUNCTION update_follower_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Increment counts
    UPDATE profiles 
    SET followers_count = followers_count + 1
    WHERE id = NEW.following_id;

    UPDATE profiles 
    SET following_count = following_count + 1
    WHERE id = NEW.follower_id;

  ELSIF TG_OP = 'DELETE' THEN
    -- Decrement counts
    UPDATE profiles 
    SET followers_count = GREATEST(0, followers_count - 1)
    WHERE id = OLD.following_id;

    UPDATE profiles 
    SET following_count = GREATEST(0, following_count - 1)
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

-- Function to reset and recalculate all counts
CREATE OR REPLACE FUNCTION fix_all_follower_counts()
RETURNS void AS $$
BEGIN
  -- Reset all counts to 0
  UPDATE profiles SET followers_count = 0, following_count = 0;
  
  -- Update followers_count
  UPDATE profiles p
  SET followers_count = (
    SELECT COUNT(*)
    FROM follows f
    WHERE f.following_id = p.id
  );
  
  -- Update following_count
  UPDATE profiles p
  SET following_count = (
    SELECT COUNT(*)
    FROM follows f
    WHERE f.follower_id = p.id
  );
END;
$$ LANGUAGE plpgsql;

-- Run the fix
SELECT fix_all_follower_counts();

-- Ensure constraints exist
ALTER TABLE follows DROP CONSTRAINT IF EXISTS prevent_self_following;
ALTER TABLE follows ADD CONSTRAINT prevent_self_following CHECK (follower_id != following_id);

ALTER TABLE follows DROP CONSTRAINT IF EXISTS follows_unique_pair;
ALTER TABLE follows ADD CONSTRAINT follows_unique_pair UNIQUE (follower_id, following_id);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';