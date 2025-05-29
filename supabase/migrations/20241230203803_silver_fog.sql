/*
  # Fix Loop Deletion System

  1. Changes
    - Improve storage cleanup trigger
    - Update RLS policies for proper deletion flow
    - Add better error handling
    - Fix permission issues

  2. Security
    - Maintains RLS policies
    - Ensures proper cleanup order
    - Prevents orphaned storage files
*/

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS handle_storage_cleanup_trigger ON loops;
DROP FUNCTION IF EXISTS handle_storage_cleanup();

-- Create improved function to handle storage cleanup
CREATE OR REPLACE FUNCTION handle_storage_cleanup()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete the file from storage
  DELETE FROM storage.objects
  WHERE bucket_id = 'loops'
  AND name = OLD.audio_url
  AND (storage.foldername(name))[1] = auth.uid()::text;

  -- Return OLD to proceed with loop deletion
  RETURN OLD;
EXCEPTION WHEN OTHERS THEN
  -- Log error and re-raise
  RAISE EXCEPTION 'Failed to delete storage file: %', SQLERRM;
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
USING (auth.uid() = producer_id);

-- Drop existing storage delete policy
DROP POLICY IF EXISTS "Users can delete their own loops" ON storage.objects;

-- Create improved storage delete policy
CREATE POLICY "Users can delete their own loops"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'loops' AND
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';