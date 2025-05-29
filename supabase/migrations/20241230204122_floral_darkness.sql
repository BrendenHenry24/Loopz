/*
  # Fix Storage Usage Tracking

  1. Changes
    - Add storage tracking trigger
    - Fix storage usage updates
    - Add proper cleanup on deletion

  2. Security
    - Maintains RLS policies
    - Ensures accurate storage tracking
*/

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS update_storage_usage_trigger ON loops;
DROP FUNCTION IF EXISTS update_storage_usage();

-- Create improved function to track storage usage
CREATE OR REPLACE FUNCTION update_storage_usage()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Add new file size to user's storage
    UPDATE profiles
    SET storage_used = COALESCE(storage_used, 0) + COALESCE(NEW.file_size, 0)
    WHERE id = NEW.producer_id;
    
  ELSIF TG_OP = 'DELETE' THEN
    -- Subtract deleted file size from user's storage
    UPDATE profiles
    SET storage_used = GREATEST(0, COALESCE(storage_used, 0) - COALESCE(OLD.file_size, 0))
    WHERE id = OLD.producer_id;
    
  ELSIF TG_OP = 'UPDATE' AND OLD.file_size != NEW.file_size THEN
    -- Update storage for file size changes
    UPDATE profiles
    SET storage_used = GREATEST(0, COALESCE(storage_used, 0) - COALESCE(OLD.file_size, 0) + COALESCE(NEW.file_size, 0))
    WHERE id = NEW.producer_id;
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for storage usage updates
CREATE TRIGGER update_storage_usage_trigger
AFTER INSERT OR UPDATE OR DELETE ON loops
FOR EACH ROW
EXECUTE FUNCTION update_storage_usage();

-- Function to fix any incorrect storage usage
CREATE OR REPLACE FUNCTION fix_storage_usage()
RETURNS void AS $$
BEGIN
  -- Reset all storage usage to 0
  UPDATE profiles SET storage_used = 0;
  
  -- Recalculate storage usage for each user
  WITH storage_totals AS (
    SELECT 
      producer_id,
      COALESCE(SUM(file_size), 0) as total_storage
    FROM loops
    GROUP BY producer_id
  )
  UPDATE profiles p
  SET storage_used = st.total_storage
  FROM storage_totals st
  WHERE p.id = st.producer_id;
END;
$$ LANGUAGE plpgsql;

-- Run storage usage fix
SELECT fix_storage_usage();

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_loops_producer_file_size 
ON loops(producer_id, file_size);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';