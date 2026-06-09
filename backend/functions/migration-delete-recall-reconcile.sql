-- migration-delete-recall-reconcile.sql
-- Reconciles the live database with the shipped delete/recall/clear design.
--
-- An earlier partial version of these tables/functions was applied to production
-- (message_deletions without a `kind` column; delete_message_for_me / recall_message
-- with a single `p_message_id` arg; dm_clears / group_clears without the composite
-- unique keys the functions' ON CONFLICT needs). This migration brings the live
-- schema up to the design the iOS app actually calls. Fully idempotent + additive.
--
-- Run BEFORE re-applying functions-delete-recall-clear.sql.

begin;

-- ── message_deletions: add `kind` + composite unique (user_id, message_id, kind) ──
alter table public.message_deletions
  add column if not exists kind text;

update public.message_deletions set kind = 'dm' where kind is null;

-- Drop any pre-existing duplicates before enforcing the composite unique key.
delete from public.message_deletions a
using public.message_deletions b
where a.user_id = b.user_id
  and a.message_id = b.message_id
  and coalesce(a.kind, 'dm') = coalesce(b.kind, 'dm')
  and a.ctid < b.ctid;

alter table public.message_deletions alter column kind set default 'dm';
alter table public.message_deletions alter column kind set not null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'message_deletions_kind_check') then
    alter table public.message_deletions
      add constraint message_deletions_kind_check check (kind in ('dm','group'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'message_deletions_uid_mid_kind_key') then
    alter table public.message_deletions
      add constraint message_deletions_uid_mid_kind_key unique (user_id, message_id, kind);
  end if;
end $$;

-- ── dm_clears: composite unique (user_id, thread_id) for ON CONFLICT ──
delete from public.dm_clears a
using public.dm_clears b
where a.user_id = b.user_id and a.thread_id = b.thread_id and a.ctid < b.ctid;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'dm_clears_uid_tid_key') then
    alter table public.dm_clears
      add constraint dm_clears_uid_tid_key unique (user_id, thread_id);
  end if;
end $$;

-- ── group_clears: composite unique (user_id, group_id) for ON CONFLICT ──
delete from public.group_clears a
using public.group_clears b
where a.user_id = b.user_id and a.group_id = b.group_id and a.ctid < b.ctid;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'group_clears_uid_gid_key') then
    alter table public.group_clears
      add constraint group_clears_uid_gid_key unique (user_id, group_id);
  end if;
end $$;

-- ── Drop the stale single-arg functions so the two-arg versions in
--    functions-delete-recall-clear.sql become the only overloads. ──
drop function if exists public.delete_message_for_me(uuid);
drop function if exists public.recall_message(uuid);

commit;
