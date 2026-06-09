-- migration-delete-recall-clear.sql
-- Add recall + soft-delete + clear-history support to chat.
--
-- Run this inside the Supabase SQL Editor (or via a migration tool).
-- All changes are additive — no existing columns or policies are dropped.

begin;

-- ── 1. Add recalled_at / recalled_by to dm_messages ──────────────────────────
alter table public.dm_messages
  add column if not exists recalled_at timestamptz,
  add column if not exists recalled_by uuid references public.profiles(id);

comment on column public.dm_messages.recalled_at is 'When the message was recalled (non-null = recalled, show placeholder)';
comment on column public.dm_messages.recalled_by is 'Who recalled it (must match sender_id at recall time)';

-- ── 2. Add recalled_at / recalled_by to group_messages ───────────────────────
alter table public.group_messages
  add column if not exists recalled_at timestamptz,
  add column if not exists recalled_by uuid references public.profiles(id);

comment on column public.group_messages.recalled_at is 'When the message was recalled (non-null = recalled, show placeholder)';
comment on column public.group_messages.recalled_by is 'Who recalled it (must match sender_id at recall time)';

-- ── 3. Soft-delete table (one row per deleted message per user) ──────────────
create table if not exists public.message_deletions (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  message_id uuid not null,
  kind       text not null check (kind in ('dm','group')),
  created_at timestamptz not null default now(),
  primary key (user_id, message_id, kind)
);

comment on table public.message_deletions is 'A user hides a single message for themselves (A / local-only soft delete). No physical DELETE.';

-- RLS: each user can only see their own deletions (used during message load).
alter table public.message_deletions enable row level security;
create policy "Users can read own deletions"
  on public.message_deletions for select
  using (auth.uid() = user_id);
create policy "Users can insert own deletions"
  on public.message_deletions for insert
  with check (auth.uid() = user_id);

-- ── 4. DM-clear watermark (one row per thread per user) ──────────────────────
create table if not exists public.dm_clears (
  user_id       uuid not null references public.profiles(id) on delete cascade,
  thread_id     uuid not null references public.dm_threads(id) on delete cascade,
  cleared_before timestamptz not null default now(),
  primary key (user_id, thread_id)
);

comment on table public.dm_clears is 'When a user clears a DM thread, everything before this timestamp is hidden for them only.';

alter table public.dm_clears enable row level security;
create policy "Users can read own dm_clears"
  on public.dm_clears for select
  using (auth.uid() = user_id);
create policy "Users can upsert own dm_clears"
  on public.dm_clears for insert
  with check (auth.uid() = user_id);
create policy "Users can update own dm_clears"
  on public.dm_clears for update
  using (auth.uid() = user_id);

-- ── 5. Group-clear watermark (one row per group per user) ────────────────────
create table if not exists public.group_clears (
  user_id        uuid not null references public.profiles(id) on delete cascade,
  group_id       uuid not null references public.group_threads(id) on delete cascade,
  cleared_before timestamptz not null default now(),
  primary key (user_id, group_id)
);

comment on table public.group_clears is 'When a user clears a group thread, everything before this timestamp is hidden for them only.';

alter table public.group_clears enable row level security;
create policy "Users can read own group_clears"
  on public.group_clears for select
  using (auth.uid() = user_id);
create policy "Users can upsert own group_clears"
  on public.group_clears for insert
  with check (auth.uid() = user_id);
create policy "Users can update own group_clears"
  on public.group_clears for update
  using (auth.uid() = user_id);

commit;
