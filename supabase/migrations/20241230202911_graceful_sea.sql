/*
  # Add DELETE Policy for Loops Table

  1. Changes
    - Add DELETE policy to allow producers to delete their own loops
    - Ensures proper cascade deletion with storage files

  2. Security
    - Only allows deletion of owned loops
    - Maintains existing RLS policies
*/

-- Drop existing delete policy if it exists
DROP POLICY IF EXISTS "Producers can delete own loops" ON loops;

-- Create DELETE policy
CREATE POLICY "Producers can delete own loops"
ON loops FOR DELETE
USING (auth.uid() = producer_id);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';