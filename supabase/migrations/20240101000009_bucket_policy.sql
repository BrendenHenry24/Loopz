-- Enable RLS on storage.buckets
ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Public can read loops bucket" ON storage.buckets;
DROP POLICY IF EXISTS "Admin can manage buckets" ON storage.buckets;

-- Create policies for bucket access
CREATE POLICY "Public can read loops bucket"
ON storage.buckets FOR SELECT
USING (id = 'loops');

CREATE POLICY "Admin can manage buckets"
ON storage.buckets 
USING (auth.role() = 'service_role');

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';