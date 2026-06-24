-- migration-admin-roles.sql
-- Admin role management — let an existing admin GRANT or REVOKE the is_admin flag
-- on OTHER users, from the in-app admin/developer panel.
--
--   * admin_set_admin (SECURITY DEFINER, is_admin-gated) flips profiles.is_admin on
--     a target user. Writes are gated so we don't touch the profiles table's RLS,
--     mirroring the brand / campaign admin RPCs.
--   * CRITICAL GUARD: an admin can never change their OWN admin status — that would
--     let them demote and lock themselves out. The server enforces this regardless
--     of what the UI sends.
--
-- Run AFTER migration-admin-curation.sql (which defines is_admin_caller). Idempotent.
-- Does NOT redefine is_admin_caller — it already exists.

begin;

-- Grant (make_admin true) or revoke (make_admin false) admin on a target user.
drop function if exists public.admin_set_admin(uuid, boolean);
create or replace function public.admin_set_admin(target uuid, make_admin boolean)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin_caller() then raise exception 'forbidden'; end if;
  if target = auth.uid() then raise exception 'cannot change your own admin status'; end if;
  update public.profiles set is_admin = make_admin where id = target;
end;
$$;
grant execute on function public.admin_set_admin(uuid, boolean) to authenticated;

commit;
