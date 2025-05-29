-- Create profiles table
create table profiles (
  id uuid references auth.users on delete cascade,
  username text unique,
  email text unique,
  avatar_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (id)
);

-- Create loops table
create table loops (
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

-- Create ratings table
create table ratings (
  id uuid default uuid_generate_v4() primary key,
  loop_id uuid references loops(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  rating integer check (rating >= 1 and rating <= 5),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(loop_id, user_id)
);

-- Create downloads table
create table downloads (
  id uuid default uuid_generate_v4() primary key,
  loop_id uuid references loops(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create function to increment downloads
create or replace function increment_downloads(loop_id uuid)
returns void as $$
begin
  update loops
  set downloads = downloads + 1
  where id = loop_id;
end;
$$ language plpgsql;

-- Set up storage
insert into storage.buckets (id, name)
values ('loops', 'loops');

-- Set up storage policies
create policy "Loops are publicly accessible"
  on storage.objects for select
  using ( bucket_id = 'loops' );

create policy "Authenticated users can upload loops"
  on storage.objects for insert
  with check ( bucket_id = 'loops' AND auth.role() = 'authenticated' );

-- Enable Row Level Security
alter table profiles enable row level security;
alter table loops enable row level security;
alter table ratings enable row level security;
alter table downloads enable row level security;

-- Set up Row Level Security policies
create policy "Public profiles are viewable by everyone"
  on profiles for select
  using ( true );

create policy "Users can update own profile"
  on profiles for update
  using ( auth.uid() = id );

create policy "Loops are viewable by everyone"
  on loops for select
  using ( true );

create policy "Authenticated users can create loops"
  on loops for insert
  with check ( auth.role() = 'authenticated' );

create policy "Producers can update own loops"
  on loops for update
  using ( auth.uid() = producer_id );

create policy "Authenticated users can rate loops"
  on ratings for insert
  with check ( auth.role() = 'authenticated' );

create policy "Users can update own ratings"
  on ratings for update
  using ( auth.uid() = user_id );

create policy "Downloads are recorded for authenticated users"
  on downloads for insert
  with check ( auth.role() = 'authenticated' );