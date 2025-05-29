-- Drop existing triggers
DROP TRIGGER IF EXISTS update_loop_rating_trigger ON ratings;
DROP TRIGGER IF EXISTS update_profile_rating_trigger ON ratings;
DROP FUNCTION IF EXISTS update_loop_rating();
DROP FUNCTION IF EXISTS update_profile_average_rating();

-- Create improved function to update both loop and profile ratings
CREATE OR REPLACE FUNCTION update_ratings()
RETURNS TRIGGER AS $$
DECLARE
  _producer_id uuid;
BEGIN
  -- Get the producer_id for the loop
  SELECT producer_id INTO _producer_id
  FROM loops
  WHERE id = COALESCE(NEW.loop_id, OLD.loop_id);

  IF TG_OP = 'DELETE' THEN
    -- Update loop rating
    UPDATE loops
    SET average_rating = COALESCE(
      (SELECT ROUND(AVG(rating)::numeric, 2)
       FROM ratings
       WHERE loop_id = OLD.loop_id),
      0
    )
    WHERE id = OLD.loop_id;
    
    -- Update producer's average rating
    UPDATE profiles
    SET average_loop_rating = COALESCE(
      (SELECT ROUND(AVG(l.average_rating)::numeric, 2)
       FROM loops l
       WHERE l.producer_id = _producer_id
       AND l.average_rating > 0),
      0
    )
    WHERE id = _producer_id;
    
    RETURN OLD;
  ELSE
    -- Update loop rating
    UPDATE loops
    SET average_rating = COALESCE(
      (SELECT ROUND(AVG(rating)::numeric, 2)
       FROM ratings
       WHERE loop_id = NEW.loop_id),
      0
    )
    WHERE id = NEW.loop_id;
    
    -- Update producer's average rating
    UPDATE profiles
    SET average_loop_rating = COALESCE(
      (SELECT ROUND(AVG(l.average_rating)::numeric, 2)
       FROM loops l
       WHERE l.producer_id = _producer_id
       AND l.average_rating > 0),
      0
    )
    WHERE id = _producer_id;
    
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for all rating changes
CREATE TRIGGER update_ratings_trigger
AFTER INSERT OR UPDATE OR DELETE ON ratings
FOR EACH ROW
EXECUTE FUNCTION update_ratings();

-- Update RLS policies
DROP POLICY IF EXISTS "Ratings are viewable by everyone" ON ratings;
DROP POLICY IF EXISTS "Authenticated users can rate loops" ON ratings;
DROP POLICY IF EXISTS "Users can update their own ratings" ON ratings;
DROP POLICY IF EXISTS "Users can delete their own ratings" ON ratings;

-- Create new policies with proper constraints
CREATE POLICY "Ratings are viewable by everyone"
ON ratings FOR SELECT
USING (true);

CREATE POLICY "Authenticated users can rate loops"
ON ratings FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated' AND
  user_id = auth.uid() AND
  NOT EXISTS (
    SELECT 1 FROM loops 
    WHERE loops.id = loop_id 
    AND loops.producer_id = auth.uid()
  )
);

CREATE POLICY "Users can update their own ratings"
ON ratings FOR UPDATE
USING (
  auth.uid() = user_id AND
  NOT EXISTS (
    SELECT 1 FROM loops 
    WHERE loops.id = loop_id 
    AND loops.producer_id = auth.uid()
  )
);

CREATE POLICY "Users can delete their own ratings"
ON ratings FOR DELETE
USING (auth.uid() = user_id);

-- Fix any existing ratings
WITH loop_ratings AS (
  SELECT 
    loop_id,
    ROUND(AVG(rating)::numeric, 2) as avg_rating
  FROM ratings
  GROUP BY loop_id
)
UPDATE loops l
SET average_rating = COALESCE(lr.avg_rating, 0)
FROM loop_ratings lr
WHERE l.id = lr.loop_id;

WITH producer_ratings AS (
  SELECT 
    l.producer_id,
    ROUND(AVG(l.average_rating)::numeric, 2) as avg_rating
  FROM loops l
  WHERE l.average_rating > 0
  GROUP BY l.producer_id
)
UPDATE profiles p
SET average_loop_rating = COALESCE(pr.avg_rating, 0)
FROM producer_ratings pr
WHERE p.id = pr.producer_id;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_ratings_loop_user ON ratings(loop_id, user_id);
CREATE INDEX IF NOT EXISTS idx_ratings_user_loop ON ratings(user_id, loop_id);
CREATE INDEX IF NOT EXISTS idx_loops_producer_rating ON loops(producer_id, average_rating);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';