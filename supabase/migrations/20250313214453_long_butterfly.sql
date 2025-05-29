/*
  # Switch to Phone Authentication
  
  1. Changes
    - Update profiles table to use phone as primary identifier
    - Add phone verification handling
    - Update RLS policies
    
  2. Security
    - Maintain RLS
    - Ensure proper verification
*/

-- Add phone verification columns if they don't exist
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS phone_number text UNIQUE,
ADD COLUMN IF NOT EXISTS phone_verified boolean DEFAULT false;

-- Create function to handle phone verification
CREATE OR REPLACE FUNCTION handle_phone_verification()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
BEGIN
  -- Basic phone number validation
  IF NEW.phone_number IS NOT NULL THEN
    IF NEW.phone_number !~ '^\+[1-9]\d{1,14}$' THEN
      RAISE EXCEPTION 'Invalid phone number format. Must start with + and contain 1-15 digits';
    END IF;

    -- Check uniqueness (additional check to prevent race conditions)
    IF EXISTS (
      SELECT 1 FROM profiles 
      WHERE phone_number = NEW.phone_number 
      AND id != NEW.id
    ) THEN
      RAISE EXCEPTION 'Phone number already in use';
    END IF;
  END IF;

  -- Only allow phone_verified to be set to true if there's a matching auth.users record
  -- with phone_confirmed_at set
  IF NEW.phone_verified = true AND OLD.phone_verified = false THEN
    IF NOT EXISTS (
      SELECT 1 
      FROM auth.users 
      WHERE id = NEW.id 
      AND phone_confirmed_at IS NOT NULL
      AND phone = NEW.phone_number
    ) THEN
      RAISE EXCEPTION 'Cannot set phone_verified to true without verification in auth.users';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger for phone verification
DROP TRIGGER IF EXISTS handle_phone_verification_trigger ON profiles;
CREATE TRIGGER handle_phone_verification_trigger
BEFORE INSERT OR UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION handle_phone_verification();

-- Create function to create profile after signup
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
  -- Add a small delay to ensure auth.users record is fully committed
  PERFORM pg_sleep(0.1);

  -- Check if profile already exists
  IF EXISTS (
    SELECT 1 FROM profiles WHERE id = NEW.id
  ) THEN
    RETURN NEW;
  END IF;

  -- Get metadata from auth.users
  username_base := COALESCE(
    NEW.raw_user_meta_data->>'username',
    'user' || substr(NEW.phone::text, -4)
  );
  username_final := username_base;

  -- Ensure username uniqueness
  WHILE EXISTS (
    SELECT 1 FROM profiles WHERE username = username_final
  ) LOOP
    counter := counter + 1;
    username_final := username_base || counter::text;
  END LOOP;

  -- Create profile with data from metadata
  BEGIN
    INSERT INTO profiles (
      id,
      username,
      display_name,
      phone_number,
      phone_verified,
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
      username_final,
      COALESCE(NEW.raw_user_meta_data->>'display_name', username_final),
      NEW.phone,
      COALESCE(NEW.phone_confirmed_at IS NOT NULL, false),
      'basic',
      0,
      0,
      0,
      0.00,
      0,
      0
    );
  EXCEPTION WHEN OTHERS THEN
    -- Log error and continue
    RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
  END;
  
  RETURN NEW;
END;
$$;

-- Create trigger that runs after user creation
DROP TRIGGER IF EXISTS create_profile_after_signup ON auth.users;
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

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_profiles_phone_number ON profiles(phone_number);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT USAGE ON SCHEMA auth TO authenticated, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA auth TO service_role;
GRANT INSERT, UPDATE, DELETE ON profiles TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION handle_phone_verification() TO authenticated;
GRANT EXECUTE ON FUNCTION create_profile_for_user() TO postgres, service_role;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';