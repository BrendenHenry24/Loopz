-- Drop existing trigger and function
DROP TRIGGER IF EXISTS update_follower_counts_trigger ON follows;
DROP FUNCTION IF EXISTS update_follower_counts();

-- Create improved function to update follower counts
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

-- Create trigger for follower count updates
CREATE TRIGGER update_follower_counts_trigger
AFTER INSERT OR DELETE ON follows
FOR EACH ROW
EXECUTE FUNCTION update_follower_counts();

-- Function to recalculate all follower counts
CREATE OR REPLACE FUNCTION recalculate_follower_counts()
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

-- Run initial recalculation
SELECT recalculate_follower_counts();