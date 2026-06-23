-- migration-push-triggers.sql
-- DB-trigger SKELETON that drives the (stubbed) send-push edge function. This is
-- the "call site" half of the push pipeline — it is built and wired, but it stays
-- inert until the APNs send path in send-push/index.ts is completed by a dev with
-- an Apple Developer account (see that file + PLAN.md → "Push notifications").
--
-- Why it's safe to apply now:
--   * notify_push() is a no-op unless BOTH pg_net is installed AND app_secrets has
--     PUSH_INTERNAL_SECRET + EDGE_BASE_URL — so applying this on a project without
--     push configured changes nothing observable.
--   * send-push itself is a stub that only logs, so even once wired it cannot send
--     a real notification until the APNs block is filled in.
--
-- Prereqs the Apple-account dev sets when going live:
--   create extension if not exists pg_net;
--   insert into app_secrets(key,value) values
--     ('PUSH_INTERNAL_SECRET', '<random>'),
--     ('EDGE_BASE_URL', 'https://<project-ref>.supabase.co/functions/v1');

begin;

-- Central helper: fire-and-forget a request to the send-push edge function.
-- Reads its config from app_secrets; if anything is missing it returns quietly so
-- triggers never fail a user's write just because push isn't set up.
create or replace function public.notify_push(
  recipient_ids uuid[],
  title text,
  body text,
  data jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  secret text;
  base_url text;
begin
  if recipient_ids is null or array_length(recipient_ids, 1) is null then
    return;
  end if;

  -- pg_net must be installed for net.http_post to exist.
  if not exists (select 1 from pg_extension where extname = 'pg_net') then
    return;
  end if;

  select value into secret from app_secrets where key = 'PUSH_INTERNAL_SECRET';
  select value into base_url from app_secrets where key = 'EDGE_BASE_URL';
  if secret is null or base_url is null then
    return;  -- push not configured yet — no-op
  end if;

  perform net.http_post(
    url     := base_url || '/send-push',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-internal-secret', secret
               ),
    body    := jsonb_build_object(
                 'userIds', to_jsonb(recipient_ids),
                 'title', title,
                 'body', body,
                 'data', data
               )
  );
end;
$$;

-- ── Friend requests ──────────────────────────────────────────────────────────
-- INSERT of a pending request → notify the recipient ("X sent you a friend request").
create or replace function public.on_friend_request_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare sender_name text;
begin
  if new.status = 'pending' then
    select coalesce(name, handle, 'Someone') into sender_name
      from profiles where id = new.from_user_id;
    perform public.notify_push(
      array[new.to_user_id],
      'New friend request',
      coalesce(sender_name, 'Someone') || ' wants to connect',
      jsonb_build_object('kind', 'friend_request', 'requestId', new.id)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_friend_request_insert on public.friend_requests;
create trigger trg_friend_request_insert
  after insert on public.friend_requests
  for each row execute function public.on_friend_request_insert();

-- UPDATE to accepted → notify the original sender ("X accepted your request").
create or replace function public.on_friend_request_accept()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare accepter_name text;
begin
  if new.status = 'accepted' and coalesce(old.status, '') <> 'accepted' then
    select coalesce(name, handle, 'Someone') into accepter_name
      from profiles where id = new.to_user_id;
    perform public.notify_push(
      array[new.from_user_id],
      'Friend request accepted',
      coalesce(accepter_name, 'Someone') || ' accepted your request',
      jsonb_build_object('kind', 'friend_accepted', 'requestId', new.id)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_friend_request_accept on public.friend_requests;
create trigger trg_friend_request_accept
  after update on public.friend_requests
  for each row execute function public.on_friend_request_accept();

commit;

-- ── TODO(APNs): message triggers ─────────────────────────────────────────────
-- New-message pushes are left as a skeleton because resolving a message's
-- recipient(s) depends on the thread/participant schema (dm threads + group
-- membership) not captured in this repo. To complete:
--
--   1. DM: on insert into dm_messages, resolve the *other* participant of
--      new.thread_id and call notify_push(array[other_user_id], sender_name,
--      new.body, jsonb_build_object('kind','dm','threadId',new.thread_id)).
--      Skip when new.message_type <> 'text' (or summarize media as "📷 Photo").
--
--   2. Group: on insert into group_messages, select all group_members for
--      new.group_id except new.sender_id, and notify_push(that array, group_name,
--      sender_name || ': ' || new.body, {'kind':'group','groupId':new.group_id}).
--
-- Wrap both in the same `status='pending'`-style guards and keep them AFTER INSERT
-- so a push failure can never roll back the message write.
