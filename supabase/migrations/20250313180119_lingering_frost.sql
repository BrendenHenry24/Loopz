/*
  # Fix User Deletion System

  1. Changes
    - Improve deletion order and error handling
    - Fix permission issues
    - Add better cleanup process
    
  2. Security
    - Maintain RLS policies
    - Grant proper permissions
*/

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS handle_user_deletion_trigger ON auth.users;
DROP FUNCTION IF EXISTS handle_user_deletion();

-- Create improved function to handle user deletion
CREATE OR REPLACE FUNCTION handle_user_deletion()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public, auth, storage
LANGUAGE plpgsql
AS $$
DECLARE
  storage_error text;
  profile_error text;
BEGIN
  -- Start an explicit transaction
  BEGIN
    -- Delete storage files first
    BEGIN
      DELETE FROM storage.objects
      WHERE bucket_id IN ('loops', 'avatars')
      AND (storage.foldername(name))[1] = OLD.id::text;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS storage_error = MESSAGE_TEXT;
      RAISE WARNING 'Storage cleanup failed: %', storage_error;
      -- Continue with profile deletion even if storage cleanup fails
    END;

    -- Delete profile (cascades to all related data)
    BEGIN
      DELETE FROM profiles WHERE id = OLD.id;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS profile_error = MESSAGE_TEXT;
      RAISE WARNING 'Profile deletion failed: %', profile_error;
      -- Continue with user deletion even if profile deletion fails
    END;
    
    RETURN OLD;
  END;
END;
$$;

-- Create trigger that runs before user deletion
CREATE TRIGGER handle_user_deletion_trigger
BEFORE DELETE ON auth.users
FOR EACH ROW
EXECUTE FUNCTION handle_user_deletion();

-- Drop existing profile policies
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
  auth.uid() = id OR
  NOT EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = profiles.id
  )
);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA storage TO postgres, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA storage TO postgres, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA storage TO postgres, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO postgres, service_role;

-- Grant specific permissions for the function
GRANT EXECUTE ON FUNCTION handle_user_deletion() TO postgres, service_role;
GRANT DELETE ON profiles TO postgres, service_role;

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';