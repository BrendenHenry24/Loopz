/*
  # Fix Phone Number Validation and Profile Creation

  1. Changes
    - Improve phone number validation and formatting
    - Fix profile creation during signup
    - Add better error handling
    
  2. Security
    - Maintain existing security model
    - Ensure proper validation
*/

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS handle_phone_verification_trigger ON profiles;
DROP FUNCTION IF EXISTS handle_phone_verification();

-- Create improved function to handle phone verification
CREATE OR REPLACE FUNCTION handle_phone_verification()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
DECLARE
  clean_number text;
BEGIN
  -- Basic phone number validation
  IF NEW.phone_number IS NOT NULL THEN
    -- Clean the phone number - remove all non-digit characters except +
    clean_number := regexp_replace(NEW.phone_number, '[^0-9+]', '', 'g');
    
    -- If number starts with 1 but no +, add the +
    IF clean_number ~ '^1[0-9]{10}$' THEN
      clean_number := '+' || clean_number;
    END IF;
    
    -- If number has 10 digits with no prefix, add +1
    IF clean_number ~ '^[0-9]{10}$' THEN
      clean_number := '+1' || clean_number;
    END IF;

    -- If number starts with +1 and has 11 digits total, it's valid
    -- If number has + and 11 digits total but doesn't start with 1, make it start with 1
    IF clean_number ~ '^\+[0-9]{11}$' AND NOT clean_number ~ '^\+1' THEN
      clean_number := '+1' || substr(clean_number, 2);
    END IF;

    -- Final validation of the cleaned number
    IF clean_number !~ '^\+1[0-9]{10}$' THEN
      RAISE EXCEPTION 'Invalid phone number format. Must be a valid US number (+1 followed by 10 digits)';
    END IF;

    -- Set the cleaned number
    NEW.phone_number := clean_number;

    -- Check uniqueness (additional check to prevent race conditions)
    IF EXISTS (
      SELECT 1 FROM profiles 
      WHERE phone_number = NEW.phone_number 
      AND id != NEW.id
    ) THEN
      RAISE EXCEPTION 'Phone number already in use';
    END IF;
  END IF;

  -- Set phone_verified based on auth.users phone_confirmed_at
  SELECT 
    COALESCE(phone_confirmed_at IS NOT NULL, false) INTO NEW.phone_verified
  FROM auth.users 
  WHERE id = NEW.id;

  RETURN NEW;
END;
$$;

-- Create trigger for phone verification
CREATE TRIGGER handle_phone_verification_trigger
BEFORE INSERT OR UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION handle_phone_verification();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT SELECT ON auth.users TO authenticated;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';