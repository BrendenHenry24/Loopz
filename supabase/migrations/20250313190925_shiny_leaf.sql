/*
  # Fix Profile Permissions

  1. Changes
    - Remove email field validation from profile updates
    - Improve RLS policies for profiles
    - Fix profile update function
    - Grant proper permissions
    
  2. Security
    - Maintain RLS
    - Remove unnecessary auth.users access
*/

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

-- Drop existing update trigger
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
  NEW.created_at := OLD.created_at;

  -- Allow email to be updated
  NEW.email := NEW.email;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'Failed to update profile: %', SQLERRM;
END;
$$;

-- Create trigger for profile updates
CREATE TRIGGER handle_profile_update_trigger
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION handle_profile_update();

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