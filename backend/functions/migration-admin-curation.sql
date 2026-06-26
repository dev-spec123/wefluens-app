-- migration-admin-curation.sql
-- Admin curation for Top Talent and Top Brands, gated by the existing is_admin flag.
--
--   * profiles.featured_rank / brands.featured_rank — nullable position. Set =
--     featured (and ordered by it ascending); null = not featured.
--   * Top Talent (browse_top_talent) = featured creators first in admin order,
--     then opt-in (data_sharing) creators as follower-ranked fill. Featured
--     creators appear regardless of their opt-in (admin can feature anyone).
--   * Admin RPCs (SECURITY DEFINER, is_admin-gated) to feature talent, and to
--     create / edit / delete / feature brands. Reads stay public; only writes are
--     gated, and via RPC so we don't touch the brands table's RLS.
--
-- Run AFTER the full-completion + top-talent-optin migrations. Idempotent.

begin;

alter table public.profiles add column if not exists featured_rank int;
alter table public.brands   add column if not exists featured_rank int;

create index if not exists profiles_featured_rank_idx
  on public.profiles (featured_rank) where featured_rank is not null;
create index if not exists brands_featured_rank_idx
  on public.brands (featured_rank) where featured_rank is not null;

-- Is the current caller an admin? Reused by every admin RPC below.
create or replace function public.is_admin_caller()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and coalesce(is_admin, false) = true
  );
$$;
grant execute on function public.is_admin_caller() to authenticated;

-- Feature / reorder / unfeature a creator. rank null => unfeature.
-- (Nullable params get DEFAULT NULL: the Supabase client omits nil args, so the
-- function must resolve when `rank` isn't sent.)
create or replace function public.admin_set_featured_talent(target uuid, rank int default null)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin_caller() then raise exception 'forbidden'; end if;
  update public.profiles set featured_rank = rank where id = target;
end;
$$;
grant execute on function public.admin_set_featured_talent(uuid, int) to authenticated;

-- Feature / reorder / unfeature a brand.
create or replace function public.admin_set_featured_brand(target uuid, rank int default null)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin_caller() then raise exception 'forbidden'; end if;
  update public.brands set featured_rank = rank where id = target;
end;
$$;
grant execute on function public.admin_set_featured_brand(uuid, int) to authenticated;

-- Create (brand_id null) or update a brand. Returns the brand id. p_name is the
-- only required arg; everything else defaults so the call resolves regardless of
-- which nil args the client omits. (Reordered so the required param comes first.)
drop function if exists public.admin_upsert_brand(uuid, text, text, text, text, text, int, int);
create or replace function public.admin_upsert_brand(
  p_name text,
  brand_id uuid default null,
  p_category text default null,
  p_tagline text default null,
  p_symbol text default null,
  p_colors text default null,
  p_active_campaigns int default null,
  p_featured_rank int default null
)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare new_id uuid;
begin
  if not public.is_admin_caller() then raise exception 'forbidden'; end if;
  if brand_id is null then
    insert into public.brands (name, category, tagline, symbol, colors, active_campaigns, featured_rank)
    values (p_name, p_category, p_tagline, p_symbol, p_colors, p_active_campaigns, p_featured_rank)
    returning id into new_id;
    return new_id;
  else
    update public.brands set
      name = p_name, category = p_category, tagline = p_tagline,
      symbol = p_symbol, colors = p_colors,
      active_campaigns = p_active_campaigns, featured_rank = p_featured_rank
    where id = brand_id;
    return brand_id;
  end if;
end;
$$;
grant execute on function public.admin_upsert_brand(text, uuid, text, text, text, text, int, int) to authenticated;

create or replace function public.admin_delete_brand(target uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin_caller() then raise exception 'forbidden'; end if;
  delete from public.brands where id = target;
end;
$$;
grant execute on function public.admin_delete_brand(uuid) to authenticated;

-- Lists currently-featured creators (with rank) for the curation screen. Featured
-- creators are a public showcase, so this read isn't admin-gated.
create or replace function public.admin_list_featured_talent()
returns table (
  id            uuid,
  name         text,
  handle       text,
  role         text,
  avatar_url   text,
  followers    text,
  featured_rank int
)
language sql stable security definer set search_path = public
as $$
  select p.id, coalesce(p.name, ''), coalesce(p.handle, ''), coalesce(p.role, ''),
         p.avatar_url, coalesce(p.followers, ''), p.featured_rank
  from public.profiles p
  where p.featured_rank is not null
  order by p.featured_rank asc;
$$;
grant execute on function public.admin_list_featured_talent() to authenticated;

-- Top Talent: ONLY the admin-curated featured creators, in admin order. No opt-in
-- fill (the data_sharing/Discoverable toggle no longer affects this list).
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
    and p.featured_rank is not null                  -- curated list only
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by p.featured_rank asc                        -- admin's order
  limit greatest(1, least(limit_count, 200))
$$;

commit;
