-- migration-group-avatar.sql
-- Owner-gated RPC for changing a group's avatar.
--
--   * The `group_threads` UPDATE RLS policy is owner-only, but a direct table
--     write from the client is silently rejected, so the avatar change never
--     lands. Route the write through a SECURITY DEFINER function instead, gated
--     so only the group owner (group_threads.created_by) may change it.
--   * The client still uploads the image to the public `avatars` bucket; this
--     function only stamps the resulting public URL onto the row.
--
-- Idempotent. Drops the old signature first so re-runs are clean.

begin;

drop function if exists public.group_set_avatar(uuid, text);

-- Stamp a new avatar URL onto a group. Owner-only: the caller must be the
-- group's creator (group_threads.created_by = auth.uid()).
create or replace function public.group_set_avatar(p_group uuid, p_url text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not exists (
    select 1 from public.group_threads g
    where g.id = p_group and g.created_by = auth.uid()
  ) then
    raise exception 'forbidden';
  end if;
  update public.group_threads set avatar_url = p_url where id = p_group;
end;
$$;

grant execute on function public.group_set_avatar(uuid, text) to authenticated;

commit;
