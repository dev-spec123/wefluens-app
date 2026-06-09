-- functions-delete-recall-clear.sql
-- 4 SECURITY DEFINER functions + updated list_dm_threads/list_group_threads
-- for the recall/delete/clear chat system.
--
-- Run AFTER migration-delete-recall-clear.sql.
-- All functions use SET search_path = '' and fully-qualified table names.
-- EXECUTE is revoked from PUBLIC and granted only to authenticated.

-- ═══════════════════════════════════════════════════════════════════════════════
-- A) delete_message_for_me — soft-delete a single message for the caller only
-- ═══════════════════════════════════════════════════════════════════════════════
create or replace function public.delete_message_for_me(
  p_message_id uuid,
  p_kind       text   -- 'dm' or 'group'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_kind = 'dm' then
    -- Verify the caller is a participant of this DM thread (they can only
    -- delete messages from threads they have access to).
    if not exists (
      select 1 from public.dm_messages
      where id = p_message_id
        and (sender_id = auth.uid() or recipient_id = auth.uid())
    ) then
      raise exception 'FORBIDDEN: not a participant of this message';
    end if;
  elsif p_kind = 'group' then
    if not exists (
      select 1
      from public.group_messages gm
      join public.group_members gmem on gmem.group_id = gm.group_id and gmem.user_id = auth.uid()
      where gm.id = p_message_id
    ) then
      raise exception 'FORBIDDEN: not a member of this group';
    end if;
  else
    raise exception 'BAD_KIND: must be dm or group';
  end if;

  -- Upsert a soft-deletion row (A / local-only, affects only the caller).
  insert into public.message_deletions (user_id, message_id, kind)
  values (auth.uid(), p_message_id, p_kind)
  on conflict (user_id, message_id, kind) do nothing;
end;
$$;

revoke execute on function public.delete_message_for_me(uuid, text) from public;
grant  execute on function public.delete_message_for_me(uuid, text) to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- B) recall_message — recall a message (both sides) within 2 minutes, sender-only
--    Clears all content fields so captured data exposes nothing.
-- ═══════════════════════════════════════════════════════════════════════════════
create or replace function public.recall_message(
  p_message_id uuid,
  p_kind       text   -- 'dm' or 'group'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sender_id uuid;
  v_created_at timestamptz;
begin
  if p_kind = 'dm' then
    select sender_id, created_at into v_sender_id, v_created_at
    from public.dm_messages
    where id = p_message_id;

    if not found then
      raise exception 'NOT_FOUND';
    end if;

    if v_sender_id <> auth.uid() then
      raise exception 'FORBIDDEN: only the sender can recall this message';
    end if;

    if v_created_at is null or v_created_at < (now() - interval '2 minutes') then
      raise exception 'EXPIRED: recall window is 2 minutes';
    end if;

    if exists (select 1 from public.dm_messages where id = p_message_id and recalled_at is not null) then
      raise exception 'ALREADY_RECALLED';
    end if;

    -- Clear all content fields (body must be '' not null — column has a NOT NULL
    -- constraint). Media URLs are set to null (those columns are nullable).
    update public.dm_messages
    set recalled_at = now(),
        recalled_by = auth.uid(),
        body         = '',
        image_url    = null,
        thumb_url    = null,
        file_name    = null,
        file_size    = null,
        file_mime    = null
    where id = p_message_id;

  elsif p_kind = 'group' then
    select sender_id, created_at into v_sender_id, v_created_at
    from public.group_messages
    where id = p_message_id;

    if not found then
      raise exception 'NOT_FOUND';
    end if;

    if v_sender_id <> auth.uid() then
      raise exception 'FORBIDDEN: only the sender can recall this message';
    end if;

    if v_created_at is null or v_created_at < (now() - interval '2 minutes') then
      raise exception 'EXPIRED: recall window is 2 minutes';
    end if;

    if exists (select 1 from public.group_messages where id = p_message_id and recalled_at is not null) then
      raise exception 'ALREADY_RECALLED';
    end if;

    update public.group_messages
    set recalled_at = now(),
        recalled_by = auth.uid(),
        body         = '',
        image_url    = null,
        thumb_url    = null,
        file_name    = null,
        file_size    = null,
        file_mime    = null
    where id = p_message_id;

  else
    raise exception 'BAD_KIND: must be dm or group';
  end if;
end;
$$;

revoke execute on function public.recall_message(uuid, text) from public;
grant  execute on function public.recall_message(uuid, text) to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- C) clear_dm_history — clear a 1:1 thread for the caller only (sets watermark)
-- ═══════════════════════════════════════════════════════════════════════════════
create or replace function public.clear_dm_history(
  p_thread_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Verify the caller is a participant.
  if not exists (
    select 1 from public.dm_threads
    where id = p_thread_id
      and (user_high = auth.uid() or user_low = auth.uid())
  ) then
    raise exception 'FORBIDDEN: not a participant of this thread';
  end if;

  insert into public.dm_clears (user_id, thread_id, cleared_before)
  values (auth.uid(), p_thread_id, now())
  on conflict (user_id, thread_id)
  do update set cleared_before = now();
end;
$$;

revoke execute on function public.clear_dm_history(uuid) from public;
grant  execute on function public.clear_dm_history(uuid) to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- D) clear_group_history — clear a group thread for the caller only
-- ═══════════════════════════════════════════════════════════════════════════════
create or replace function public.clear_group_history(
  p_group_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Verify the caller is a member.
  if not exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = auth.uid()
  ) then
    raise exception 'FORBIDDEN: not a member of this group';
  end if;

  insert into public.group_clears (user_id, group_id, cleared_before)
  values (auth.uid(), p_group_id, now())
  on conflict (user_id, group_id)
  do update set cleared_before = now();
