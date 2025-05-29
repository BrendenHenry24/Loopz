-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS update_follower_counts_trigger ON follows;
DROP FUNCTION IF EXISTS update_follower_counts();
DROP FUNCTION IF EXISTS fix_follower_counts();

-- Create a more robust function to update follower counts
CREATE OR REPLACE FUNCTION update_follower_counts()
RETURNS TRIGGER AS $$
BEGIN
  -- For inserts, increment both counters
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
    
  -- For deletes, decrement both counters
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

-- Create the trigger
CREATE TRIGGER update_follower_counts_trigger
AFTER INSERT OR DELETE ON follows
FOR EACH ROW
EXECUTE FUNCTION update_follower_counts();

-- Make sure the follows table has the proper primary key and constraints
ALTER TABLE follows 
DROP CONSTRAINT IF EXISTS follows_pkey CASCADE;

ALTER TABLE follows
ADD PRIMARY KEY (follower_id, following_id);

-- Ensure no self-follows
ALTER TABLE follows
DROP CONSTRAINT IF EXISTS prevent_self_following;

ALTER TABLE follows
ADD CONSTRAINT prevent_self_following
CHECK (follower_id != following_id);

-- Function to fix any existing counts
CREATE OR REPLACE FUNCTION fix_all_follower_counts()
RETURNS void AS $$
BEGIN
  -- Reset all counts first
  UPDATE profiles SET followers_count = 0, following_count = 0;
  
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
SELECT fix_all_follower_counts();

-- Create indexes for better performance
DROP INDEX IF EXISTS idx_follows_follower;
DROP INDEX IF EXISTS idx_follows_following;

CREATE INDEX idx_follows_follower ON follows(follower_id);
CREATE INDEX idx_follows_following ON follows(following_id);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';