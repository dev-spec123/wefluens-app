-- migration-profiles-app-compat.sql
-- Makes the live `profiles` table compatible with the iOS app (WeConnect) and its
-- SQL functions, which were written against a different column set than this DB
-- actually has.
--
-- The app reads/writes: name, handle, avatar_url, followers, engagement, deals,
-- bio, location, is_admin, is_full_access, is_banned, terms_accepted_at — none of
-- which existed here. This DB instead has full_name, display_name, username,
-- creator_handle, is_super_admin, disabled, brand_id, company, permissions.
--
-- Symptoms this fixes:
--   * search_users() / are_friends-based search erroring on missing columns
--     ("column p.name does not exist") → Add Friend search broken.
--   * Profile rows never being created: the app's profile upsert omits this
--     table's extra NOT-NULL columns, so the insert fails and is swallowed —
--     which is why a freshly-signed-up user has an auth.users row but no
--     profiles row.
--   * browse_top_talent (new Top Talent directory) needs the same columns.
--
-- Approach: ADDITIVE. We add the app's columns alongside the existing ones and
-- give the other-system columns safe defaults so app-driven inserts succeed. This
-- is a compatibility shim, not a true reconciliation — `name`/`full_name` and
-- `handle`/`creator_handle` now coexist and can drift. Resolving the two-schema
-- split properly is a separate, larger task.
--
-- Run this BEFORE migration-full-completion.sql. Idempotent / safe to re-run.

begin;

-- 1. Let app-driven inserts succeed. The app's profile upsert provides only its
--    own columns, so anything else that's NOT NULL must have a default, and role
--    must tolerate being unset at create time (the app creates the row first,
--    sets the role later). Setting an existing default again is harmless.
alter table public.profiles alter column role drop not null;
alter table public.profiles alter column role set default '';

-- These may already have defaults; (re)setting is idempotent and only affects
-- future inserts that omit the column — existing rows are untouched.
alter table public.profiles alter column must_change_password set default false;
alter table public.profiles alter column disabled set default false;
alter table public.profiles alter column is_super_admin set default false;
alter table public.profiles alter column permissions set default '{}'::jsonb;

-- 2. Add the columns the app + its functions expect.
alter table public.profiles add column if not exists name text;
alter table public.profiles add column if not exists handle text;
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists followers text default '0';
alter table public.profiles add column if not exists engagement text default '0%';
alter table public.profiles add column if not exists deals text default '0';
alter table public.profiles add column if not exists bio text;
alter table public.profiles add column if not exists location text;
alter table public.profiles add column if not exists is_admin boolean not null default false;
alter table public.profiles add column if not exists is_full_access boolean not null default true;
alter table public.profiles add column if not exists is_banned boolean not null default false;
alter table public.profiles add column if not exists terms_accepted_at timestamptz;
alter table public.profiles add column if not exists updated_at timestamptz default now();

-- 3. Backfill the app columns from the existing ones for current rows. Only fills
--    where the app column is still empty, so re-running won't clobber app edits.
update public.profiles set
  name   = coalesce(name, display_name, full_name, username),
  handle = coalesce(handle, creator_handle, username)
where name is null or handle is null;

-- Map the existing admin / disabled flags onto the app's flags.
update public.profiles set is_admin  = true where coalesce(is_super_admin, false) = true and is_admin = false;
update public.profiles set is_banned = true where coalesce(disabled, false)        = true and is_banned = false;

commit;

-- NOTE: name/handle now mirror display_name/creator_handle at migration time but
-- are written independently by the app afterward. If another system relies on
-- full_name/creator_handle, decide on a single source of truth and keep them in
-- sync (a trigger, or generated columns) as a follow-up.
