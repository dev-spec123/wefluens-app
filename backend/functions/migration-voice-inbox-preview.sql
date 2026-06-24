-- migration-voice-inbox-preview.sql
-- Fixes the "voice shows as [File] in the inbox/conversation list" bug.
--
-- Voice clips are stored as message_type = 'file' with file_name = 'voice.m4a'
-- and file_mime like 'audio%'. The inbox list RPCs (list_dm_threads /
-- list_group_threads) previously reported them as last_message_type = 'file',
-- so the conversation-list preview rendered "[File]" instead of a voice label.
--
-- This migration REDEFINES both functions identically to their current form
-- (see functions-conversation-hides.sql) EXCEPT the last_message_type output:
-- a voice file is now reported as 'audio'. The last_visible CTE in each function
-- now also selects file_name / file_mime so the CASE can reference them.
--
-- Backend-only — no client change is needed (both apps already render an
-- 'audio' inbox-preview branch).
--
-- Idempotent: drops + recreates both functions, then re-applies the
-- revoke-from-public / grant-to-authenticated grants exactly as the originals.

begin;

-- ═══════════════════════════════════════════════════════════════════════════════
-- list_dm_threads — voice files now report as 'audio' in last_message_type
-- ═══════════════════════════════════════════════════════════════════════════════
drop function if exists public.list_dm_threads();

