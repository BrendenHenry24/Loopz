/*
  # Add Google Authentication Support
  
  1. Changes
    - Remove phone verification columns and triggers
    - Update profile creation for Google auth
    - Add Google-specific profile fields
    
  2. Security
    - Maintain RLS policies
    - Ensure proper auth flow
*/

-- Drop phone verification triggers and functions
DROP TRIGGER IF EXISTS handle_phone_verification_trigger ON profiles;
DROP FUNCTION IF EXISTS handle_phone_verification();

-- Remove phone-related columns
ALTER TABLE profiles
DROP COLUMN IF EXISTS phone_number,
DROP COLUMN IF EXISTS phone_verified;

-- Add Google-specific profile fields
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS google_id text UNIQUE,
ADD COLUMN IF NOT EXISTS avatar_url text;

-- Update profile creation function
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
  -- Check if profile already exists
  IF EXISTS (
    SELECT 1 FROM profiles WHERE id = NEW.id
  ) THEN
    RETURN NEW;
  END IF;

  -- Get data from auth metadata
  SELECT 
    COALESCE(raw_user_meta_data->>'name', raw_user_meta_data->>'full_name', email),
    COALESCE(raw_user_meta_data->>'avatar_url', raw_user_meta_data->>'picture'),
    COALESCE(raw_user_meta_data->>'email')
  INTO display_name_final, NEW.avatar_url, NEW.email
  FROM auth.users
  WHERE id = NEW.id;

  -- Generate username from display name
  username_base := regexp_replace(lower(display_name_final), '[^a-z0-9]', '', 'g');
  username_final := username_base;

  -- Ensure username uniqueness
  WHILE EXISTS (
    SELECT 1 FROM profiles WHERE username = username_final
  ) LOOP
    counter := counter + 1;
    username_final := username_base || counter::text;
  END LOOP;

  -- Create profile
  INSERT INTO profiles (
    id,
    username,
    display_name,
    email,
    avatar_url,
    google_id,
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
    NEW.email,
    NEW.avatar_url,
    raw_user_meta_data->>'sub',
    'basic',
    0,
    0,
    0,
    0.00,
    0,
    0
  );

  RETURN NEW;
END;
$$;

-- Recreate trigger
DROP TRIGGER IF EXISTS create_profile_after_signup ON auth.users;
CREATE TRIGGER create_profile_after_signup
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION create_profile_for_user();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA auth TO service_role;
GRANT INSERT, UPDATE, DELETE ON profiles TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';