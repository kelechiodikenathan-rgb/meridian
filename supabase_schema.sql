-- Meridian backend schema for Supabase
-- Run this entire file in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.activities (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  category text not null,
  start text not null,
  "end" text not null,
  note text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.events (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  title text not null,
  time text not null default '',
  note text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.goals (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  scope text not null,
  period_key text not null,
  text text not null,
  done boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists activities_user_date_idx on public.activities(user_id, date);
create index if not exists events_user_date_idx on public.events(user_id, date);
create index if not exists goals_user_period_idx on public.goals(user_id, scope, period_key);

alter table public.profiles enable row level security;
alter table public.activities enable row level security;
alter table public.events enable row level security;
alter table public.goals enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "activities_all_own" on public.activities;
create policy "activities_all_own" on public.activities
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "events_all_own" on public.events;
create policy "events_all_own" on public.events
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "goals_all_own" on public.goals;
create policy "goals_all_own" on public.goals
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Automatically create a profile row from the username supplied at signup.
create or replace function public.handle_new_meridian_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    lower(coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_meridian on auth.users;
create trigger on_auth_user_created_meridian
  after insert on auth.users
  for each row execute procedure public.handle_new_meridian_user();

-- Important:
-- In Supabase Dashboard > Authentication > Providers > Email,
-- turn OFF "Confirm email" for this username-only login flow.
-- Never expose a Supabase service_role key in this project.