create or replace function public.list_dm_threads()
returns table (
  thread_id             uuid,
  other_id              uuid,
  other_name            text,
  other_handle          text,
  other_role            text,
  other_avatar_url      text,
  last_message          text,
  last_message_at       timestamptz,
  last_sender_id        uuid,
  last_message_type     text,
  last_message_recalled boolean,
  unread_count          bigint
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  with my_threads as (
    select dt.id as tid,
           case when dt.user_high = auth.uid() then dt.user_low else dt.user_high end as oid
    from public.dm_threads dt
    where dt.user_high = auth.uid() or dt.user_low = auth.uid()
  ),
  last_visible as (
    select distinct on (dm.thread_id)
      dm.thread_id,
      dm.id            as msg_id,
      dm.body,
      dm.message_type,
      dm.file_name,
      dm.file_mime,
      dm.created_at,
      dm.sender_id,
      dm.recalled_at
    from public.dm_messages dm
    left join public.message_deletions md
      on md.user_id = auth.uid()
     and md.message_id = dm.id
     and md.kind = 'dm'
    left join public.dm_clears dc
      on dc.user_id = auth.uid()
     and dc.thread_id = dm.thread_id
    where dm.thread_id in (select mt.tid from my_threads mt)
      and md.user_id is null
      and (dc.cleared_before is null or dm.created_at > dc.cleared_before)
    order by dm.thread_id, dm.created_at desc
  ),
  unread as (
    select dm.thread_id,
           count(*) as cnt
    from public.dm_messages dm
    left join public.message_deletions md
      on md.user_id = auth.uid()
     and md.message_id = dm.id
     and md.kind = 'dm'
    where dm.thread_id in (select mt.tid from my_threads mt)
      and dm.recipient_id = auth.uid()
      and dm.read_at is null
      and md.user_id is null
    group by dm.thread_id
  )
  select
    mt.tid                       as thread_id,
    mt.oid                       as other_id,
    p.name                       as other_name,
    p.handle                     as other_handle,
    p.role                       as other_role,
    p.avatar_url                 as other_avatar_url,
    case
      when lv.recalled_at is not null then ''
      else coalesce(lv.body, '')
    end                           as last_message,
    lv.created_at                 as last_message_at,
    lv.sender_id                  as last_sender_id,
    case
      when lv.message_type = 'file'
       and (lv.file_name = 'voice.m4a' or lv.file_mime like 'audio%')
      then 'audio'
      else coalesce(lv.message_type, 'text')
    end                           as last_message_type,
    (lv.recalled_at is not null)  as last_message_recalled,
    coalesce(u.cnt, 0)            as unread_count
  from my_threads mt
  left join public.profiles p on p.id = mt.oid
  left join last_visible lv on lv.thread_id = mt.tid
  left join unread u on u.thread_id = mt.tid
  -- Exclude conversations I've hidden, UNLESS a new message arrived after the hide time.
  left join public.conversation_hides ch
    on ch.user_id = auth.uid()
   and ch.conversation_id = mt.tid
   and ch.conversation_type = 'dm'
  where ch.user_id is null or (lv.created_at is not null and lv.created_at > ch.hidden_at)
  order by coalesce(lv.created_at, '1970-01-01'::timestamptz) desc;
end;
$$;

revoke execute on function public.list_dm_threads() from public;
grant  execute on function public.list_dm_threads() to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- list_group_threads — voice files now report as 'audio' in last_message_type
-- ═══════════════════════════════════════════════════════════════════════════════
drop function if exists public.list_group_threads();

create or replace function public.list_group_threads()
returns table (
  group_id              uuid,
  name                  text,
  avatar_url            text,
  created_by            uuid,
  last_message          text,
  last_message_at       timestamptz,
  last_sender_id        uuid,
  last_message_type     text,
  last_message_recalled boolean,
  member_count          bigint,
  unread_count          bigint
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  with my_groups as (
    select gm.group_id as gid
    from public.group_members gm
    where gm.user_id = auth.uid()
  ),
  last_visible as (
    select distinct on (gm.group_id)
      gm.group_id,
      gm.id            as msg_id,
      gm.body,
      gm.message_type,
      gm.file_name,
      gm.file_mime,
      gm.created_at,
      gm.sender_id,
      gm.recalled_at
    from public.group_messages gm
    left join public.message_deletions md
      on md.user_id = auth.uid()
     and md.message_id = gm.id
     and md.kind = 'group'
    left join public.group_clears gc
      on gc.user_id = auth.uid()
     and gc.group_id = gm.group_id
    where gm.group_id in (select mg.gid from my_groups mg)
      and md.user_id is null
      and (gc.cleared_before is null or gm.created_at > gc.cleared_before)
    order by gm.group_id, gm.created_at desc
  ),
  unread as (
    select gm.group_id,
           count(*) as cnt
    from public.group_messages gm
    join public.group_members gmem
      on gmem.group_id = gm.group_id
     and gmem.user_id = auth.uid()
    left join public.message_deletions md
      on md.user_id = auth.uid()
     and md.message_id = gm.id
     and md.kind = 'group'
    where gm.group_id in (select mg.gid from my_groups mg)
      and gm.created_at > coalesce(gmem.last_read_at, '1970-01-01'::timestamptz)
      and gm.sender_id <> auth.uid()
      and md.user_id is null
    group by gm.group_id
  )
  select
    gt.id                         as group_id,
    gt.name,
    gt.avatar_url,
    gt.created_by,
    case
      when lv.recalled_at is not null then ''
      else coalesce(lv.body, '')
    end                           as last_message,
    lv.created_at                 as last_message_at,
    lv.sender_id                  as last_sender_id,
    case
      when lv.message_type = 'file'
       and (lv.file_name = 'voice.m4a' or lv.file_mime like 'audio%')
      then 'audio'
      else coalesce(lv.message_type, 'text')
    end                           as last_message_type,
    (lv.recalled_at is not null)  as last_message_recalled,
    (select count(*)::bigint from public.group_members gm2 where gm2.group_id = gt.id) as member_count,
    coalesce(u.cnt, 0)            as unread_count
  from public.group_threads gt
  join my_groups mg on mg.gid = gt.id
  left join last_visible lv on lv.group_id = gt.id
  left join unread u on u.group_id = gt.id
  -- Exclude groups I've hidden, UNLESS a new message arrived after the hide time.
  left join public.conversation_hides ch
    on ch.user_id = auth.uid()
   and ch.conversation_id = gt.id
   and ch.conversation_type = 'group'
  where ch.user_id is null or (lv.created_at is not null and lv.created_at > ch.hidden_at)
  order by coalesce(lv.created_at, gt.created_at) desc;
end;
$$;

revoke execute on function public.list_group_threads() from public;
grant  execute on function public.list_group_threads() to authenticated;

commit;
