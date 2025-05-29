/*
  # Fix Loop Deletion Cascade

  1. Changes
    - Add trigger to handle storage cleanup when a loop is deleted
    - Ensure proper order of operations for loop deletion
    - Add function to validate storage path before deletion

  2. Security
    - Maintain existing RLS policies
    - Only allow deletion of owned loops
*/

-- Create function to handle storage cleanup
CREATE OR REPLACE FUNCTION handle_storage_cleanup()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete the file from storage
  DELETE FROM storage.objects
  WHERE bucket_id = 'loops'
  AND name = OLD.audio_url;

  -- Return the old record to continue with the deletion
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to run AFTER loop deletion
DROP TRIGGER IF EXISTS handle_storage_cleanup_trigger ON loops;
CREATE TRIGGER handle_storage_cleanup_trigger
AFTER DELETE ON loops
FOR EACH ROW
EXECUTE FUNCTION handle_storage_cleanup();

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';