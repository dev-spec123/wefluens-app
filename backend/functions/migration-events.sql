-- migration-events.sql
-- Events on Discover: an admin creates an event, PUBLISHES it, and influencers
-- sign up to participate. Run AFTER migration-discover-revamp.sql (it reuses
-- is_admin_caller and the public `discover` Storage bucket). Idempotent.
--
--   * events table with an explicit draft → published gate. Drafts are invisible
--     to non-admins and cannot be signed up for; publishing is its own RPC so
--     "save an edit" never accidentally makes a draft live.
--   * event_signups table (the "sign up to participate" join) + sign-up /
--     cancel / list-mine RPCs, mirroring campaign_applications.
--   * list_discover_events (published only, soonest first) computes the signup
--     count and the caller's signed_up flag server-side, like list_discover_campaigns.
--   * Admin RPCs (SECURITY DEFINER, is_admin-gated) to create / edit / publish /
--     unpublish / delete, plus list_admin_events which returns drafts too.
--
-- Capacity note: unlike campaigns.spots_left (a mutable counter the apply RPC
-- decrements), an event stores a fixed `capacity` and spots-left is DERIVED from
-- the live signup count. Same UI, but it cannot drift out of sync with reality.

begin;

-- ───────────────────────────────────────────────────────────────────────────────
-- 1. Tables
-- ───────────────────────────────────────────────────────────────────────────────
create table if not exists public.events (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  description  text,
  location     text,
  starts_at    timestamptz,
  ends_at      timestamptz,
  -- Total participant slots. null = uncapped (the app shows no spots-left figure).
  capacity     int,
  tags         text[] not null default '{}',
  -- Denormalized brand name + optional link, mirroring campaigns.
  brand        text not null default '',
  brand_id     uuid references public.brands(id) on delete set null,
  -- Default look when no icon is uploaded: JSON "[a,b]" text, same as campaigns.
  symbol       text,
  colors       text,
  icon_url     text,
  -- The publish gate. Drafts are admin-only and reject signups.
  published    boolean not null default false,
  published_at timestamptz,
  created_at   timestamptz not null default now()
);

create index if not exists events_published_idx on public.events (published, starts_at);
create index if not exists events_brand_id_idx  on public.events (brand_id);

create table if not exists public.event_signups (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (event_id, user_id)
);
create index if not exists event_signups_event_idx on public.event_signups (event_id);

-- ───────────────────────────────────────────────────────────────────────────────
-- 2. RLS — reads of published rows are public; every write goes through an RPC.
-- ───────────────────────────────────────────────────────────────────────────────
alter table public.events        enable row level security;
alter table public.event_signups enable row level security;

drop policy if exists events_select_published on public.events;
create policy events_select_published on public.events
  for select to authenticated
  using (published = true or public.is_admin_caller());

drop policy if exists event_signups_select_own on public.event_signups;
create policy event_signups_select_own on public.event_signups
  for select to authenticated using (user_id = auth.uid());

-- ───────────────────────────────────────────────────────────────────────────────
-- 3. Influencer RPCs — sign up / cancel / list mine
-- ───────────────────────────────────────────────────────────────────────────────
-- Sign up once. Refuses unpublished events and full events; both surface to the
-- client as an error so the optimistic UI rolls back with a real reason.
create or replace function public.sign_up_for_event(p_event uuid)
returns void language plpgsql security definer set search_path = public
as $$
declare
  v_published boolean;
  v_capacity  int;
  v_taken     int;
begin
  -- FOR UPDATE serializes concurrent signups for the SAME event, so the capacity
  -- check below can't be passed by two callers at once and overfill the event.
  select published, capacity into v_published, v_capacity
  from public.events where id = p_event
  for update;

  if not found then raise exception 'event_not_found'; end if;
  if not v_published then raise exception 'event_not_published'; end if;

  -- Already signed up → succeed quietly (idempotent, like apply_to_campaign).
  if exists (select 1 from public.event_signups
             where event_id = p_event and user_id = auth.uid()) then
    return;
  end if;

  if v_capacity is not null then
    select count(*) into v_taken from public.event_signups where event_id = p_event;
    if v_taken >= v_capacity then raise exception 'event_full'; end if;
  end if;

  insert into public.event_signups (event_id, user_id)
  values (p_event, auth.uid())
  on conflict (event_id, user_id) do nothing;
