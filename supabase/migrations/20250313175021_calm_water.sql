/*
  # Fix User Deletion System

  1. Changes
    - Drop and recreate foreign key with proper permissions
    - Update trigger function to handle deletion order
    - Add proper security context for deletion
    
  2. Security
    - Use security definer for proper permissions
    - Ensure proper cleanup order
*/

-- First ensure the trigger is dropped
DROP TRIGGER IF EXISTS handle_user_deletion_trigger ON auth.users;
DROP FUNCTION IF EXISTS handle_user_deletion();

-- Drop existing foreign key
ALTER TABLE profiles
DROP CONSTRAINT IF EXISTS profiles_id_fkey;

-- Create improved function to handle user deletion
CREATE OR REPLACE FUNCTION handle_user_deletion()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- First delete storage files
  DELETE FROM storage.objects
  WHERE bucket_id IN ('loops', 'avatars')
  AND (storage.foldername(name))[1] = OLD.id::text;

  -- Then delete profile (this will cascade to all related data)
  DELETE FROM profiles WHERE id = OLD.id;
  
  RETURN OLD;
END;
$$;

-- Create trigger that runs before user deletion
CREATE TRIGGER handle_user_deletion_trigger
BEFORE DELETE ON auth.users
FOR EACH ROW
EXECUTE FUNCTION handle_user_deletion();

-- Recreate foreign key with proper permissions
ALTER TABLE profiles
ADD CONSTRAINT profiles_id_fkey
  FOREIGN KEY (id)
  REFERENCES auth.users(id)
  ON DELETE CASCADE;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA storage TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA storage TO postgres, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA storage TO postgres, service_role;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';