end;
$$;

revoke execute on function public.clear_group_history(uuid) from public;
grant  execute on function public.clear_group_history(uuid) to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- UPDATED: list_dm_threads — now filters out recalled/deleted/cleared messages
--            for the last-message preview, and shows 「消息已撤回」 for recalls
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
    -- For each DM thread, find the most recent message that the current user
    -- is allowed to see (not deleted by me, not before my clear watermark).
    select distinct on (dm.thread_id)
      dm.thread_id,
      dm.id            as msg_id,
      dm.body,
      dm.message_type,
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
      and md.user_id is null                         -- not deleted by me
      and (dc.cleared_before is null or dm.created_at > dc.cleared_before)  -- after my clear
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
      when lv.recalled_at is not null then ''  -- placeholder text set client-side
      else coalesce(lv.body, '')
    end                           as last_message,
    lv.created_at                 as last_message_at,
    lv.sender_id                  as last_sender_id,
    coalesce(lv.message_type, 'text') as last_message_type,
    (lv.recalled_at is not null)  as last_message_recalled,
    coalesce(u.cnt, 0)            as unread_count
  from my_threads mt
  left join public.profiles p on p.id = mt.oid
  left join last_visible lv on lv.thread_id = mt.tid
  left join unread u on u.thread_id = mt.tid
  order by coalesce(lv.created_at, '1970-01-01'::timestamptz) desc;
end;
$$;

revoke execute on function public.list_dm_threads() from public;
grant  execute on function public.list_dm_threads() to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- UPDATED: list_group_threads — same filtering for groups
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
    coalesce(lv.message_type, 'text') as last_message_type,
    (lv.recalled_at is not null)  as last_message_recalled,
    (select count(*)::bigint from public.group_members where group_id = gt.id) as member_count,
    coalesce(u.cnt, 0)            as unread_count
  from public.group_threads gt
  join my_groups mg on mg.gid = gt.id
  left join last_visible lv on lv.group_id = gt.id
  left join unread u on u.group_id = gt.id
  order by coalesce(lv.created_at, gt.created_at) desc;
end;
$$;

revoke execute on function public.list_group_threads() from public;
grant  execute on function public.list_group_threads() to authenticated;
