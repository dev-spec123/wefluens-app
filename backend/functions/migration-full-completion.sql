-- migration-full-completion.sql
-- Schema for the "full completion" feature pass. Adds, in one idempotent script:
--   1. profiles prefs columns  — notifications_enabled, activity_status, data_sharing
--   2. device_tokens           — APNs device tokens for push (send-path stubbed)
--   3. favorites               — cloud-synced saved messages (was local-only)
--   4. support_tickets         — in-app support tickets (emailed via Resend)
--   5. browse_top_talent()     — privacy-safe creator directory RPC
--
-- Safe to re-run: every CREATE is IF NOT EXISTS / OR REPLACE, every policy is
-- dropped before being (re)created, every column add is IF NOT EXISTS.

begin;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. profiles preference columns
--
-- notifications_enabled — mirrors the Me-tab "Push Notifications" toggle. The
--   send path (send-push) only delivers to users whose flag is true.
-- activity_status       — when false, this user's online/isOnline dot is hidden
--   from others (gates what `is_online` other clients are allowed to show).
-- data_sharing          — when false, the user is excluded from the Top Talent
--   directory (browse_top_talent). Direct handle/email search is unaffected: if
--   someone already knows your exact handle they can still send a request.
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.profiles
  add column if not exists notifications_enabled boolean not null default true;
alter table public.profiles
  add column if not exists activity_status boolean not null default true;
alter table public.profiles
  add column if not exists data_sharing boolean not null default true;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. device_tokens — one row per (user, device) APNs token
--
-- The client inserts/updates its own token after the OS grants notification
-- permission. `token` is unique so re-registering the same device is an upsert,
-- not a duplicate. RLS: a user only ever sees / writes their own tokens; the
-- send path reads them with the service role (bypasses RLS).
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.device_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  token       text not null unique,
  platform    text not null default 'ios',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists device_tokens_user_id_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

drop policy if exists device_tokens_select_own on public.device_tokens;
create policy device_tokens_select_own on public.device_tokens
  for select using (auth.uid() = user_id);

drop policy if exists device_tokens_insert_own on public.device_tokens;
create policy device_tokens_insert_own on public.device_tokens
  for insert with check (auth.uid() = user_id);

