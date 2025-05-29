/*
  # Fix Profile Permissions

  1. Changes
    - Update RLS policies for better access control
    - Fix permission issues with profiles table
    - Add proper grants for auth schema access
    
  2. Security
    - Maintain proper RLS
    - Grant necessary permissions
*/

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
  auth.uid() = id AND
  NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
  )
);

CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can delete own profile"
ON profiles FOR DELETE
USING (auth.uid() = id);

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS handle_profile_creation_trigger ON profiles;
DROP TRIGGER IF EXISTS handle_profile_update_trigger ON profiles;
DROP FUNCTION IF EXISTS handle_profile_creation();
DROP FUNCTION IF EXISTS handle_profile_update();

-- Create improved function to handle profile creation
CREATE OR REPLACE FUNCTION handle_profile_creation()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
BEGIN
  -- Set default values
  NEW.membership_tier := COALESCE(NEW.membership_tier, 'basic');
  NEW.storage_used := COALESCE(NEW.storage_used, 0);
  NEW.total_uploads := COALESCE(NEW.total_uploads, 0);
  NEW.total_downloads := COALESCE(NEW.total_downloads, 0);
  NEW.average_loop_rating := COALESCE(NEW.average_loop_rating, 0.00);
  NEW.followers_count := COALESCE(NEW.followers_count, 0);
  NEW.following_count := COALESCE(NEW.following_count, 0);

  -- Get email from auth.users
  SELECT email INTO NEW.email
  FROM auth.users
  WHERE id = NEW.id;

  -- Generate username from email if not provided
  IF NEW.username IS NULL AND NEW.email IS NOT NULL THEN
    NEW.username := split_part(NEW.email, '@', 1);
    
    -- Ensure username uniqueness
    WHILE EXISTS (
      SELECT 1 FROM profiles WHERE username = NEW.username AND id != NEW.id
    ) LOOP
      NEW.username := NEW.username || floor(random() * 1000)::text;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

-- Create function to handle profile updates
CREATE OR REPLACE FUNCTION handle_profile_update()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public, auth
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

  -- Prevent modification of certain fields
  NEW.id := OLD.id;
  NEW.email := OLD.email;
  NEW.created_at := OLD.created_at;

  RETURN NEW;
END;
$$;

-- Create triggers
CREATE TRIGGER handle_profile_creation_trigger
BEFORE INSERT ON profiles
FOR EACH ROW
EXECUTE FUNCTION handle_profile_creation();

CREATE TRIGGER handle_profile_update_trigger
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION handle_profile_update();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, postgres, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA auth TO postgres, service_role;
GRANT INSERT, UPDATE, DELETE ON profiles TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION handle_profile_creation() TO authenticated;
GRANT EXECUTE ON FUNCTION handle_profile_update() TO authenticated;

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';