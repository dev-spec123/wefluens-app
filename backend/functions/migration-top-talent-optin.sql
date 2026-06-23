-- migration-top-talent-optin.sql
-- Switches the Top Talent directory from opt-OUT to opt-IN.
--
-- Before: data_sharing defaulted true, so every user appeared in browse_top_talent
-- unless they turned it off. Now: data_sharing defaults false, existing rows are
-- reset to false, and browse_top_talent returns only users who explicitly opted in.
-- Direct search (search_users / Add Friend) is unaffected — a user can still be
-- found by exact handle/name even when not listed in the directory.
--
-- Run AFTER migration-full-completion.sql. Idempotent.

begin;

-- New users are not discoverable until they opt in.
alter table public.profiles alter column data_sharing set default false;

-- Reset everyone to not-listed (the migration that added the column defaulted it
-- to true). Pre-launch, so this just clears the implicit opt-in.
update public.profiles set data_sharing = false where data_sharing is true;

-- Only opted-in users appear in the directory. (coalesce keeps it safe if the
-- column is ever nullable.)
create or replace function public.browse_top_talent(limit_count int default 50)
returns table (
  id                  uuid,
  name                text,
  handle              text,
  role                text,
  avatar_url          text,
  followers           text,
  relationship        text,
  incoming_request_id uuid
)
language sql
security definer
set search_path = public
as $$
  select
    p.id,
    coalesce(p.name, '')   as name,
    coalesce(p.handle, '') as handle,
    coalesce(p.role, '')   as role,
    p.avatar_url,
    coalesce(p.followers, '') as followers,
    case
      when exists (
        select 1 from public.friendships f
        where (f.user_id = auth.uid() and f.friend_id = p.id)
           or (f.friend_id = auth.uid() and f.user_id = p.id)
      ) then 'friends'
      when exists (
        select 1 from public.friend_requests r
        where r.from_user_id = auth.uid() and r.to_user_id = p.id and r.status = 'pending'
      ) then 'request_sent'
      when exists (
        select 1 from public.friend_requests r
        where r.from_user_id = p.id and r.to_user_id = auth.uid() and r.status = 'pending'
      ) then 'request_received'
      else 'none'
    end as relationship,
    (
      select r.id from public.friend_requests r
      where r.from_user_id = p.id and r.to_user_id = auth.uid() and r.status = 'pending'
      limit 1
    ) as incoming_request_id
  from public.profiles p
  where p.id <> auth.uid()
    and coalesce(p.data_sharing, false) = true
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by public.followers_magnitude(p.followers) desc, p.created_at desc
  limit greatest(1, least(limit_count, 200))
$$;

commit;