end;
$$;
grant execute on function public.sign_up_for_event(uuid) to authenticated;

create or replace function public.cancel_event_signup(p_event uuid)
returns void language plpgsql security definer set search_path = public
as $$
begin
  delete from public.event_signups where event_id = p_event and user_id = auth.uid();
end;
$$;
grant execute on function public.cancel_event_signup(uuid) to authenticated;

-- The caller's signed-up event ids (mirrors list_my_applications).
create or replace function public.list_my_event_signups()
returns setof uuid language sql stable security definer set search_path = public
as $$
  select event_id from public.event_signups where user_id = auth.uid();
$$;
grant execute on function public.list_my_event_signups() to authenticated;

-- ───────────────────────────────────────────────────────────────────────────────
-- 4. Discover read — PUBLISHED events only, soonest first
-- ───────────────────────────────────────────────────────────────────────────────
-- Undated events sort last. spots_left is derived (null when uncapped).
create or replace function public.list_discover_events()
returns table (
  id           uuid,
  title        text,
  description  text,
  location     text,
  starts_at    timestamptz,
  ends_at      timestamptz,
  capacity     int,
  spots_left   int,
  tags         text[],
  brand        text,
  brand_id     uuid,
  symbol       text,
  colors       text,
  icon_url     text,
  published    boolean,
  signup_count bigint,
  signed_up    boolean
)
language sql stable security definer set search_path = public
as $$
  select
    e.id, e.title, e.description, e.location, e.starts_at, e.ends_at, e.capacity,
    case when e.capacity is null then null
         else greatest(0, e.capacity - (select count(*)::int
                                          from public.event_signups s
                                         where s.event_id = e.id))
    end as spots_left,
    e.tags, e.brand, e.brand_id, e.symbol, e.colors, e.icon_url, e.published,
    (select count(*) from public.event_signups s where s.event_id = e.id) as signup_count,
    exists (select 1 from public.event_signups s
             where s.event_id = e.id and s.user_id = auth.uid()) as signed_up
  from public.events e
  where e.published = true
  order by (e.starts_at is null), e.starts_at asc, e.created_at desc;
$$;
grant execute on function public.list_discover_events() to authenticated;

-- ───────────────────────────────────────────────────────────────────────────────
-- 5. Admin RPCs — list (incl. drafts), upsert, publish/unpublish, delete
-- ───────────────────────────────────────────────────────────────────────────────
-- Same shape as list_discover_events so one client-side row decoder serves both;
-- drafts first (they need attention), then soonest.
create or replace function public.list_admin_events()
returns table (
  id           uuid,
  title        text,
  description  text,
  location     text,
  starts_at    timestamptz,
  ends_at      timestamptz,
  capacity     int,
  spots_left   int,
  tags         text[],
  brand        text,
  brand_id     uuid,
  symbol       text,
  colors       text,
  icon_url     text,
  published    boolean,
  signup_count bigint,
  signed_up    boolean
)
language sql stable security definer set search_path = public
as $$
  select
    e.id, e.title, e.description, e.location, e.starts_at, e.ends_at, e.capacity,
    case when e.capacity is null then null
         else greatest(0, e.capacity - (select count(*)::int
                                          from public.event_signups s
                                         where s.event_id = e.id))
    end as spots_left,
    e.tags, e.brand, e.brand_id, e.symbol, e.colors, e.icon_url, e.published,
    (select count(*) from public.event_signups s where s.event_id = e.id) as signup_count,
    exists (select 1 from public.event_signups s
             where s.event_id = e.id and s.user_id = auth.uid()) as signed_up
  from public.events e
  where public.is_admin_caller()
  order by e.published asc, (e.starts_at is null), e.starts_at asc, e.created_at desc;
$$;
grant execute on function public.list_admin_events() to authenticated;

