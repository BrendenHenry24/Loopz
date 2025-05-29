/*
  # Fix Profile Creation with Signup Metadata

  1. Changes
    - Improve metadata handling during signup
    - Fix profile creation trigger
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
    -- Check if profile already exists
    IF EXISTS (
      SELECT 1 FROM profiles WHERE id = NEW.id
    ) THEN
      -- Update existing profile with metadata if needed
      UPDATE profiles
      SET 
        phone_number = COALESCE(profiles.phone_number, NEW.phone),
        phone_verified = COALESCE(NEW.phone_confirmed_at IS NOT NULL, false),
        email = COALESCE(
          profiles.email,
          NEW.email,
          (NEW.raw_user_meta_data->>'email')::text
        ),
        username = COALESCE(
          profiles.username,
          (NEW.raw_user_meta_data->>'username')::text,
          split_part(COALESCE(NEW.email, NEW.phone), '@', 1)
        ),
        display_name = COALESCE(
          profiles.display_name,
          (NEW.raw_user_meta_data->>'display_name')::text,
          (NEW.raw_user_meta_data->>'username')::text,
          split_part(COALESCE(NEW.email, NEW.phone), '@', 1)
        )
      WHERE id = NEW.id;
      
      RETURN NEW;
    END IF;

    -- Get username and display name from metadata
    username_base := COALESCE(
      (NEW.raw_user_meta_data->>'username')::text,
      split_part(COALESCE(NEW.email, NEW.phone), '@', 1)
    );
    username_final := username_base;
    display_name_final := COALESCE(
      (NEW.raw_user_meta_data->>'display_name')::text,
      (NEW.raw_user_meta_data->>'username')::text,
      username_base
    );

    -- Ensure username uniqueness
    WHILE EXISTS (
      SELECT 1 FROM profiles WHERE username = username_final
    ) LOOP
      counter := counter + 1;
      username_final := username_base || counter::text;
    END LOOP;

    -- Create profile with all available metadata
    INSERT INTO profiles (
      id,
      username,
      display_name,
      email,
      phone_number,
      phone_verified,
      avatar_url,
      bio,
      website,
      instagram_handle,
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
      COALESCE(NEW.email, (NEW.raw_user_meta_data->>'email')::text),
      NEW.phone,
      COALESCE(NEW.phone_confirmed_at IS NOT NULL, false),
      (NEW.raw_user_meta_data->>'avatar_url')::text,
      (NEW.raw_user_meta_data->>'bio')::text,
      (NEW.raw_user_meta_data->>'website')::text,
      (NEW.raw_user_meta_data->>'instagram_handle')::text,
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
      phone_number = COALESCE(profiles.phone_number, NEW.phone),
      phone_verified = COALESCE(NEW.phone_confirmed_at IS NOT NULL, false),
      email = COALESCE(
        profiles.email,
        NEW.email,
        (NEW.raw_user_meta_data->>'email')::text
      )
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