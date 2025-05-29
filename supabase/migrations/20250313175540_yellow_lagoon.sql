/*
  # Fix Profile Deletion System

  1. Changes
    - Add explicit transaction handling for profile deletion
    - Fix permission issues
    - Add proper cleanup order
    - Improve error handling
    
  2. Security
    - Grant proper permissions
    - Maintain RLS policies
*/

-- Drop existing delete policy if it exists
DROP POLICY IF EXISTS "Users can delete own profile" ON profiles;

-- Create improved delete policy
CREATE POLICY "Users can delete own profile"
ON profiles FOR DELETE
USING (
  auth.uid() = id OR
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = profiles.id
    AND auth.users.deleted_at IS NOT NULL
  )
);

-- Create function to handle profile cleanup
CREATE OR REPLACE FUNCTION handle_profile_cleanup()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, storage
LANGUAGE plpgsql
AS $$
DECLARE
  storage_error text;
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
      -- Continue with deletion even if storage cleanup fails
    END;

    -- The actual profile deletion will happen automatically
    RETURN OLD;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Profile cleanup failed: %', SQLERRM;
  END;
END;
$$;

-- Create trigger for profile cleanup
DROP TRIGGER IF EXISTS handle_profile_cleanup_trigger ON profiles;
CREATE TRIGGER handle_profile_cleanup_trigger
BEFORE DELETE ON profiles
FOR EACH ROW
EXECUTE FUNCTION handle_profile_cleanup();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA storage TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA storage TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA storage TO service_role;

-- Grant specific permissions for the function
GRANT EXECUTE ON FUNCTION handle_profile_cleanup() TO service_role;

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';