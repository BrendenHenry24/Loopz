-- Add instagram_handle column to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS instagram_handle text DEFAULT NULL;

-- Update RLS policies
CREATE POLICY "Users can update their own instagram_handle"
ON public.profiles
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';