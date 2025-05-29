/*
  # Update profiles with additional fields and statistics

  1. New Fields
    - Add bio, website, instagram_handle to profiles
    - Add statistics tracking columns (total_uploads, total_downloads, average_rating)
  
  2. Functions & Triggers
    - Create functions to update profile statistics
    - Set up triggers for automatic stats updates
  
  3. Security
    - Enable RLS on profiles table
    - Set up policies for public viewing and user updates
  
  4. Performance
    - Add indexes for common queries
    - Set up cascading deletes for related tables
*/

-- Update profiles table with additional fields
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS bio text,
ADD COLUMN IF NOT EXISTS website text,
ADD COLUMN IF NOT EXISTS instagram_handle text,
ADD COLUMN IF NOT EXISTS total_uploads integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_downloads integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS average_loop_rating numeric(3,2) DEFAULT 0.00;

-- Create function to update profile statistics
CREATE OR REPLACE FUNCTION update_profile_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Update total uploads
  IF TG_OP = 'INSERT' THEN
    UPDATE profiles 
    SET total_uploads = total_uploads + 1
    WHERE id = NEW.producer_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE profiles 
    SET total_uploads = total_uploads - 1
    WHERE id = OLD.producer_id;
  END IF;

  -- Update average rating
  UPDATE profiles p
  SET average_loop_rating = (
    SELECT COALESCE(AVG(average_rating), 0)
    FROM loops
    WHERE producer_id = p.id
  )
  WHERE id = COALESCE(NEW.producer_id, OLD.producer_id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create function to update download counts
CREATE OR REPLACE FUNCTION update_download_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Update loop download count
  UPDATE loops
  SET downloads = downloads + 1
  WHERE id = NEW.loop_id;

  -- Update producer's total downloads
  UPDATE profiles p
  SET total_downloads = (
    SELECT COALESCE(SUM(downloads), 0)
    FROM loops
    WHERE producer_id = p.id
  )
  FROM loops l
  WHERE l.id = NEW.loop_id AND p.id = l.producer_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for automatic stats updates
DROP TRIGGER IF EXISTS update_profile_stats_trigger ON loops;
CREATE TRIGGER update_profile_stats_trigger
AFTER INSERT OR DELETE ON loops
FOR EACH ROW
EXECUTE FUNCTION update_profile_stats();

DROP TRIGGER IF EXISTS update_download_stats_trigger ON downloads;
CREATE TRIGGER update_download_stats_trigger
AFTER INSERT ON downloads
FOR EACH ROW
EXECUTE FUNCTION update_download_stats();

-- Update RLS policies
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies first
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;

-- Create new policies
CREATE POLICY "Public profiles are viewable by everyone"
ON profiles FOR SELECT
USING (true);

CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Ensure cascading deletes
ALTER TABLE loops
DROP CONSTRAINT IF EXISTS loops_producer_id_fkey,
ADD CONSTRAINT loops_producer_id_fkey
  FOREIGN KEY (producer_id)
  REFERENCES profiles(id)
  ON DELETE CASCADE;

ALTER TABLE downloads
DROP CONSTRAINT IF EXISTS downloads_user_id_fkey,
ADD CONSTRAINT downloads_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES profiles(id)
  ON DELETE CASCADE;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_loops_producer_id ON loops(producer_id);
CREATE INDEX IF NOT EXISTS idx_downloads_user_id ON downloads(user_id);
CREATE INDEX IF NOT EXISTS idx_downloads_loop_id ON downloads(loop_id);
CREATE INDEX IF NOT EXISTS idx_profiles_instagram_handle ON profiles(instagram_handle);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';