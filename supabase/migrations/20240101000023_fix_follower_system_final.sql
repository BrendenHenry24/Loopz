-- Drop existing trigger and function
DROP TRIGGER IF EXISTS update_follower_counts_trigger ON follows;
DROP FUNCTION IF EXISTS update_follower_counts();

-- Create an improved function with explicit transaction handling
CREATE OR REPLACE FUNCTION update_follower_counts()
RETURNS TRIGGER AS $$
BEGIN
  -- Start a transaction block
  BEGIN
    -- Lock the relevant rows in the profiles table
    PERFORM id 
    FROM profiles 
    WHERE id IN (
      CASE 
        WHEN TG_OP = 'INSERT' THEN 
          array[NEW.follower_id, NEW.following_id]
        ELSE 
          array[OLD.follower_id, OLD.following_id]
      END
    )
    FOR UPDATE;

    IF TG_OP = 'INSERT' THEN
      -- Update followers count atomically
      UPDATE profiles 
      SET followers_count = (
        SELECT COUNT(*) 
        FROM follows 
        WHERE following_id = NEW.following_id
      )
      WHERE id = NEW.following_id;

      -- Update following count atomically
      UPDATE profiles 
      SET following_count = (
        SELECT COUNT(*) 
        FROM follows 
        WHERE follower_id = NEW.follower_id
      )
      WHERE id = NEW.follower_id;

    ELSIF TG_OP = 'DELETE' THEN
      -- Update followers count atomically
      UPDATE profiles 
      SET followers_count = (
        SELECT COUNT(*) 
        FROM follows 
        WHERE following_id = OLD.following_id
      )
      WHERE id = OLD.following_id;

      -- Update following count atomically
      UPDATE profiles 
      SET following_count = (
        SELECT COUNT(*) 
        FROM follows 
        WHERE follower_id = OLD.follower_id
      )
      WHERE id = OLD.follower_id;
    END IF;

    -- Commit the transaction
    RETURN NULL;
  EXCEPTION WHEN OTHERS THEN
    -- Rollback on error
    RAISE;
  END;
END;
$$ LANGUAGE plpgsql;

-- Create trigger with immediate timing
CREATE TRIGGER update_follower_counts_trigger
AFTER INSERT OR DELETE ON follows
FOR EACH ROW
EXECUTE FUNCTION update_follower_counts();

-- Ensure columns have correct defaults
ALTER TABLE profiles
ALTER COLUMN followers_count SET DEFAULT 0,
ALTER COLUMN following_count SET DEFAULT 0;

-- Fix any existing incorrect counts
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

-- Create index for better performance if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_follows_composite 
ON follows(follower_id, following_id);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';