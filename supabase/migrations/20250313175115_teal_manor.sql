/*
  # Fix User Deletion System

  1. Changes
    - Drop and recreate triggers in correct order
    - Add proper security context for deletion
    - Fix permission issues
    - Ensure proper cleanup order
    
  2. Security
    - Use security definer with proper search path
    - Grant explicit permissions
*/

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS handle_user_deletion_trigger ON auth.users;
DROP FUNCTION IF EXISTS handle_user_deletion();

-- Create improved function to handle user deletion
CREATE OR REPLACE FUNCTION handle_user_deletion()
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

  -- Delete profile (cascades to all related data)
  DELETE FROM profiles WHERE id = OLD.id;
  
  RETURN OLD;
EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'Failed to delete user: %', SQLERRM;
END;
$$;

-- Create trigger that runs before user deletion
CREATE TRIGGER handle_user_deletion_trigger
BEFORE DELETE ON auth.users
FOR EACH ROW
EXECUTE FUNCTION handle_user_deletion();

-- Grant explicit permissions
GRANT USAGE ON SCHEMA storage TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA storage TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA storage TO service_role;

-- Grant delete permissions on profiles
GRANT DELETE ON profiles TO service_role;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION handle_user_deletion() TO service_role;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';