-- Create storage bucket if it doesn't exist
insert into storage.buckets (id, name, public)
values ('loops', 'loops', false)
on conflict (id) do nothing;

-- Remove any existing policies
drop policy if exists "Authenticated users can upload loops" on storage.objects;
drop policy if exists "Users can view their own loops" on storage.objects;
drop policy if exists "Users can delete their own loops" on storage.objects;
drop policy if exists "Anyone can download published loops" on storage.objects;

-- Create new storage policies with RLS
create policy "Authenticated users can upload loops"
on storage.objects for insert
with check (
  auth.role() = 'authenticated' AND
  bucket_id = 'loops' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can view their own loops"
on storage.objects for select
using (
  bucket_id = 'loops' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

create policy "Users can delete their own loops"
on storage.objects for delete
using (
  bucket_id = 'loops' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

create policy "Anyone can download published loops"
on storage.objects for select
using (
  bucket_id = 'loops' AND
  exists (
    select 1 from public.loops
    where audio_url = name
  )
);