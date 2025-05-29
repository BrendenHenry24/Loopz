/*
  # Fix Phone Number Validation

  1. Changes
    - Update phone number validation regex to accept common formats
    - Fix phone number cleaning in trigger
    - Maintain proper validation rules
    
  2. Security
    - Maintain RLS policies
    - Ensure proper validation
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_phone_verification_trigger ON profiles;
DROP FUNCTION IF EXISTS handle_phone_verification();

-- Create improved function to handle phone verification
CREATE OR REPLACE FUNCTION handle_phone_verification()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
BEGIN
  -- Basic phone number validation
  IF NEW.phone_number IS NOT NULL THEN
    -- Clean the phone number - remove spaces, parentheses, and hyphens
    NEW.phone_number := regexp_replace(NEW.phone_number, '[[:space:]()-]', '', 'g');
    
    -- Ensure it starts with + if not already
    IF NEW.phone_number !~ '^\+' THEN
      NEW.phone_number := '+' || NEW.phone_number;
    END IF;

    -- Validate the cleaned number
    IF NEW.phone_number !~ '^\+1[0-9]{10}$' THEN
      RAISE EXCEPTION 'Invalid phone number format. Must be a valid US number (+1 followed by 10 digits)';
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

  -- Only allow phone_verified to be set to true if phone is verified in auth.users
  IF NEW.phone_verified IS DISTINCT FROM OLD.phone_verified AND NEW.phone_verified = true THEN
    IF NOT EXISTS (
      SELECT 1 
      FROM auth.users 
      WHERE id = NEW.id 
      AND phone_confirmed_at IS NOT NULL
      AND phone = NEW.phone_number
    ) THEN
      -- Reset phone_verified to false if not verified in auth.users
      NEW.phone_verified := false;
    END IF;
  END IF;

  -- Automatically set phone_verified based on auth.users status
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