-- migration-add-friend-browse.sql
-- Add Friend gets its own browse list, decoupled from the (now admin-curated)
-- Top Talent. browse_addable_users returns all users you could add — everyone
-- except yourself and people in a block relationship — ranked by followers, with
-- your current relationship to each so the row can show Add / Pending / Friends.
-- Same column shape as search_users / browse_top_talent (decodes to SearchUserResult).
--
-- Not gated by data_sharing: this is the "find people" directory. (Top Talent is
-- the curated/opt-in-independent showcase; exact-handle search is search_users.)
--
-- Run after the earlier curation migrations. Idempotent.

begin;

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
