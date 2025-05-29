-- Remove any existing storage policies
DROP POLICY IF EXISTS "Loops are publicly accessible" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload loops" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own loops" ON storage.objects;

-- Create new storage policies
CREATE POLICY "Public read access for loops"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'loops' AND
  EXISTS (
    SELECT 1 FROM loops 
    WHERE audio_url = storage.objects.name
  )
);

CREATE POLICY "Authenticated users can upload to their folder"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'loops' AND
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can delete their own loops"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'loops' AND
  EXISTS (
    SELECT 1 FROM loops
    WHERE audio_url = storage.objects.name
    AND producer_id = auth.uid()
  )
);

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Update bucket configuration
UPDATE storage.buckets
SET public = true,
    file_size_limit = 10485760, -- 10MB
    allowed_mime_types = ARRAY['audio/mpeg', 'audio/wav', 'audio/x-m4a', 'audio/aac']
WHERE id = 'loops';

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';