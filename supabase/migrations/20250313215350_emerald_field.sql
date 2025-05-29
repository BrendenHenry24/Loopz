/*
  # Fix Profile Creation System

  1. Changes
    - Improve profile creation to properly handle username and display name
    - Fix metadata handling from auth.users
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
  -- Add a small delay to ensure auth.users record is fully committed
  PERFORM pg_sleep(0.1);

  -- Check if profile already exists
  IF EXISTS (
    SELECT 1 FROM profiles WHERE id = NEW.id
  ) THEN
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
      display_name_final,
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
CREATE TRIGGER create_profile_after_signup
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION create_profile_for_user();

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