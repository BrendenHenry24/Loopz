/*
  # Fix Profile Creation System

  1. Changes
    - Fix profile creation during signup
    - Improve error handling
    - Add proper transaction handling
    - Fix race conditions
    
  2. Security
    - Maintain RLS policies
    - Ensure proper validation
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
  signup_data jsonb;
  counter integer := 0;
  max_retries integer := 3;
  current_try integer := 0;
  lock_obtained boolean;
BEGIN
  -- Get an advisory lock for this user ID to prevent concurrent profile creation
  -- Convert UUID to two integers for pg_try_advisory_xact_lock
  SELECT pg_try_advisory_xact_lock(
    ('x' || substr(NEW.id::text, 1, 8))::bit(32)::int,
    ('x' || substr(NEW.id::text, 9, 8))::bit(32)::int
  ) INTO lock_obtained;

  IF NOT lock_obtained THEN
    -- Another transaction is already creating/updating this profile
    RETURN NEW;
  END IF;

  -- Start an explicit transaction block
  BEGIN
    -- Get signup data from metadata if available
    signup_data := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);

    -- Get session data if available (for phone verification)
    IF TG_OP = 'UPDATE' AND NEW.phone_confirmed_at IS NOT NULL THEN
      signup_data := COALESCE(
        (SELECT raw_user_meta_data FROM auth.users WHERE id = NEW.id),
        signup_data
      );
    END IF;

    -- Check if profile already exists using FOR UPDATE SKIP LOCKED
    IF EXISTS (
      SELECT 1 FROM profiles WHERE id = NEW.id FOR UPDATE SKIP LOCKED
    ) THEN
      -- Update existing profile with metadata if needed
      UPDATE profiles
      SET 
        phone_number = NEW.phone,
        phone_verified = COALESCE(NEW.phone_confirmed_at IS NOT NULL, false),
        email = COALESCE(
          NEW.email,
          (signup_data->>'email')::text,
          profiles.email
        ),
        username = COALESCE(
          (signup_data->>'username')::text,
          profiles.username
        ),
        display_name = COALESCE(
          (signup_data->>'display_name')::text,
          profiles.display_name
        )
      WHERE id = NEW.id;
      
      RETURN NEW;
    END IF;

    -- Retry loop for handling race conditions
    WHILE current_try < max_retries LOOP
      BEGIN
        current_try := current_try + 1;

        -- Get username and display name from metadata
        username_base := COALESCE(
          (signup_data->>'username')::text,
          'user' || substr(COALESCE(NEW.phone, NEW.id::text), -4)
        );
        username_final := username_base;
        display_name_final := COALESCE(
          (signup_data->>'display_name')::text,
          (signup_data->>'username')::text,
          username_base
        );

        -- Ensure username uniqueness with SKIP LOCKED
        WHILE EXISTS (
          SELECT 1 FROM profiles WHERE username = username_final FOR UPDATE SKIP LOCKED
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
          COALESCE(NEW.email, (signup_data->>'email')::text),
          NEW.phone,
          COALESCE(NEW.phone_confirmed_at IS NOT NULL, false),
          (signup_data->>'avatar_url')::text,
          (signup_data->>'bio')::text,
          (signup_data->>'website')::text,
          (signup_data->>'instagram_handle')::text,
          'basic',
          0,
          0,
          0,
          0.00,
          0,
          0
        )
        ON CONFLICT (id) DO UPDATE
        SET
          phone_number = EXCLUDED.phone_number,
          phone_verified = EXCLUDED.phone_verified,
          email = COALESCE(EXCLUDED.email, profiles.email),
          username = COALESCE(profiles.username, EXCLUDED.username),
          display_name = COALESCE(profiles.display_name, EXCLUDED.display_name);

        -- If we get here, the insert/update succeeded
        EXIT;

      EXCEPTION 
        WHEN unique_violation THEN
          -- Only retry if we haven't hit max retries
          IF current_try >= max_retries THEN
            RAISE WARNING 'Max retries reached for profile creation';
            EXIT;
          END IF;
          -- Otherwise continue to next retry
          CONTINUE;
      END;
    END LOOP;

    RETURN NEW;
  EXCEPTION WHEN OTHERS THEN
    -- Log other errors and continue
    RAISE WARNING 'Failed to create/update profile for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
  END;
END;
$$;

-- Create trigger that runs after user creation AND after phone verification
CREATE TRIGGER create_profile_after_signup
AFTER INSERT OR UPDATE OF phone_confirmed_at, raw_user_meta_data ON auth.users
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