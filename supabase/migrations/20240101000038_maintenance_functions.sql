-- Create function to fix all ratings
CREATE OR REPLACE FUNCTION fix_all_ratings()
RETURNS void AS $$
BEGIN
  -- Reset all ratings
  UPDATE loops SET average_rating = 0;
  UPDATE profiles SET average_loop_rating = 0;

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
END;
$$ LANGUAGE plpgsql;

-- Create function to clean up database
CREATE OR REPLACE FUNCTION cleanup_database()
RETURNS void AS $$
BEGIN
  -- Delete orphaned ratings
  DELETE FROM ratings r
  WHERE NOT EXISTS (
    SELECT 1 FROM loops l WHERE l.id = r.loop_id
  );

  -- Delete orphaned downloads
  DELETE FROM downloads d
  WHERE NOT EXISTS (
    SELECT 1 FROM loops l WHERE l.id = d.loop_id
  );

  -- Delete orphaned follows
  DELETE FROM follows f
  WHERE NOT EXISTS (
    SELECT 1 FROM profiles p WHERE p.id = f.follower_id
  )
  OR NOT EXISTS (
    SELECT 1 FROM profiles p WHERE p.id = f.following_id
  );
END;
$$ LANGUAGE plpgsql;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';