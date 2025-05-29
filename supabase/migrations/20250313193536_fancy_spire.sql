/*
  # Fix Database Setup

  1. Changes
    - Drop existing triggers and functions safely
    - Recreate profile management functions
    - Set up proper RLS policies
    - Fix permission issues

  2. Security
    - Maintain RLS policies
    - Ensure proper cleanup
*/

-- Drop existing triggers and functions safely
DROP TRIGGER IF EXISTS create_profile_after_signup ON auth.users;
DROP FUNCTION IF EXISTS create_profile_for_user();
DROP TRIGGER IF EXISTS handle_profile_update_trigger ON profiles;
DROP FUNCTION IF EXISTS handle_profile_update();

-- Create improved function to handle profile updates
CREATE OR REPLACE FUNCTION handle_profile_update()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Validate username if being updated
  IF NEW.username IS DISTINCT FROM OLD.username THEN
    IF EXISTS (
      SELECT 1 FROM profiles
      WHERE username = NEW.username
      AND id != NEW.id
    ) THEN
      RAISE EXCEPTION 'Username already taken';
    END IF;
  END IF;

  -- Prevent modification of protected fields
  NEW.id := OLD.id;
  NEW.created_at := OLD.created_at;
  NEW.membership_tier := OLD.membership_tier;
  NEW.storage_used := OLD.storage_used;
  NEW.total_uploads := OLD.total_uploads;
  NEW.total_downloads := OLD.total_downloads;
  NEW.average_loop_rating := OLD.average_loop_rating;
  NEW.followers_count := OLD.followers_count;
  NEW.following_count := OLD.following_count;

  -- Only allow updates to:
  -- - username
  -- - instagram_handle
  -- - avatar_url
  -- - bio
  -- - website

  RETURN NEW;
END;
$$;

-- Create trigger for profile updates
CREATE TRIGGER handle_profile_update_trigger
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION handle_profile_update();

-- Create function to automatically create profile after user creation
CREATE OR REPLACE FUNCTION create_profile_for_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
DECLARE
  username_base text;
  username_final text;
  counter integer := 0;
BEGIN
  -- Generate base username from email
  username_base := split_part(NEW.email, '@', 1);
  username_final := username_base;

  -- Ensure username uniqueness
  WHILE EXISTS (
    SELECT 1 FROM public.profiles WHERE username = username_final
  ) LOOP
    counter := counter + 1;
    username_final := username_base || counter::text;
  END LOOP;

  -- Create profile with default values
  INSERT INTO public.profiles (
    id,
    email,
    username,
    membership_tier,
    storage_used,
    total_uploads,
    total_downloads,
    average_loop_rating,
    followers_count,
    following_count
  )
  VALUES (
    NEW.id,
    NEW.email,
    username_final,
    'basic',
    0,
    0,
    0,
    0.00,
    0,
    0
  )
  ON CONFLICT (id) DO NOTHING;
  
  RETURN NEW;
END;
$$;

-- Create trigger that runs after user creation
CREATE TRIGGER create_profile_after_signup
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION create_profile_for_user();

-- Drop existing policies
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON profiles;

-- Create improved policies
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

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON profiles TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION handle_profile_update() TO authenticated;
GRANT EXECUTE ON FUNCTION create_profile_for_user() TO postgres, service_role;

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Create any missing profiles for existing users
INSERT INTO public.profiles (
  id,
  email,
  username,
  membership_tier,
  storage_used,
  total_uploads,
  total_downloads,
  average_loop_rating,
  followers_count,
  following_count
)
SELECT 
  u.id,
  u.email,
  COALESCE(
    (SELECT username FROM profiles WHERE id = u.id),
    split_part(u.email, '@', 1) || floor(random() * 1000)::text
  ),
  'basic',
  0,
  0,
  0,
  0.00,
  0,
  0
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM profiles WHERE profiles.id = u.id
)
ON CONFLICT (id) DO NOTHING;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';