-- migration-user-email-invites.sql
-- Lets any user (not just admins) invite someone by email, spending one of their
-- personal invite allowance (the same budget as their shareable code — see
-- migration-user-invite-codes.sql). Admins are not charged.
--
-- These are called by the invite-user edge function using the CALLER's client
-- (not the service role), so auth.uid() is the inviting user.
--
-- Run after migration-user-invite-codes.sql. Idempotent.

begin;

-- Atomically spend one invite from the caller's active personal code.
-- Returns true if one was available and consumed, false if they're out.
create or replace function public.spend_my_invite()
returns boolean
language plpgsql security definer set search_path = public
as $$
declare v_id uuid;
begin
  if auth.uid() is null then return false; end if;

  update public.invite_codes c
     set uses = c.uses + 1
   where c.id = (
     select c2.id
     from public.invite_codes c2
     where c2.created_by = auth.uid()
       and c2.personal = true
       and c2.revoked = false
       and c2.uses < c2.max_uses
       and (c2.expires_at is null or c2.expires_at > now())
     order by c2.created_at desc
     limit 1
   )
  returning c.id into v_id;

  return v_id is not null;
end;
$$;
grant execute on function public.spend_my_invite() to authenticated;

-- Give an invite back if sending the invitation fails afterwards (best-effort).
create or replace function public.refund_my_invite()
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then return; end if;

  update public.invite_codes c
     set uses = greatest(0, c.uses - 1)
   where c.id = (
     select c2.id
     from public.invite_codes c2
     where c2.created_by = auth.uid()
       and c2.personal = true
       and c2.uses > 0
     order by c2.created_at desc
     limit 1
   );
end;
$$;
grant execute on function public.refund_my_invite() to authenticated;

commit;