-- Create (event_id null) or update an event. Returns the event id. Deliberately
-- does NOT touch `published` — publishing is admin_set_event_published, so saving
-- an edit can never silently take a draft live (or pull a live event down).
-- p_title comes first because it's the only required arg; the Supabase clients
-- omit nil args, so everything else must default.
create or replace function public.admin_upsert_event(
  p_title text,
  event_id uuid default null,
  p_description text default null,
  p_location text default null,
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null,
  p_capacity int default null,
  p_tags text[] default null,
  p_brand text default null,
  p_brand_id uuid default null,
  p_symbol text default null,
  p_color_a text default null,
  p_color_b text default null,
  p_icon_url text default null
)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  new_id uuid;
  v_colors text;
  v_brand text;
begin
  if not public.is_admin_caller() then raise exception 'forbidden'; end if;

  -- Two color ints → the JSON "[a,b]" text the apps' parseColors expects.
  if p_color_a is not null or p_color_b is not null then
    v_colors := '[' || coalesce(p_color_a, '0') || ',' || coalesce(p_color_b, '0') || ']';
  else
    v_colors := null;
  end if;

  -- Prefer the linked brand's name; fall back to the passed text.
  if p_brand_id is not null then
    select name into v_brand from public.brands where id = p_brand_id;
  end if;
  v_brand := coalesce(v_brand, p_brand, '');

  if event_id is null then
    insert into public.events
      (title, description, location, starts_at, ends_at, capacity, tags,
       brand, brand_id, symbol, colors, icon_url)
    values
      (p_title, p_description, p_location, p_starts_at, p_ends_at, p_capacity,
       coalesce(p_tags, '{}'), v_brand, p_brand_id, p_symbol, v_colors, p_icon_url)
    returning id into new_id;
    return new_id;
  else
    update public.events set
      title = p_title, description = p_description, location = p_location,
      starts_at = p_starts_at, ends_at = p_ends_at, capacity = p_capacity,
      tags = coalesce(p_tags, '{}'), brand = v_brand, brand_id = p_brand_id,
      symbol = p_symbol, colors = v_colors, icon_url = p_icon_url
    where id = event_id;
    return event_id;
  end if;
end;
$$;
grant execute on function public.admin_upsert_event(text, uuid, text, text, timestamptz, timestamptz, int, text[], text, uuid, text, text, text, text) to authenticated;

-- Publish (make_published true) or pull back to draft (false). published_at keeps
-- the FIRST publish time — unpublishing clears it so a re-publish is honest.
create or replace function public.admin_set_event_published(target uuid, make_published boolean)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin_caller() then raise exception 'forbidden'; end if;
  update public.events set
    published = make_published,
    published_at = case when make_published then coalesce(published_at, now()) else null end
  where id = target;
end;
$$;
grant execute on function public.admin_set_event_published(uuid, boolean) to authenticated;

-- The participant roster for one event, newest signup first. ADMIN-ONLY: who
-- signed up is participant data, not public event info, so this is gated the same
-- way the other admin reads are — influencers only ever see the aggregate count.
create or replace function public.admin_list_event_signups(p_event uuid)
returns table (
  id            uuid,
  name          text,
  handle        text,
  role          text,
  email         text,
  avatar_url    text,
  followers     text,
  signed_up_at  timestamptz
)
language sql stable security definer set search_path = public
as $$
  select
    p.id,
    coalesce(p.name, '')      as name,
    coalesce(p.handle, '')    as handle,
    coalesce(p.role, '')      as role,
    coalesce(p.email, '')     as email,
    p.avatar_url,
    coalesce(p.followers, '') as followers,
    s.created_at              as signed_up_at
  from public.event_signups s
  join public.profiles p on p.id = s.user_id
  where s.event_id = p_event
    and public.is_admin_caller()
  order by s.created_at desc;
$$;
grant execute on function public.admin_list_event_signups(uuid) to authenticated;

create or replace function public.admin_delete_event(target uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin_caller() then raise exception 'forbidden'; end if;
  delete from public.events where id = target;
end;
$$;
grant execute on function public.admin_delete_event(uuid) to authenticated;

commit;