drop policy if exists device_tokens_update_own on public.device_tokens;
create policy device_tokens_update_own on public.device_tokens
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists device_tokens_delete_own on public.device_tokens;
create policy device_tokens_delete_own on public.device_tokens
  for delete using (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. favorites — cloud-synced saved (收藏) messages
--
-- Replaces the on-device UserDefaults store. `message_id` is the original chat
-- message id; (user_id, message_id) is unique so re-favoriting is idempotent
-- (upsert). Fields mirror the old Favorite struct so the client maps 1:1.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.favorites (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  message_id  uuid not null,
  text        text not null default '',
  kind        text not null default 'text',
  sender      text not null default '',
  source      text not null default 'dm',
  saved_at    timestamptz not null default now(),
  unique (user_id, message_id)
);

create index if not exists favorites_user_id_saved_at_idx
  on public.favorites (user_id, saved_at desc);

alter table public.favorites enable row level security;

drop policy if exists favorites_select_own on public.favorites;
create policy favorites_select_own on public.favorites
  for select using (auth.uid() = user_id);

drop policy if exists favorites_insert_own on public.favorites;
create policy favorites_insert_own on public.favorites
  for insert with check (auth.uid() = user_id);

drop policy if exists favorites_delete_own on public.favorites;
create policy favorites_delete_own on public.favorites
  for delete using (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. support_tickets — in-app support / contact requests
--
-- The client inserts a ticket (RLS: own rows). The submit-support-ticket edge
-- function (service role) also writes here and emails support@ via Resend. The
-- user can read back their own tickets; admins can read all.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.support_tickets (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  subject     text not null,
  body        text not null,
  status      text not null default 'open',
  created_at  timestamptz not null default now()
);

create index if not exists support_tickets_user_id_idx on public.support_tickets (user_id);

alter table public.support_tickets enable row level security;

drop policy if exists support_tickets_select_own on public.support_tickets;
create policy support_tickets_select_own on public.support_tickets
  for select using (
    auth.uid() = user_id
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
  );

drop policy if exists support_tickets_insert_own on public.support_tickets;
create policy support_tickets_insert_own on public.support_tickets
  for insert with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. browse_top_talent() — privacy-safe creator directory
--
-- Returns profiles ranked for the "Top Talent" directory, EXCLUDING:
--   * the caller themselves
--   * anyone who turned Data Sharing off (data_sharing = false)
--   * anyone the caller has blocked or who has blocked the caller
-- Email is never returned (mirrors search_users). `relationship` reports the
-- caller's standing with each result so the directory can show Add / Pending /
-- Friends without a second round-trip. SECURITY DEFINER so it can read across
-- profiles under controlled columns; granted to authenticated only.
--
-- Ranking: followers are stored as display strings ("12.4K", "1.2M"), so we sort
-- by a parsed numeric magnitude (see followers_magnitude) descending.
-- ─────────────────────────────────────────────────────────────────────────────

-- Helper: parse a display follower count ("12.4K" / "1.2M" / "950") to a number
-- for ranking. Immutable so it can be used in ORDER BY cheaply.
create or replace function public.followers_magnitude(display text)
returns numeric
language sql
immutable
as $$
  select case
    when display is null or btrim(display) = '' then 0
    when right(btrim(display), 1) in ('M', 'm')
      then coalesce(nullif(regexp_replace(display, '[^0-9.]', '', 'g'), '')::numeric, 0) * 1000000
    when right(btrim(display), 1) in ('K', 'k')
      then coalesce(nullif(regexp_replace(display, '[^0-9.]', '', 'g'), '')::numeric, 0) * 1000
    else coalesce(nullif(regexp_replace(display, '[^0-9.]', '', 'g'), '')::numeric, 0)
  end
$$;

-- Column set + names mirror search_users so the client decodes both into the same
-- SearchUserResult struct and reuses the same add-friend row/actions. Email is
-- never returned; incoming_request_id lets a "request_received" row be accepted
-- inline without a second lookup.
create or replace function public.browse_top_talent(limit_count int default 50)
returns table (
  id                  uuid,
  name                text,
  handle              text,
  role                text,
  avatar_url          text,
  followers           text,
  relationship        text,
  incoming_request_id uuid
)
language sql
security definer
set search_path = public
as $$
  select
    p.id,
    coalesce(p.name, '')   as name,
    coalesce(p.handle, '') as handle,
    coalesce(p.role, '')   as role,
    p.avatar_url,
    coalesce(p.followers, '') as followers,
    case
      when exists (
        select 1 from public.friendships f
        where (f.user_id = auth.uid() and f.friend_id = p.id)
           or (f.friend_id = auth.uid() and f.user_id = p.id)
      ) then 'friends'
      when exists (
        select 1 from public.friend_requests r
        where r.from_user_id = auth.uid() and r.to_user_id = p.id and r.status = 'pending'
      ) then 'request_sent'
      when exists (
        select 1 from public.friend_requests r
        where r.from_user_id = p.id and r.to_user_id = auth.uid() and r.status = 'pending'
      ) then 'request_received'
      else 'none'
    end as relationship,
    (
      select r.id from public.friend_requests r
      where r.from_user_id = p.id and r.to_user_id = auth.uid() and r.status = 'pending'
      limit 1
    ) as incoming_request_id
  from public.profiles p
  where p.id <> auth.uid()
    and coalesce(p.data_sharing, true) = true
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by public.followers_magnitude(p.followers) desc, p.created_at desc
  limit greatest(1, least(limit_count, 200))
$$;

grant execute on function public.browse_top_talent(int) to authenticated;

commit;

-- NOTE: column names above were verified against the live queries in
-- AppDataService.swift — friendships(user_id, friend_id),
-- friend_requests(from_user_id, to_user_id, status), blocks(blocker_id,
-- blocked_id). If the schema diverges, adjust the EXISTS clauses before applying.
