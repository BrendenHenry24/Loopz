-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Drop existing policies first
drop policy if exists "Public profiles are viewable by everyone" on profiles;
drop policy if exists "Users can update own profile" on profiles;
drop policy if exists "Users can insert their own profile" on profiles;
drop policy if exists "Loops are viewable by everyone" on loops;
drop policy if exists "Authenticated users can create loops" on loops;
drop policy if exists "Producers can update own loops" on loops;
drop policy if exists "Producers can delete own loops" on loops;
drop policy if exists "Authenticated users can rate loops" on ratings;
drop policy if exists "Users can update own ratings" on ratings;
drop policy if exists "Users can delete own ratings" on ratings;
drop policy if exists "Downloads are recorded for authenticated users" on downloads;
drop policy if exists "Loops are publicly accessible" on storage.objects;
drop policy if exists "Authenticated users can upload loops" on storage.objects;

-- Create tables if they don't exist
create table if not exists profiles (
  id uuid references auth.users on delete cascade primary key,
  username text unique,
  email text unique,
  avatar_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table if not exists loops (
  id uuid default uuid_generate_v4() primary key,
  title text not null,
  producer_id uuid references profiles(id) on delete cascade,
  audio_url text not null,
  bpm integer not null,
  key text not null,
  downloads integer default 0,
  average_rating float default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table if not exists ratings (
  id uuid default uuid_generate_v4() primary key,
  loop_id uuid references loops(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  rating integer check (rating >= 1 and rating <= 5),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(loop_id, user_id)
);

create table if not exists downloads (
  id uuid default uuid_generate_v4() primary key,
  loop_id uuid references loops(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create or replace function for downloads
create or replace function increment_downloads(loop_id uuid)
returns void as $$
begin
  update loops
  set downloads = downloads + 1
  where id = loop_id;
end;
$$ language plpgsql;

-- Set up storage bucket
insert into storage.buckets (id, name, public)
values ('loops', 'loops', true)
on conflict (id) do nothing;

-- Enable RLS
alter table profiles enable row level security;
alter table loops enable row level security;
alter table ratings enable row level security;
alter table downloads enable row level security;

-- Create new policies
create policy "Public profiles are viewable by everyone"
  on profiles for select
  using ( true );

create policy "Users can update own profile"
  on profiles for update
  using ( auth.uid() = id );

create policy "Users can insert their own profile"
  on profiles for insert
  with check ( auth.uid() = id );

create policy "Loops are viewable by everyone"
  on loops for select
  using ( true );

create policy "Authenticated users can create loops"
  on loops for insert
  with check ( auth.role() = 'authenticated' );

create policy "Producers can update own loops"
  on loops for update
  using ( auth.uid() = producer_id );

create policy "Producers can delete own loops"
  on loops for delete
  using ( auth.uid() = producer_id );

create policy "Authenticated users can rate loops"
  on ratings for insert
  with check ( auth.role() = 'authenticated' );

create policy "Users can update own ratings"
  on ratings for update
  using ( auth.uid() = user_id );

create policy "Users can delete own ratings"
  on ratings for delete
  using ( auth.uid() = user_id );

create policy "Downloads are recorded for authenticated users"
  on downloads for insert
  with check ( auth.role() = 'authenticated' );

create policy "Loops are publicly accessible"
  on storage.objects for select
  using ( bucket_id = 'loops' );

create policy "Authenticated users can upload loops"
  on storage.objects for insert
  with check ( bucket_id = 'loops' AND auth.role() = 'authenticated' );

-- Create indexes for better query performance
create index if not exists loops_producer_id_idx on loops(producer_id);
create index if not exists loops_created_at_idx on loops(created_at desc);
create index if not exists loops_downloads_idx on loops(downloads desc);
create index if not exists loops_average_rating_idx on loops(average_rating desc);
create index if not exists ratings_loop_id_idx on ratings(loop_id);
create index if not exists downloads_loop_id_idx on downloads(loop_id);