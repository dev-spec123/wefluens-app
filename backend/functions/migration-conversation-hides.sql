-- migration-conversation-hides.sql
-- Adds swipe-to-delete (hide conversation) support for the chat list.
--
-- Run this inside the Supabase SQL Editor after the delete-recall-clear migrations.
-- All changes are additive — no existing columns or policies are dropped.

begin;

-- ── 1. conversation_hides table ──────────────────────────────────────────────
create table if not exists public.conversation_hides (
  user_id           uuid not null references public.profiles(id) on delete cascade,
  conversation_id   uuid not null,
  conversation_type text not null check (conversation_type in ('dm','group')),
  hidden_at         timestamptz not null default now(),
  primary key (user_id, conversation_id, conversation_type)
);

comment on table public.conversation_hides is 'A user hides a conversation from their chat list. New messages after hidden_at make it reappear.';

alter table public.conversation_hides enable row level security;
create policy "Users can read own hides"
  on public.conversation_hides for select
  using (auth.uid() = user_id);
create policy "Users can insert own hides"
  on public.conversation_hides for insert
  with check (auth.uid() = user_id);
create policy "Users can delete own hides"
  on public.conversation_hides for delete
  using (auth.uid() = user_id);

commit;
