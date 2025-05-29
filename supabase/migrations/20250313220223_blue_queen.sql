/*
  # Fix Phone Validation System

  1. Changes
    - Fix phone number validation
    - Improve profile creation trigger
    - Add proper error handling
    
  2. Security
    - Maintain RLS policies
    - Ensure data consistency
*/

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS create_profile_after_signup ON auth.users;
DROP FUNCTION IF EXISTS create_profile_for_user();

-- Create improved function to create profile after signup
CREATE OR REPLACE FUNCTION create_profile_for_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
DECLARE
  username_base text;
  username_final text;
  display_name_final text;
  counter integer := 0;
BEGIN
  -- Start an explicit transaction
  BEGIN
    -- Only create profile if phone is verified
    IF NEW.phone_confirmed_at IS NULL THEN
      RETURN NEW;
    END IF;

    -- Check if profile already exists
    IF EXISTS (
      SELECT 1 FROM profiles WHERE id = NEW.id
    ) THEN
      -- Update existing profile with verified status
      UPDATE profiles
      SET 
        phone_number = NEW.phone,
        phone_verified = true
      WHERE id = NEW.id;
      
      RETURN NEW;
    END IF;

    -- Get username and display name from metadata
    username_base := COALESCE(
      (NEW.raw_user_meta_data->>'username')::text,
      'user' || substr(NEW.phone::text, -4)
    );
    username_final := username_base;
    display_name_final := COALESCE(
      (NEW.raw_user_meta_data->>'display_name')::text,
      username_base
    );

    -- Ensure username uniqueness
    WHILE EXISTS (
      SELECT 1 FROM profiles WHERE username = username_final
    ) LOOP
      counter := counter + 1;
      username_final := username_base || counter::text;
    END LOOP;

    -- Create profile with data from metadata
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
      display_name_final,
      NEW.phone,
      true, -- Phone is verified at this point
      'basic',
      0,
      0,
      0,
      0.00,
      0,
      0
    );

    RETURN NEW;
  EXCEPTION WHEN unique_violation THEN
    -- If we hit a unique violation, try to update the existing profile
    UPDATE profiles
    SET 
      phone_number = NEW.phone,
      phone_verified = true
    WHERE id = NEW.id;
    
    RETURN NEW;
  WHEN OTHERS THEN
    -- Log other errors and continue
    RAISE WARNING 'Failed to create/update profile for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
  END;
END;
$$;

-- Create trigger that runs after user creation AND after phone verification
CREATE TRIGGER create_profile_after_signup
AFTER INSERT OR UPDATE OF phone_confirmed_at ON auth.users
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
  auth.uid() = id AND
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND phone_confirmed_at IS NOT NULL
  )
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
GRANT USAGE ON SCHEMA auth TO authenticated, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA auth TO service_role;
GRANT INSERT, UPDATE, DELETE ON profiles TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION create_profile_for_user() TO postgres, service_role;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';