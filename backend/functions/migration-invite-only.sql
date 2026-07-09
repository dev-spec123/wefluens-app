-- migration-invite-only.sql
-- Invite-only signup. New accounts can only be created with a valid invite code,
-- via the signup-with-invite edge function (service role). Existing users are
-- grandfathered (no access change). Admins mint/manage codes.
--
-- Enforcement: this migration + the edge function are the gate. The final step is
-- turning OFF "Allow new users to sign up" in Supabase Auth settings so the public
-- auth.signUp endpoint can't be used to bypass the code — do that once both apps
-- are deployed. (The edge function creates users via the admin API, which is
-- unaffected by that setting.)
--
-- Reuses is_admin_caller() from migration-admin-curation.sql. Idempotent.

begin;

create table if not exists public.invite_codes (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  max_uses    int  not null default 1,
  uses        int  not null default 0,
  expires_at  timestamptz,
  revoked     boolean not null default false,
  label       text,
  created_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now()
);

create table if not exists public.code_redemptions (
  id          uuid primary key default gen_random_uuid(),
  code_id     uuid references public.invite_codes (id) on delete set null,
  code        text not null,
  user_id     uuid,
  email       text,
  redeemed_at timestamptz not null default now()
);

-- RLS on: no client policies. All reads/writes go through SECURITY DEFINER RPCs
-- (admins) or the service-role edge function (redeem). Ordinary clients get nothing.
alter table public.invite_codes    enable row level security;
alter table public.code_redemptions enable row level security;

-- ── Admin: create a code ─────────────────────────────────────────────────────
-- Generates a readable random code (8 uppercase hex chars). max_uses defaults 1.
create or replace function public.admin_create_invite_code(
  p_max_uses int default 1,
  p_expires_at timestamptz default null,
  p_label text default null
)
returns text
language plpgsql security definer set search_path = public
as $$
declare new_code text;
begin
  if not public.is_admin_caller() then raise exception 'forbidden'; end if;
  -- Retry a few times on the (astronomically unlikely) unique collision.
  for _ in 1..5 loop
    new_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    begin
      insert into public.invite_codes (code, max_uses, expires_at, label, created_by)
      values (new_code, greatest(1, coalesce(p_max_uses, 1)), p_expires_at, p_label, auth.uid());
      return new_code;
    exception when unique_violation then
      -- try again
    end;
  end loop;
  raise exception 'could_not_generate_code';
end;
$$;
grant execute on function public.admin_create_invite_code(int, timestamptz, text) to authenticated;

-- ── Admin: list codes (with computed status) ─────────────────────────────────
create or replace function public.admin_list_invite_codes()
returns table (
  id uuid, code text, max_uses int, uses int, expires_at timestamptz,
  revoked boolean, label text, created_at timestamptz, status text
)
language sql stable security definer set search_path = public
as $$
  select
    c.id, c.code, c.max_uses, c.uses, c.expires_at, c.revoked, c.label, c.created_at,
    case
      when c.revoked then 'revoked'
      when c.expires_at is not null and c.expires_at <= now() then 'expired'
      when c.uses >= c.max_uses then 'used'
      else 'active'
    end as status
  from public.invite_codes c
  where public.is_admin_caller()
  order by c.created_at desc
$$;
grant execute on function public.admin_list_invite_codes() to authenticated;

-- ── Admin: revoke a code ─────────────────────────────────────────────────────
create or replace function public.admin_revoke_invite_code(p_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin_caller() then raise exception 'forbidden'; end if;
  update public.invite_codes set revoked = true where id = p_id;
end;
$$;
grant execute on function public.admin_revoke_invite_code(uuid) to authenticated;

-- ── Redeem: atomically claim one use of a valid code ─────────────────────────
-- Returns the code id if a use was claimed, else null. The conditional UPDATE is
-- atomic, so two concurrent signups can't over-consume a single-use code. Called
-- by the signup-with-invite edge function (service role).
create or replace function public.claim_invite_code(p_code text)
returns uuid
language sql security definer set search_path = public
as $$
  update public.invite_codes c
     set uses = c.uses + 1
   where lower(c.code) = lower(btrim(p_code))
     and c.revoked = false
     and (c.expires_at is null or c.expires_at > now())
     and c.uses < c.max_uses
  returning c.id
$$;
grant execute on function public.claim_invite_code(text) to service_role;

-- Release a claimed use if account creation fails afterwards (best-effort).
create or replace function public.release_invite_code(p_code text)
returns void
language sql security definer set search_path = public
as $$
  update public.invite_codes c
     set uses = greatest(0, c.uses - 1)
   where lower(c.code) = lower(btrim(p_code))
$$;
grant execute on function public.release_invite_code(text) to service_role;

commit;
