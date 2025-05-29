/*
  # Fix Rating Policies
  
  1. Changes
    - Replace check constraint with trigger-based validation
    - Update RLS policies for better security
    - Add performance optimizations
    
  2. Security
    - Prevent self-rating through BEFORE trigger
    - Proper RLS policies for all operations
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Ratings are viewable by everyone" ON ratings;
DROP POLICY IF EXISTS "Authenticated users can rate loops" ON ratings;
DROP POLICY IF EXISTS "Users can update their own ratings" ON ratings;
DROP POLICY IF EXISTS "Users can delete their own ratings" ON ratings;

-- Create function to validate rating
CREATE OR REPLACE FUNCTION validate_rating()
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

-- Create trigger for rating validation
DROP TRIGGER IF EXISTS validate_rating_trigger ON ratings;
CREATE TRIGGER validate_rating_trigger
BEFORE INSERT OR UPDATE ON ratings
FOR EACH ROW
EXECUTE FUNCTION validate_rating();

-- Create improved policies with proper checks
CREATE POLICY "Ratings are viewable by everyone"
ON ratings FOR SELECT
USING (true);

CREATE POLICY "Authenticated users can rate loops"
ON ratings FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated' AND
  auth.uid() = user_id
);

CREATE POLICY "Users can update their own ratings"
ON ratings FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own ratings"
ON ratings FOR DELETE
USING (auth.uid() = user_id);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_ratings_user_loop 
ON ratings(user_id, loop_id);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';