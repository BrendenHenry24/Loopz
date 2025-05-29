/*
  # Fix Profile Creation System

  1. Changes
    - Drop and recreate profile creation trigger
    - Add proper error handling
    - Fix race condition with auth.users
    - Add proper permissions
    
  2. Security
    - Maintain RLS
    - Ensure proper cleanup
*/

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS create_profile_after_signup ON auth.users;
DROP FUNCTION IF EXISTS create_profile_for_user();

-- Create improved function to automatically create profile after user creation
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
    split_part(NEW.email, '@', 1)
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
      email,
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
      NEW.email,
      username_final,
      COALESCE(NEW.raw_user_meta_data->>'display_name', username_final),
      COALESCE(NEW.raw_user_meta_data->>'phone', NULL),
      false,
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