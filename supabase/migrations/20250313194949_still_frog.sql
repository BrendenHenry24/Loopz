/*
  # Fix Upload System Permissions

  1. Changes
    - Fix storage policies for uploads
    - Add proper RLS policies for profiles
    - Grant necessary permissions
    - Fix storage usage tracking
    
  2. Security
    - Maintain RLS
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
  auth.role() = 'authenticated'
);

CREATE POLICY "Users can update their own loops"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'loops' AND
  auth.role() = 'authenticated'
);

CREATE POLICY "Users can delete their own loops"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'loops' AND
  auth.role() = 'authenticated'
);

-- Drop existing profile policies
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON profiles;

-- Create improved profile policies
CREATE POLICY "Public profiles are viewable by everyone"
ON profiles FOR SELECT
USING (true);

CREATE POLICY "Users can insert their own profile"
ON profiles FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated' AND
  auth.uid() = id
);

CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can delete own profile"
ON profiles FOR DELETE
USING (auth.uid() = id);

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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for storage usage updates
DROP TRIGGER IF EXISTS update_storage_usage_trigger ON loops;
CREATE TRIGGER update_storage_usage_trigger
AFTER INSERT OR UPDATE OR DELETE ON loops
FOR EACH ROW
EXECUTE FUNCTION update_storage_usage();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA storage TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA storage TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA storage TO authenticated;

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION update_storage_usage() TO authenticated;

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';