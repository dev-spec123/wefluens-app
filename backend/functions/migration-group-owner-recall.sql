-- migration-group-owner-recall.sql
-- Group OWNER may recall ANY message in their group at ANY time — no sender check,
-- no 2-minute window. Normal members are unchanged (own message + 2 minutes).
--
-- Redefines recall_message identically to functions-delete-recall-clear.sql EXCEPT
-- the 'group' branch, which now grants the group owner an override. The 'dm' branch
-- is verbatim. Idempotent.

begin;

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
  v_group_id uuid;
  v_is_owner boolean := false;
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
    select sender_id, created_at, group_id into v_sender_id, v_created_at, v_group_id
    from public.group_messages
    where id = p_message_id;

    if not found then
      raise exception 'NOT_FOUND';
    end if;

    -- The group OWNER may recall ANY message at ANY time — bypass the sender check
    -- and the 2-minute window. Everyone else keeps the normal rules.
    v_is_owner := exists (
      select 1 from public.group_threads g
      where g.id = v_group_id and g.created_by = auth.uid()
    );

    if not v_is_owner and v_sender_id <> auth.uid() then
      raise exception 'FORBIDDEN: only the sender can recall this message';
    end if;

    if not v_is_owner and (v_created_at is null or v_created_at < (now() - interval '2 minutes')) then
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

commit;
