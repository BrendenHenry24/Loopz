/*
  # Fix Auth User Deletion System

  1. Changes
    - Update foreign key constraint between auth.users and profiles
    - Add cascading delete from auth.users to profiles
    - Ensure proper cleanup of all related data
    
  2. Security
    - Maintain data integrity
    - Ensure proper authorization
*/

-- First, drop existing foreign key if it exists
ALTER TABLE profiles
DROP CONSTRAINT IF EXISTS profiles_id_fkey;

-- Add cascading foreign key from profiles to auth.users
ALTER TABLE profiles
ADD CONSTRAINT profiles_id_fkey
  FOREIGN KEY (id)
  REFERENCES auth.users(id)
  ON DELETE CASCADE;

-- Create function to handle user deletion cleanup
CREATE OR REPLACE FUNCTION handle_user_deletion()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete user's storage files
  DELETE FROM storage.objects
  WHERE bucket_id IN ('loops', 'avatars')
  AND (storage.foldername(name))[1] = OLD.id::text;
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to clean up storage on user deletion
DROP TRIGGER IF EXISTS handle_user_deletion_trigger ON auth.users;
CREATE TRIGGER handle_user_deletion_trigger
BEFORE DELETE ON auth.users
FOR EACH ROW
EXECUTE FUNCTION handle_user_deletion();

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';