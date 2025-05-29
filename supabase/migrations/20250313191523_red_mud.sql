/*
  # Fix Profile Update System

  1. Changes
    - Remove auth.users dependency from profile updates
    - Fix RLS policies for profile updates
    - Add proper field validation
    
  2. Security
    - Maintain RLS
    - Allow only specific field updates
*/

-- Drop existing update trigger and function
DROP TRIGGER IF EXISTS handle_profile_update_trigger ON profiles;
DROP FUNCTION IF EXISTS handle_profile_update();

-- Create improved function to handle profile updates
CREATE OR REPLACE FUNCTION handle_profile_update()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Validate username if being updated
  IF NEW.username IS DISTINCT FROM OLD.username THEN
    IF EXISTS (
      SELECT 1 FROM profiles
      WHERE username = NEW.username
      AND id != NEW.id
    ) THEN
      RAISE EXCEPTION 'Username already taken';
    END IF;
  END IF;

  -- Prevent modification of certain fields
  NEW.id := OLD.id;
  NEW.email := OLD.email;
  NEW.created_at := OLD.created_at;
  NEW.membership_tier := OLD.membership_tier;
  NEW.storage_used := OLD.storage_used;
  NEW.total_uploads := OLD.total_uploads;
  NEW.total_downloads := OLD.total_downloads;
  NEW.average_loop_rating := OLD.average_loop_rating;
  NEW.followers_count := OLD.followers_count;
  NEW.following_count := OLD.following_count;

  -- Only allow updates to:
  -- - username
  -- - instagram_handle
  -- - avatar_url
  -- - bio
  -- - website

  RETURN NEW;
END;
$$;

-- Create trigger for profile updates
CREATE TRIGGER handle_profile_update_trigger
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION handle_profile_update();

-- Drop existing policies
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON profiles;

-- Create improved policies
CREATE POLICY "Public profiles are viewable by everyone"
ON profiles FOR SELECT
USING (true);

CREATE POLICY "Users can insert their own profile"
ON profiles FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated' AND
  auth.uid() = id
);

CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can delete own profile"
ON profiles FOR DELETE
USING (auth.uid() = id);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON profiles TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION handle_profile_update() TO authenticated;

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';