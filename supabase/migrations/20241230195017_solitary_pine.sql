-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS update_ratings_trigger ON ratings;
DROP TRIGGER IF EXISTS validate_rating_trigger ON ratings;
DROP FUNCTION IF EXISTS update_ratings();
DROP FUNCTION IF EXISTS validate_rating();

-- Create improved function to update ratings
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

  -- Validate rating (for INSERT and UPDATE)
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    -- Check if user exists in profiles
    IF NOT EXISTS (
      SELECT 1 FROM profiles WHERE id = NEW.user_id
    ) THEN
      RAISE EXCEPTION 'User profile does not exist';
    END IF;

    -- Check for self-rating
    IF _producer_id = NEW.user_id THEN
      RAISE EXCEPTION 'Users cannot rate their own loops';
    END IF;
  END IF;

  -- Update ratings
  IF TG_OP = 'DELETE' THEN
    -- Calculate and update loop rating
    SELECT COALESCE(ROUND(AVG(rating)::numeric, 2), 0) INTO _loop_rating
    FROM ratings
    WHERE loop_id = OLD.loop_id;
    
    UPDATE loops
    SET average_rating = _loop_rating
    WHERE id = OLD.loop_id;
  ELSE
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
BEFORE INSERT OR UPDATE OR DELETE ON ratings
FOR EACH ROW
EXECUTE FUNCTION update_ratings();

-- Drop existing policies
DROP POLICY IF EXISTS "Ratings are viewable by everyone" ON ratings;
DROP POLICY IF EXISTS "Authenticated users can rate loops" ON ratings;
DROP POLICY IF EXISTS "Users can update their own ratings" ON ratings;
DROP POLICY IF EXISTS "Users can delete their own ratings" ON ratings;

-- Create improved policies
CREATE POLICY "Ratings are viewable by everyone"
ON ratings FOR SELECT
USING (true);

CREATE POLICY "Authenticated users can rate loops"
ON ratings FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated' AND
  auth.uid() = user_id AND
  EXISTS (
    SELECT 1 FROM profiles WHERE id = user_id
  )
);

CREATE POLICY "Users can update their own ratings"
ON ratings FOR UPDATE
USING (
  auth.uid() = user_id AND
  EXISTS (
    SELECT 1 FROM profiles WHERE id = user_id
  )
);

CREATE POLICY "Users can delete their own ratings"
ON ratings FOR DELETE
USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_ratings_loop_user ON ratings(loop_id, user_id);
CREATE INDEX IF NOT EXISTS idx_ratings_user_loop ON ratings(user_id, loop_id);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';