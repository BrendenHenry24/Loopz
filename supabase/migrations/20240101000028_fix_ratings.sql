-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS update_loop_rating_trigger ON ratings;
DROP FUNCTION IF EXISTS update_loop_rating();

-- Create improved function to update average rating
CREATE OR REPLACE FUNCTION update_loop_rating()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    -- Handle deletion
    UPDATE loops
    SET average_rating = COALESCE(
      (SELECT ROUND(AVG(rating)::numeric, 2)
       FROM ratings
       WHERE loop_id = OLD.loop_id),
      0
    )
    WHERE id = OLD.loop_id;
    
    RETURN OLD;
  ELSE
    -- Handle INSERT or UPDATE
    UPDATE loops
    SET average_rating = COALESCE(
      (SELECT ROUND(AVG(rating)::numeric, 2)
       FROM ratings
       WHERE loop_id = NEW.loop_id),
      0
    )
    WHERE id = NEW.loop_id;
    
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for all rating changes
CREATE TRIGGER update_loop_rating_trigger
AFTER INSERT OR UPDATE OR DELETE ON ratings
FOR EACH ROW
EXECUTE FUNCTION update_loop_rating();

-- Update RLS policies
DROP POLICY IF EXISTS "Authenticated users can rate loops" ON ratings;
DROP POLICY IF EXISTS "Users can update their own ratings" ON ratings;
DROP POLICY IF EXISTS "Users can delete their own ratings" ON ratings;

CREATE POLICY "Authenticated users can rate loops"
ON ratings FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated' AND
  auth.uid() = user_id
);

CREATE POLICY "Users can update their own ratings"
ON ratings FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own ratings"
ON ratings FOR DELETE
USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_ratings_loop_user ON ratings(loop_id, user_id);
CREATE INDEX IF NOT EXISTS idx_ratings_user_loop ON ratings(user_id, loop_id);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';