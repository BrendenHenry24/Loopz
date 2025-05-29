-- Drop existing function if it exists
DROP FUNCTION IF EXISTS update_profile_average_rating();

-- Create function to update profile's average loop rating
CREATE OR REPLACE FUNCTION update_profile_average_rating()
RETURNS TRIGGER AS $$
BEGIN
  -- Update the producer's average loop rating
  UPDATE profiles
  SET average_loop_rating = COALESCE(
    (
      SELECT ROUND(AVG(average_rating)::numeric, 2)
      FROM loops
      WHERE producer_id = (
        SELECT producer_id 
        FROM loops 
        WHERE id = COALESCE(NEW.loop_id, OLD.loop_id)
      )
      AND average_rating > 0
    ),
    0
  )
  WHERE id = (
    SELECT producer_id 
    FROM loops 
    WHERE id = COALESCE(NEW.loop_id, OLD.loop_id)
  );

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update profile rating when a loop's rating changes
CREATE TRIGGER update_profile_rating_trigger
AFTER INSERT OR UPDATE OR DELETE ON ratings
FOR EACH ROW
EXECUTE FUNCTION update_profile_average_rating();

-- Fix any existing profile ratings
UPDATE profiles p
SET average_loop_rating = COALESCE(
  (
    SELECT ROUND(AVG(average_rating)::numeric, 2)
    FROM loops l
    WHERE l.producer_id = p.id
    AND l.average_rating > 0
  ),
  0
);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_loops_producer_rating 
ON loops(producer_id, average_rating);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';