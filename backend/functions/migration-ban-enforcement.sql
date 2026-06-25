-- migration-ban-enforcement.sql
-- Make a ban actually STOP an already-logged-in user (not just block fresh login).
--
-- The send_* RPCs are SECURITY DEFINER (Rork-managed) so RLS can't gate them — but
-- table TRIGGERS still fire on their inserts. So we reject any insert whose actor is
-- banned, which blocks a banned user's activity IMMEDIATELY, per-request, even with a
-- still-valid access token. Plus, the moment is_banned flips true we revoke the user's
-- sessions and stamp auth.users.banned_until so they're logged out + can't refresh or
-- sign back in. No client change needed — the existing admin_ban_user flow drives it.
--
-- Idempotent.

begin;

-- Is this user banned? (indexed PK lookup on profiles.)
create or replace function public.is_user_banned(uid uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select coalesce((select p.is_banned from public.profiles p where p.id = uid), false);
$$;

-- Generic guard: reject the insert if the row's actor column (passed as TG_ARGV[0])
-- belongs to a banned account.
create or replace function public.reject_if_actor_banned()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_actor uuid;
begin
  execute format('select ($1).%I', TG_ARGV[0]) into v_actor using NEW;
  if public.is_user_banned(v_actor) then
    raise exception 'BANNED: this account is suspended';
  end if;
  return NEW;
end;
$$;

-- Block a banned user's core activity: DMs, group messages, friend requests, and
-- creating groups. (Media/attachments route through these same message tables, so
-- they're covered too.)
drop trigger if exists trg_dm_sender_banned on public.dm_messages;
create trigger trg_dm_sender_banned
  before insert on public.dm_messages
  for each row execute function public.reject_if_actor_banned('sender_id');

drop trigger if exists trg_group_sender_banned on public.group_messages;
create trigger trg_group_sender_banned
  before insert on public.group_messages
  for each row execute function public.reject_if_actor_banned('sender_id');

drop trigger if exists trg_friend_req_banned on public.friend_requests;
create trigger trg_friend_req_banned
  before insert on public.friend_requests
  for each row execute function public.reject_if_actor_banned('from_user_id');

drop trigger if exists trg_group_create_banned on public.group_threads;
create trigger trg_group_create_banned
  before insert on public.group_threads
  for each row execute function public.reject_if_actor_banned('created_by');

-- When is_banned flips, log the user out everywhere + (un)block auth.
-- SECURITY DEFINER owned by the migration runner (postgres) so it may touch auth.*.
create or replace function public.enforce_ban_sessions()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if NEW.is_banned is distinct from OLD.is_banned then
    if coalesce(NEW.is_banned, false) then
      update auth.users set banned_until = 'infinity'::timestamptz where id = NEW.id;
      delete from auth.sessions where user_id = NEW.id;   -- refresh_tokens cascade
    else
      update auth.users set banned_until = null where id = NEW.id;
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_profiles_ban_sessions on public.profiles;
create trigger trg_profiles_ban_sessions
  after update of is_banned on public.profiles
  for each row execute function public.enforce_ban_sessions();

commit;
