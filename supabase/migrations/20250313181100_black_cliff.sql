/*
  # Fix Profile Permissions

  1. Changes
    - Update RLS policies for profile access
    - Grant proper permissions to authenticated users
    - Fix profile selection issues
    
  2. Security
    - Maintain existing security model
    - Ensure proper access control
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON profiles;

-- Create improved policies
CREATE POLICY "Public profiles are viewable by everyone"
ON profiles FOR SELECT
USING (
  -- Show profiles that either:
  -- 1. Have a corresponding auth user OR
  -- 2. Are being accessed by their owner
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = profiles.id
  ) OR auth.uid() = id
);

CREATE POLICY "Users can insert their own profile"
ON profiles FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated' AND
  auth.uid() = id AND
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = id
  )
);

CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can delete own profile"
ON profiles FOR DELETE
USING (
  auth.uid() = id OR
  NOT EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = profiles.id
  )
);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated, anon;
GRANT USAGE ON SCHEMA auth TO authenticated, anon;
GRANT SELECT ON profiles TO authenticated, anon;
GRANT INSERT, UPDATE, DELETE ON profiles TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';