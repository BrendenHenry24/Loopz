/*
  # Add Phone Verification System

  1. Changes
    - Add phone verification columns to profiles table
    - Create function to handle phone verification
    - Add trigger for phone verification updates
    - Update RLS policies
    
  2. Security
    - Maintain RLS policies
    - Ensure proper validation
*/

-- Add phone verification columns if they don't exist
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS phone_number text UNIQUE,
ADD COLUMN IF NOT EXISTS phone_verified boolean DEFAULT false;

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

-- Create index for phone number lookups
CREATE INDEX IF NOT EXISTS idx_profiles_phone_number 
ON profiles(phone_number);

-- Drop existing policies
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON profiles;

-- Create improved policies
CREATE POLICY "Public profiles are viewable by everyone"
ON profiles FOR SELECT
USING (true);

CREATE POLICY "Users can insert their own profile"
ON profiles FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated' AND
  auth.uid() = id
);

CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can delete own profile"
ON profiles FOR DELETE
USING (auth.uid() = id);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT USAGE ON SCHEMA auth TO authenticated, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA auth TO service_role;
GRANT INSERT, UPDATE, DELETE ON profiles TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION handle_phone_verification() TO authenticated;

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';