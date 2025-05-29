-- Drop existing delete policy if it exists
DROP POLICY IF EXISTS "Users can delete their own loops" ON storage.objects;

-- Create updated delete policy with proper path checking
CREATE POLICY "Users can delete their own loops"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'loops' AND
  auth.uid()::text = (storage.foldername(name))[1] AND
  EXISTS (
    SELECT 1 
    FROM loops l 
    WHERE l.audio_url = name 
    AND l.producer_id = auth.uid()
  )
);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';