-- migration-discoverable-addfriend.sql
-- "Discoverable" (data_sharing) now controls whether a user appears in the Add
-- Friend browse list. It's opt-OUT: default true, so users are discoverable
-- unless they deliberately turn it off. Exact-handle search (search_users) is
-- unaffected — someone who knows your handle/email can still find you.
--
-- (Earlier this flag was opt-IN and gated the Top Talent directory; Top Talent is
-- now admin-curated and ignores it, so the flag is repurposed here.)
--
-- Run after migration-add-friend-browse.sql. Idempotent.

begin;

-- Opt-out default + make existing users discoverable (they were reset to false by
-- the earlier opt-in migration; that "false" meant "not opted in", not a choice).
alter table public.profiles alter column data_sharing set default true;
update public.profiles set data_sharing = true where coalesce(data_sharing, false) = false;

create or replace function public.browse_addable_users(limit_count int default 50)
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
    and coalesce(p.data_sharing, true) = true        -- Discoverable opt-out
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by public.followers_magnitude(p.followers) desc, p.created_at desc
  limit greatest(1, least(limit_count, 200))
$$;

grant execute on function public.browse_addable_users(int) to authenticated;

commit;
