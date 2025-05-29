/*
  # Fix Profile Deletion System

  1. Changes
    - Update RLS policies to allow proper deletion
    - Add cascading deletes for related tables
    - Ensure proper cleanup of user data
    
  2. Security
    - Maintain data integrity
    - Only allow authorized deletions
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;

-- Create improved policies
CREATE POLICY "Public profiles are viewable by everyone"
ON profiles FOR SELECT
USING (true);

CREATE POLICY "Users can insert their own profile"
ON profiles FOR INSERT
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can delete own profile"
ON profiles FOR DELETE
USING (auth.uid() = id);

-- Ensure cascading deletes are set up properly
ALTER TABLE loops
DROP CONSTRAINT IF EXISTS loops_producer_id_fkey,
ADD CONSTRAINT loops_producer_id_fkey
  FOREIGN KEY (producer_id)
  REFERENCES profiles(id)
  ON DELETE CASCADE;

ALTER TABLE ratings
DROP CONSTRAINT IF EXISTS ratings_user_id_fkey,
ADD CONSTRAINT ratings_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES profiles(id)
  ON DELETE CASCADE;

ALTER TABLE downloads
DROP CONSTRAINT IF EXISTS downloads_user_id_fkey,
ADD CONSTRAINT downloads_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES profiles(id)
  ON DELETE CASCADE;

ALTER TABLE follows
DROP CONSTRAINT IF EXISTS follows_follower_id_fkey,
ADD CONSTRAINT follows_follower_id_fkey
  FOREIGN KEY (follower_id)
  REFERENCES profiles(id)
  ON DELETE CASCADE;

ALTER TABLE follows
DROP CONSTRAINT IF EXISTS follows_following_id_fkey,
ADD CONSTRAINT follows_following_id_fkey
  FOREIGN KEY (following_id)
  REFERENCES profiles(id)
  ON DELETE CASCADE;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';