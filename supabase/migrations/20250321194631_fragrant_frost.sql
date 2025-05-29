/*
  # Fix Google Authentication Profile Creation

  1. Changes
    - Improve profile creation function to handle Google OAuth data
    - Add better error handling
    - Fix metadata extraction
    
  2. Security
    - Maintain RLS policies
    - Ensure proper validation
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS create_profile_after_signup ON auth.users;
DROP FUNCTION IF EXISTS create_profile_for_user();

-- Create improved function to handle profile creation
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
  avatar_url_final text;
  google_id_final text;
  counter integer := 0;
BEGIN
  -- Start transaction
  BEGIN
    -- Check if profile already exists
    IF EXISTS (
      SELECT 1 FROM profiles WHERE id = NEW.id
    ) THEN
      RETURN NEW;
    END IF;

    -- Extract Google-specific data
    SELECT 
      COALESCE(raw_user_meta_data->>'name', split_part(email, '@', 1)),
      COALESCE(raw_user_meta_data->>'picture', raw_user_meta_data->>'avatar_url'),
      COALESCE(raw_user_meta_data->>'sub', raw_user_meta_data->>'google_id')
    INTO 
      display_name_final,
      avatar_url_final,
      google_id_final
    FROM auth.users
    WHERE id = NEW.id;

    -- Generate username from display name
    username_base := regexp_replace(
      lower(COALESCE(display_name_final, split_part(NEW.email, '@', 1))),
      '[^a-z0-9]',
      '',
      'g'
    );
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
      avatar_url_final,
      google_id_final,
      'basic',
      0,
      0,
      0,
      0.00,
      0,
      0
    );

    RETURN NEW;
  EXCEPTION WHEN OTHERS THEN
    -- Log error details
    RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
    -- Continue with user creation even if profile creation fails
    RETURN NEW;
  END;
END;
$$;

-- Create trigger for profile creation
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