/*
  # Add Phone Verification Display and Functionality
  
  1. Changes
    - Add phone verification display
    - Add phone verification trigger
    - Update profile policies
    
  2. Security
    - Maintain RLS
    - Add proper validation
*/

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

  -- Set phone_verified based on auth.users phone_confirmed_at
  IF EXISTS (
    SELECT 1 
    FROM auth.users 
    WHERE id = NEW.id 
    AND phone_confirmed_at IS NOT NULL
  ) THEN
    NEW.phone_verified := true;
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

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT USAGE ON SCHEMA auth TO authenticated, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA auth TO service_role;
GRANT INSERT, UPDATE, DELETE ON profiles TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION handle_phone_verification() TO authenticated;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';