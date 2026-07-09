-- migration-user-invite-codes.sql
-- Lets every user have ONE personal, shareable invite code (bounded to a few uses),
-- on top of the admin invite-code system. Admins can revoke any code (existing
-- admin_revoke_invite_code + admin_list_invite_codes already cover personal codes).
--
-- Run after migration-invite-only.sql. Idempotent.

begin;

-- Distinguishes user-minted personal codes from admin-minted ones.
alter table public.invite_codes add column if not exists personal boolean not null default false;

-- Returns the caller's current personal code (usable = not revoked / not expired /
-- not exhausted), creating a fresh one (default 5 uses) if they don't have an
-- active one. So a user always has exactly one live code to share; once it's spent
-- or revoked, the next call mints a new one.
create or replace function public.get_or_create_my_invite_code(p_max_uses int default 5)
returns table (code text, uses int, max_uses int)
language plpgsql security definer set search_path = public
as $$
declare
  v_code text;
  v_uses int;
  v_max  int;
  v_new  text;
  v_cap  int := greatest(1, coalesce(p_max_uses, 5));
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;

  select c.code, c.uses, c.max_uses into v_code, v_uses, v_max
  from public.invite_codes c
  where c.created_by = auth.uid()
    and c.personal = true
    and c.revoked = false
    and c.uses < c.max_uses
    and (c.expires_at is null or c.expires_at > now())
  order by c.created_at desc
  limit 1;

  if v_code is not null then
    return query select v_code, v_uses, v_max;
    return;
  end if;

  for _ in 1..5 loop
    v_new := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    begin
      insert into public.invite_codes (code, max_uses, personal, created_by)
      values (v_new, v_cap, true, auth.uid());
      return query select v_new, 0, v_cap;
      return;
    exception when unique_violation then
      -- retry
    end;
  end loop;
  raise exception 'could_not_generate_code';
end;
$$;
grant execute on function public.get_or_create_my_invite_code(int) to authenticated;

commit;
