-- Add membership tier and storage tracking to profiles
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS membership_tier text NOT NULL DEFAULT 'basic'
  CHECK (membership_tier IN ('basic', 'pro', 'enterprise')),
ADD COLUMN IF NOT EXISTS storage_used bigint NOT NULL DEFAULT 0;

-- Add file size tracking to loops
ALTER TABLE loops
ADD COLUMN IF NOT EXISTS file_size bigint NOT NULL DEFAULT 0;

-- Create function to update storage usage
CREATE OR REPLACE FUNCTION update_storage_usage()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Add new file size to user's storage
    UPDATE profiles
    SET storage_used = storage_used + NEW.file_size
    WHERE id = NEW.producer_id;
  ELSIF TG_OP = 'DELETE' THEN
    -- Subtract deleted file size from user's storage
    UPDATE profiles
    SET storage_used = GREATEST(0, storage_used - OLD.file_size)
    WHERE id = OLD.producer_id;
  ELSIF TG_OP = 'UPDATE' AND OLD.file_size != NEW.file_size THEN
    -- Update storage for file size changes
    UPDATE profiles
    SET storage_used = GREATEST(0, storage_used - OLD.file_size + NEW.file_size)
    WHERE id = NEW.producer_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for storage usage updates
CREATE TRIGGER update_storage_usage_trigger
AFTER INSERT OR UPDATE OR DELETE ON loops
FOR EACH ROW
EXECUTE FUNCTION update_storage_usage();

-- Create storage limit check function
CREATE OR REPLACE FUNCTION check_storage_limit()
RETURNS TRIGGER AS $$
DECLARE
  user_tier text;
  user_storage bigint;
  storage_limit bigint;
BEGIN
  -- Get user's membership tier and current storage
  SELECT membership_tier, storage_used
  INTO user_tier, user_storage
  FROM profiles
  WHERE id = NEW.producer_id;

  -- Set storage limit based on tier
  storage_limit := CASE user_tier
    WHEN 'basic' THEN 52428800 -- 50MB
    WHEN 'pro' THEN 104857600 -- 100MB
    WHEN 'enterprise' THEN 262144000 -- 250MB
    ELSE 52428800 -- Default to basic
  END;

  -- Check if new file would exceed limit
  IF user_storage + NEW.file_size > storage_limit THEN
    RAISE EXCEPTION 'Storage limit exceeded for % tier', user_tier;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to check storage limit before insert
CREATE TRIGGER check_storage_limit_trigger
BEFORE INSERT ON loops
FOR EACH ROW
EXECUTE FUNCTION check_storage_limit();

-- Update RLS policies
CREATE POLICY "Users can see their storage usage"
ON profiles
FOR SELECT
USING (auth.uid() = id);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';