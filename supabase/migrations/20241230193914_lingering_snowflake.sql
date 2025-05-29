/*
  # Add ratings system

  1. Tables
    - Create ratings table with user and loop references
    - Add constraints for valid ratings (1-5)
    - Ensure unique ratings per user/loop pair

  2. Functions & Triggers
    - Add function to update loop average ratings
    - Create trigger for automatic rating updates

  3. Security
    - Enable RLS
    - Set up policies for viewing and managing ratings

  4. Performance
    - Add indexes for common queries
*/

-- Create ratings table if it doesn't exist
CREATE TABLE IF NOT EXISTS ratings (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  loop_id uuid REFERENCES loops(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  rating integer CHECK (rating >= 1 AND rating <= 5),
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(loop_id, user_id)
);

-- Create function to update average rating
CREATE OR REPLACE FUNCTION update_loop_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE loops
  SET average_rating = (
    SELECT ROUND(AVG(rating)::numeric, 2)
    FROM ratings
    WHERE loop_id = NEW.loop_id
  )
  WHERE id = NEW.loop_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for rating updates
DROP TRIGGER IF EXISTS update_loop_rating_trigger ON ratings;
CREATE TRIGGER update_loop_rating_trigger
AFTER INSERT OR UPDATE OR DELETE ON ratings
FOR EACH ROW
EXECUTE FUNCTION update_loop_rating();

-- Enable RLS
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Ratings are viewable by everyone" ON ratings;
DROP POLICY IF EXISTS "Authenticated users can rate loops" ON ratings;
DROP POLICY IF EXISTS "Users can update their own ratings" ON ratings;

-- Create RLS policies
CREATE POLICY "Ratings are viewable by everyone"
  ON ratings FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can rate loops"
  ON ratings FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update their own ratings"
  ON ratings FOR UPDATE
  USING (auth.uid() = user_id);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_ratings_loop_id ON ratings(loop_id);
CREATE INDEX IF NOT EXISTS idx_ratings_user_id ON ratings(user_id);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';