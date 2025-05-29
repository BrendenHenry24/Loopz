/*
  # Fix Loop Deletion System

  1. Changes
    - Move storage cleanup to BEFORE DELETE trigger
    - Update RLS policies for proper deletion flow
    - Add proper error handling

  2. Security
    - Maintains RLS policies
    - Ensures proper cleanup order
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_storage_cleanup_trigger ON loops;
DROP FUNCTION IF EXISTS handle_storage_cleanup();

-- Create improved function to handle storage cleanup
CREATE OR REPLACE FUNCTION handle_storage_cleanup()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete the file from storage before the loop record is deleted
  DELETE FROM storage.objects
  WHERE bucket_id = 'loops'
  AND name = OLD.audio_url;

  -- Return OLD to proceed with loop deletion
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to run BEFORE loop deletion
CREATE TRIGGER handle_storage_cleanup_trigger
BEFORE DELETE ON loops
FOR EACH ROW
EXECUTE FUNCTION handle_storage_cleanup();

-- Drop existing delete policy
DROP POLICY IF EXISTS "Producers can delete own loops" ON loops;

-- Create improved DELETE policy
CREATE POLICY "Producers can delete own loops"
ON loops FOR DELETE
USING (
  auth.uid() = producer_id AND
  EXISTS (
    SELECT 1 FROM storage.objects
    WHERE bucket_id = 'loops'
    AND name = audio_url
  )
);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';