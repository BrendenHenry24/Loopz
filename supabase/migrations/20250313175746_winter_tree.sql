/*
  # Fix Profile Deletion System

  1. Changes
    - Update RLS policies to allow proper deletion
    - Fix permission issues
    - Improve cleanup order
    - Add better error handling
    
  2. Security
    - Maintain RLS policies
    - Grant proper permissions
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Users can delete own profile" ON profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;

-- Create improved policies
CREATE POLICY "Public profiles are viewable by everyone"
ON profiles FOR SELECT
USING (true);

CREATE POLICY "Users can insert their own profile"
ON profiles FOR INSERT
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can delete own profile"
ON profiles FOR DELETE
USING (
  -- Allow deletion if:
  -- 1. User owns the profile OR
  -- 2. User has been deleted in auth.users
  auth.uid() = id OR
  NOT EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = profiles.id
  )
);

-- Drop existing cleanup function and trigger
DROP TRIGGER IF EXISTS handle_profile_cleanup_trigger ON profiles;
DROP FUNCTION IF EXISTS handle_profile_cleanup();

-- Create improved cleanup function
CREATE OR REPLACE FUNCTION handle_profile_cleanup()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, storage
LANGUAGE plpgsql
AS $$
BEGIN
  -- Delete storage files first
  DELETE FROM storage.objects
  WHERE bucket_id IN ('loops', 'avatars')
  AND (storage.foldername(name))[1] = OLD.id::text;

  -- The actual profile deletion will happen automatically
  RETURN OLD;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Storage cleanup failed: %', SQLERRM;
  -- Continue with profile deletion even if storage cleanup fails
  RETURN OLD;
END;
$$;

-- Create trigger for profile cleanup
CREATE TRIGGER handle_profile_cleanup_trigger
BEFORE DELETE ON profiles
FOR EACH ROW
EXECUTE FUNCTION handle_profile_cleanup();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA storage TO postgres, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA storage TO postgres, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA storage TO postgres, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO postgres, service_role;

-- Grant specific permissions for the function
GRANT EXECUTE ON FUNCTION handle_profile_cleanup() TO postgres, service_role;

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';