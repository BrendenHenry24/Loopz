-- First, ensure profiles table has the correct columns with default values
ALTER TABLE profiles
ALTER COLUMN followers_count SET DEFAULT 0,
ALTER COLUMN following_count SET DEFAULT 0;

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS update_follower_counts_trigger ON follows;
DROP FUNCTION IF EXISTS update_follower_counts();

-- Create a more reliable function to update follower counts
CREATE OR REPLACE FUNCTION update_follower_counts()
RETURNS TRIGGER AS $$
DECLARE
  _followers_count INTEGER;
  _following_count INTEGER;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Get accurate count for followers
    SELECT COUNT(*) INTO _followers_count
    FROM follows
    WHERE following_id = NEW.following_id;

    -- Get accurate count for following
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
    -- Get accurate count for followers
    SELECT COUNT(*) INTO _followers_count
    FROM follows
    WHERE following_id = OLD.following_id;

    -- Get accurate count for following
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

-- Create the trigger
CREATE TRIGGER update_follower_counts_trigger
AFTER INSERT OR DELETE ON follows
FOR EACH ROW
EXECUTE FUNCTION update_follower_counts();

-- Update RLS policies for profiles table
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;

CREATE POLICY "Public profiles are viewable by everyone"
ON profiles FOR SELECT
USING (true);

CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

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

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_follows_counts ON follows(follower_id, following_id);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';