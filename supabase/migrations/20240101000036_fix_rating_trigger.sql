-- First drop the trigger, then the function
DROP TRIGGER IF EXISTS update_ratings_trigger ON ratings;
DROP FUNCTION IF EXISTS update_ratings();

-- Create improved function to update both loop and profile ratings
CREATE OR REPLACE FUNCTION update_ratings()
RETURNS TRIGGER AS $$
DECLARE
  _producer_id uuid;
  _loop_rating numeric;
BEGIN
  -- Get the producer_id for the loop
  SELECT producer_id INTO STRICT _producer_id
  FROM loops
  WHERE id = COALESCE(NEW.loop_id, OLD.loop_id);

  IF TG_OP = 'DELETE' THEN
    -- Calculate and update loop rating
    SELECT COALESCE(ROUND(AVG(rating)::numeric, 2), 0) INTO _loop_rating
    FROM ratings
    WHERE loop_id = OLD.loop_id;
    
    UPDATE loops
    SET average_rating = _loop_rating
    WHERE id = OLD.loop_id;
    
  ELSE -- INSERT or UPDATE
    -- Calculate and update loop rating
    SELECT COALESCE(ROUND(AVG(rating)::numeric, 2), 0) INTO _loop_rating
    FROM ratings
    WHERE loop_id = NEW.loop_id;
    
    UPDATE loops
    SET average_rating = _loop_rating
    WHERE id = NEW.loop_id;
  END IF;

  -- Update producer's average rating
  UPDATE profiles
  SET average_loop_rating = (
    SELECT COALESCE(ROUND(AVG(average_rating)::numeric, 2), 0)
    FROM loops
    WHERE producer_id = _producer_id
    AND average_rating > 0
  )
  WHERE id = _producer_id;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create trigger for all rating changes
CREATE TRIGGER update_ratings_trigger
AFTER INSERT OR UPDATE OR DELETE ON ratings
FOR EACH ROW
EXECUTE FUNCTION update_ratings();

-- Reset and recalculate all ratings
UPDATE loops
SET average_rating = 0;

UPDATE profiles
SET average_loop_rating = 0;

-- Update loop ratings
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

-- Update profile ratings
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

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';