/*
  # Fix Profile Fetching System

  1. Changes
    - Add default values for new profiles
    - Ensure membership_tier is always set
    - Add trigger to handle profile creation
    
  2. Security
    - Maintain RLS policies
    - Ensure data consistency
*/

-- Add default values to profiles table
ALTER TABLE profiles
ALTER COLUMN membership_tier SET DEFAULT 'basic',
ALTER COLUMN storage_used SET DEFAULT 0,
ALTER COLUMN total_uploads SET DEFAULT 0,
ALTER COLUMN total_downloads SET DEFAULT 0,
ALTER COLUMN average_loop_rating SET DEFAULT 0.00,
ALTER COLUMN followers_count SET DEFAULT 0,
ALTER COLUMN following_count SET DEFAULT 0;

-- Create function to handle profile creation
CREATE OR REPLACE FUNCTION handle_profile_creation()
RETURNS TRIGGER AS $$
BEGIN
  -- Set default values if not provided
  NEW.membership_tier := COALESCE(NEW.membership_tier, 'basic');
  NEW.storage_used := COALESCE(NEW.storage_used, 0);
  NEW.total_uploads := COALESCE(NEW.total_uploads, 0);
  NEW.total_downloads := COALESCE(NEW.total_downloads, 0);
  NEW.average_loop_rating := COALESCE(NEW.average_loop_rating, 0.00);
  NEW.followers_count := COALESCE(NEW.followers_count, 0);
  NEW.following_count := COALESCE(NEW.following_count, 0);

  -- Get email from auth.users if not provided
  IF NEW.email IS NULL THEN
    SELECT email INTO NEW.email
    FROM auth.users
    WHERE id = NEW.id;
  END IF;

  -- Generate username from email if not provided
  IF NEW.username IS NULL AND NEW.email IS NOT NULL THEN
    NEW.username := split_part(NEW.email, '@', 1);
    
    -- Ensure username uniqueness
    WHILE EXISTS (
      SELECT 1 FROM profiles WHERE username = NEW.username AND id != NEW.id
    ) LOOP
      NEW.username := NEW.username || floor(random() * 1000)::text;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for profile creation
DROP TRIGGER IF EXISTS handle_profile_creation_trigger ON profiles;
CREATE TRIGGER handle_profile_creation_trigger
BEFORE INSERT ON profiles
FOR EACH ROW
EXECUTE FUNCTION handle_profile_creation();

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';