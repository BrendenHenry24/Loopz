-- Create function to handle storage cleanup when a loop is deleted
CREATE OR REPLACE FUNCTION delete_loop_storage()
RETURNS TRIGGER AS $$
BEGIN
  -- Store the audio_url before deletion for cleanup
  PERFORM 
    pg_notify(
      'delete_storage',
      json_build_object(
        'bucket', 'loops',
        'file_path', OLD.audio_url
      )::text
    );
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to run before loop deletion
DROP TRIGGER IF EXISTS delete_loop_storage_trigger ON loops;
CREATE TRIGGER delete_loop_storage_trigger
  BEFORE DELETE ON loops
  FOR EACH ROW
  EXECUTE FUNCTION delete_loop_storage();