/*
  # Fix Upload System

  1. Changes
    - Add storage cleanup function
    - Add storage usage tracking
    - Fix profile update permissions
    - Add proper storage policies

  2. Security
    - Maintain RLS policies
    - Ensure proper cleanup
*/

-- Drop existing storage policies
DROP POLICY IF EXISTS "Anyone can read public loops" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload loops" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own loops" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own loops" ON storage.objects;

-- Create improved storage policies
CREATE POLICY "Anyone can read public loops"
ON storage.objects FOR SELECT
USING (bucket_id = 'loops');

CREATE POLICY "Users can upload loops"
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'loops' AND
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can update their own loops"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'loops' AND
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can delete their own loops"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'loops' AND
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Create function to handle storage cleanup
CREATE OR REPLACE FUNCTION handle_storage_cleanup()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, storage
LANGUAGE plpgsql
AS $$
BEGIN
  -- Delete storage files first
  DELETE FROM storage.objects
  WHERE bucket_id = 'loops'
  AND name = OLD.audio_url;

  -- Return OLD to proceed with loop deletion
  RETURN OLD;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Storage cleanup failed: %', SQLERRM;
  -- Continue with loop deletion even if storage cleanup fails
  RETURN OLD;
END;
$$;

-- Create trigger for storage cleanup
DROP TRIGGER IF EXISTS handle_storage_cleanup_trigger ON loops;
CREATE TRIGGER handle_storage_cleanup_trigger
BEFORE DELETE ON loops
FOR EACH ROW
EXECUTE FUNCTION handle_storage_cleanup();

-- Create function to update storage usage
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
DROP TRIGGER IF EXISTS update_storage_usage_trigger ON loops;
CREATE TRIGGER update_storage_usage_trigger
AFTER INSERT OR UPDATE OR DELETE ON loops
FOR EACH ROW
EXECUTE FUNCTION update_storage_usage();

-- Create function to check storage limits
CREATE OR REPLACE FUNCTION check_storage_limit()
RETURNS TRIGGER AS $$
DECLARE
  user_tier text;
  user_storage bigint;
  storage_limit bigint;
BEGIN
  -- Get user's membership tier and current storage
  SELECT membership_tier, storage_used
  INTO user_tier, user_storage
  FROM profiles
  WHERE id = NEW.producer_id;

  -- Set storage limit based on tier
  storage_limit := CASE user_tier
    WHEN 'basic' THEN 52428800 -- 50MB
    WHEN 'pro' THEN 104857600 -- 100MB
    WHEN 'enterprise' THEN 262144000 -- 250MB
    ELSE 52428800 -- Default to basic
  END;

  -- Check if new file would exceed limit
  IF user_storage + NEW.file_size > storage_limit THEN
    RAISE EXCEPTION 'Storage limit exceeded for % tier', user_tier;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to check storage limit before insert
DROP TRIGGER IF EXISTS check_storage_limit_trigger ON loops;
CREATE TRIGGER check_storage_limit_trigger
BEFORE INSERT ON loops
FOR EACH ROW
EXECUTE FUNCTION check_storage_limit();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA storage TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA storage TO authenticated;
GRANT EXECUTE ON FUNCTION handle_storage_cleanup() TO authenticated;
GRANT EXECUTE ON FUNCTION update_storage_usage() TO authenticated;
GRANT EXECUTE ON FUNCTION check_storage_limit() TO authenticated;

-- Ensure RLS is enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';