-- Drop existing storage policies
DROP POLICY IF EXISTS "Public read access for loops" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload to their folder" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own loops" ON storage.objects;

-- Create improved storage policies
CREATE POLICY "Anyone can read public loops"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'loops' AND
  auth.role() = 'authenticated'
);

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

-- Update bucket configuration
UPDATE storage.buckets
SET public = false,
    file_size_limit = 10485760, -- 10MB
    allowed_mime_types = ARRAY['audio/mpeg', 'audio/wav', 'audio/x-m4a', 'audio/aac']::text[]
WHERE id = 'loops';

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';