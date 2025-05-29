/*
  # Fix User Deletion System

  1. Changes
    - Drop and recreate function with proper permissions
    - Add explicit transaction handling
    - Fix schema search path issues
    - Add proper error handling
    
  2. Security
    - Grant proper permissions to service role
    - Use security definer with correct search path
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
      RAISE EXCEPTION 'Profile deletion failed: %', profile_error;
    END;
    
    RETURN OLD;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'User deletion failed: %', SQLERRM;
  END;
END;
$$;

-- Create trigger that runs before user deletion
CREATE TRIGGER handle_user_deletion_trigger
BEFORE DELETE ON auth.users
FOR EACH ROW
EXECUTE FUNCTION handle_user_deletion();

-- Grant necessary permissions to service role
GRANT USAGE ON SCHEMA storage TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA storage TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA storage TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO service_role;

-- Grant specific permissions for the function
GRANT EXECUTE ON FUNCTION handle_user_deletion() TO service_role;
GRANT DELETE ON profiles TO service_role;

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';