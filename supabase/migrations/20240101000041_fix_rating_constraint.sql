-- Drop existing constraint that uses subquery
ALTER TABLE ratings DROP CONSTRAINT IF EXISTS prevent_self_rating;

-- Create function to check self-rating
CREATE OR REPLACE FUNCTION prevent_self_rating()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if user is trying to rate their own loop
  IF EXISTS (
    SELECT 1 FROM loops 
    WHERE id = NEW.loop_id 
    AND producer_id = NEW.user_id
  ) THEN
    RAISE EXCEPTION 'Users cannot rate their own loops';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to prevent self-rating
DROP TRIGGER IF EXISTS prevent_self_rating_trigger ON ratings;
CREATE TRIGGER prevent_self_rating_trigger
BEFORE INSERT OR UPDATE ON ratings
FOR EACH ROW
EXECUTE FUNCTION prevent_self_rating();

-- Update RLS policies to be more explicit
DROP POLICY IF EXISTS "Authenticated users can rate loops" ON ratings;
CREATE POLICY "Authenticated users can rate loops"
ON ratings FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated' AND
  auth.uid() = user_id AND
  auth.uid() != (
    SELECT producer_id 
    FROM loops 
    WHERE id = loop_id
  )
);

DROP POLICY IF EXISTS "Users can update their own ratings" ON ratings;
CREATE POLICY "Users can update their own ratings"
ON ratings FOR UPDATE
USING (
  auth.uid() = user_id AND
  auth.uid() != (
    SELECT producer_id 
    FROM loops 
    WHERE id = loop_id
  )
);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';