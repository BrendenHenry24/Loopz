/*
  # Add Phone Verification System
  
  1. Changes
    - Add phone number and verification columns
    - Create improved phone verification trigger
    - Add phone number validation
    
  2. Security
    - Maintain phone uniqueness
    - Validate phone format
*/

-- Drop existing trigger and function if they exist
DROP TRIGGER IF EXISTS handle_phone_verification_trigger ON profiles;
DROP TRIGGER IF EXISTS validate_phone_number_trigger ON profiles;
DROP FUNCTION IF EXISTS handle_phone_verification();
DROP FUNCTION IF EXISTS validate_phone_number();

-- Add phone columns if they don't exist
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS phone_number text UNIQUE,
ADD COLUMN IF NOT EXISTS phone_verified boolean DEFAULT false;

-- Create improved function to handle phone verification
CREATE OR REPLACE FUNCTION handle_phone_verification()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

-- Create new trigger for phone handling
CREATE TRIGGER handle_phone_verification_trigger
BEFORE INSERT OR UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION handle_phone_verification();

-- Create function to sync verification status
CREATE OR REPLACE FUNCTION sync_phone_verification()
RETURNS void AS $$
BEGIN
  UPDATE profiles p
  SET phone_verified = EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE u.id = p.id
    AND u.phone_confirmed_at IS NOT NULL
  );
END;
$$ LANGUAGE plpgsql;

-- Run initial sync
SELECT sync_phone_verification();

-- Create index for phone number lookups
CREATE INDEX IF NOT EXISTS idx_profiles_phone_number 
ON profiles(phone_number);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';