-- Drop existing policies
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON profiles;
DROP POLICY IF EXISTS "Anyone can read public loops" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload loops" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own loops" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own loops" ON storage.objects;

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

-- Create improved loop policies
DROP POLICY IF EXISTS "Loops are viewable by everyone" ON loops;
DROP POLICY IF EXISTS "Authenticated users can create loops" ON loops;
DROP POLICY IF EXISTS "Producers can update own loops" ON loops;
DROP POLICY IF EXISTS "Producers can delete own loops" ON loops;

CREATE POLICY "Loops are viewable by everyone"
ON loops FOR SELECT
USING (true);

CREATE POLICY "Authenticated users can create loops"
ON loops FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated' AND
  auth.uid() = producer_id
);

CREATE POLICY "Producers can update own loops"
ON loops FOR UPDATE
USING (auth.uid() = producer_id)
WITH CHECK (auth.uid() = producer_id);

CREATE POLICY "Producers can delete own loops"
ON loops FOR DELETE
USING (auth.uid() = producer_id);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA storage TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA storage TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA storage TO authenticated;

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE loops ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';