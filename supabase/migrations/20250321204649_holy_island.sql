/*
  # Add Username Change System

  1. Changes
    - Add last_username_change column to profiles
    - Add function to check username change availability
    - Add trigger to handle username changes
    - Update profile update policies
    
  2. Security
    - Maintain RLS policies
    - Ensure proper validation
*/

-- Add column to track last username change
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS last_username_change timestamptz DEFAULT NULL;

-- Create function to check if username change is available
CREATE OR REPLACE FUNCTION can_change_username(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN (
    SELECT
      -- Allow change if:
      -- 1. Never changed username before (last_username_change is null) OR
      -- 2. Last change was more than 7 days ago
      last_username_change IS NULL OR
      last_username_change < NOW() - INTERVAL '7 days'
    FROM profiles
    WHERE id = user_id
  );
END;
$$;

-- Drop existing profile update trigger and function
DROP TRIGGER IF EXISTS handle_profile_update_trigger ON profiles;
DROP FUNCTION IF EXISTS handle_profile_update();

-- Create improved function to handle profile updates
CREATE OR REPLACE FUNCTION handle_profile_update()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Validate username if being updated
  IF NEW.username IS DISTINCT FROM OLD.username THEN
    -- Check if username change is allowed
    IF NOT can_change_username(NEW.id) THEN
      RAISE EXCEPTION 'Username can only be changed once every 7 days';
    END IF;

    -- Check if new username is taken
    IF EXISTS (
      SELECT 1 FROM profiles
      WHERE username = NEW.username
      AND id != NEW.id
    ) THEN
      RAISE EXCEPTION 'Username already taken';
    END IF;

    -- Update last_username_change timestamp
    NEW.last_username_change = NOW();
  END IF;

  -- Prevent modification of protected fields
  NEW.id := OLD.id;
  NEW.created_at := OLD.created_at;
  NEW.membership_tier := OLD.membership_tier;
  NEW.storage_used := OLD.storage_used;
  NEW.total_uploads := OLD.total_uploads;
  NEW.total_downloads := OLD.total_downloads;
  NEW.average_loop_rating := OLD.average_loop_rating;
  NEW.followers_count := OLD.followers_count;
  NEW.following_count := OLD.following_count;

  RETURN NEW;
END;
$$;

-- Create trigger for profile updates
CREATE TRIGGER handle_profile_update_trigger
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION handle_profile_update();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT EXECUTE ON FUNCTION can_change_username(uuid) TO authenticated;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';