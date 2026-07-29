-- Meridian safe Supabase schema
-- This script is intentionally NON-DESTRUCTIVE:
-- it does not DROP tables, policies, triggers, indexes, or data.
-- Run it in Supabase SQL Editor.

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

-- Create or safely update policies without DROP POLICY.
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='profiles_select_own') then
    create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);
  else
    alter policy "profiles_select_own" on public.profiles using (auth.uid() = id);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='profiles_update_own') then
    create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
  else
    alter policy "profiles_update_own" on public.profiles using (auth.uid() = id) with check (auth.uid() = id);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='activities' and policyname='activities_all_own') then
    create policy "activities_all_own" on public.activities for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
  else
    alter policy "activities_all_own" on public.activities using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='events' and policyname='events_all_own') then
    create policy "events_all_own" on public.events for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
  else
    alter policy "events_all_own" on public.events using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='goals' and policyname='goals_all_own') then
    create policy "goals_all_own" on public.goals for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
  else
    alter policy "goals_all_own" on public.goals using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
end $$;

-- Profile creation is performed by this trusted database trigger.
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
    lower(coalesce(new.raw_user_meta_data->>'username', split_part(coalesce(new.email, ''), '@', 1)))
  )
  on conflict (id) do update set username = excluded.username;
  return new;
end;
$$;

-- Create the trigger only when it is missing. No DROP TRIGGER is used.
do $$
begin
  if not exists (
    select 1
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where t.tgname = 'on_auth_user_created_meridian'
      and c.relname = 'users'
      and n.nspname = 'auth'
      and not t.tgisinternal
  ) then
    create trigger on_auth_user_created_meridian
      after insert on auth.users
      for each row execute function public.handle_new_meridian_user();
  end if;
end $$;

-- Recommended Supabase Auth settings:
-- Authentication -> Providers -> Email -> Enable Email provider = ON
-- Authentication -> Providers -> Email -> Confirm email = OFF
-- Authentication -> Settings -> Allow new users to sign up = ON
-- This app uses username@meridian.local internally because Supabase password auth
-- requires an email or phone identifier, while the UI exposes username + password.
