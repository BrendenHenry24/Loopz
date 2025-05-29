-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS update_follower_counts_trigger ON follows;
DROP FUNCTION IF EXISTS update_follower_counts();
DROP FUNCTION IF EXISTS recalculate_follower_counts();

-- Create improved function to update follower counts
CREATE OR REPLACE FUNCTION update_follower_counts()
RETURNS TRIGGER AS $$
DECLARE
  _followers_count INTEGER;
  _following_count INTEGER;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Get current followers count
    SELECT COUNT(*) INTO _followers_count
    FROM follows
    WHERE following_id = NEW.following_id;
    
    -- Get current following count
    SELECT COUNT(*) INTO _following_count
    FROM follows
    WHERE follower_id = NEW.follower_id;
    
    -- Update followers count
    UPDATE profiles 
    SET followers_count = _followers_count
    WHERE id = NEW.following_id;
    
    -- Update following count
    UPDATE profiles 
    SET following_count = _following_count
    WHERE id = NEW.follower_id;
    
  ELSIF TG_OP = 'DELETE' THEN
    -- Get current followers count
    SELECT COUNT(*) INTO _followers_count
    FROM follows
    WHERE following_id = OLD.following_id;
    
    -- Get current following count
    SELECT COUNT(*) INTO _following_count
    FROM follows
    WHERE follower_id = OLD.follower_id;
    
    -- Update followers count
    UPDATE profiles 
    SET followers_count = _followers_count
    WHERE id = OLD.following_id;
    
    -- Update following count
    UPDATE profiles 
    SET following_count = _following_count
    WHERE id = OLD.follower_id;
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for follower count updates
CREATE TRIGGER update_follower_counts_trigger
AFTER INSERT OR DELETE ON follows
FOR EACH ROW
EXECUTE FUNCTION update_follower_counts();

-- Add constraint to prevent self-following
ALTER TABLE follows
ADD CONSTRAINT prevent_self_following
CHECK (follower_id != following_id);

-- Function to fix any existing follower counts
CREATE OR REPLACE FUNCTION fix_follower_counts()
RETURNS void AS $$
BEGIN
  -- Update followers_count for all profiles
  UPDATE profiles p
  SET followers_count = (
    SELECT COUNT(*)
    FROM follows f
    WHERE f.following_id = p.id
  );
  
  -- Update following_count for all profiles
  UPDATE profiles p
  SET following_count = (
    SELECT COUNT(*)
    FROM follows f
    WHERE f.follower_id = p.id
  );
END;
$$ LANGUAGE plpgsql;

-- Run the fix
SELECT fix_follower_counts();

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';