-- migration-discover-revamp.sql
-- Discover overhaul (run AFTER migration-admin-curation.sql + migration-admin-campaigns.sql).
-- Idempotent. Adds:
--   * brands.icon_url, campaigns.icon_url / description / brand_id
--   * campaign_applications table (real "apply") + apply/withdraw/list RPCs
--   * list_discover_brands / list_discover_campaigns (compute application counts,
--     active-campaign counts, and the caller's applied flag — replaces the old
--     bare select('*') so Featured/Hot/Applied are all server-driven)
--   * admin_upsert_brand / admin_upsert_campaign extended with the new columns
--   * a public Storage bucket "discover" (public read, admin-only write) for icons
--
-- "Hot brands" = ranked by real application volume across the brand's campaigns.
-- "Featured" = brands.featured_rank (admin toggle, already exists).

begin;

-- ───────────────────────────────────────────────────────────────────────────────
-- 1. New columns
-- ───────────────────────────────────────────────────────────────────────────────
alter table public.brands    add column if not exists icon_url text;
alter table public.campaigns add column if not exists icon_url text;
alter table public.campaigns add column if not exists description text;
alter table public.campaigns add column if not exists brand_id uuid references public.brands(id) on delete set null;

create index if not exists campaigns_brand_id_idx on public.campaigns (brand_id);

-- ───────────────────────────────────────────────────────────────────────────────
-- 2. Applications table (real "apply to campaign")
-- ───────────────────────────────────────────────────────────────────────────────
create table if not exists public.campaign_applications (
  id          uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (campaign_id, user_id)
);
create index if not exists campaign_applications_campaign_idx on public.campaign_applications (campaign_id);

alter table public.campaign_applications enable row level security;
-- Reads of one's own applications; all writes go through the SECURITY DEFINER RPCs.
drop policy if exists capp_select_own on public.campaign_applications;
create policy capp_select_own on public.campaign_applications
  for select to authenticated using (user_id = auth.uid());

-- ───────────────────────────────────────────────────────────────────────────────
-- 3. apply / withdraw / list-mine RPCs
-- ───────────────────────────────────────────────────────────────────────────────
-- Apply once; decrement spots_left only on a genuinely new application.
create or replace function public.apply_to_campaign(p_campaign uuid)
returns void language plpgsql security definer set search_path = public
as $$
begin
  insert into public.campaign_applications (campaign_id, user_id)
  values (p_campaign, auth.uid())
  on conflict (campaign_id, user_id) do nothing;
  if found then
    update public.campaigns set spots_left = greatest(0, coalesce(spots_left, 0) - 1)
    where id = p_campaign and coalesce(spots_left, 0) > 0;
  end if;
end;
$$;
grant execute on function public.apply_to_campaign(uuid) to authenticated;

-- Withdraw; give the spot back only if an application was actually removed.
create or replace function public.withdraw_from_campaign(p_campaign uuid)
returns void language plpgsql security definer set search_path = public
as $$
begin
  delete from public.campaign_applications where campaign_id = p_campaign and user_id = auth.uid();
  if found then
    update public.campaigns set spots_left = coalesce(spots_left, 0) + 1 where id = p_campaign;
  end if;
end;
$$;
grant execute on function public.withdraw_from_campaign(uuid) to authenticated;

-- The caller's applied campaign ids (replaces the on-device AsyncStorage list).
create or replace function public.list_my_applications()
returns setof uuid language sql stable security definer set search_path = public
as $$
  select campaign_id from public.campaign_applications where user_id = auth.uid();
$$;
grant execute on function public.list_my_applications() to authenticated;

-- ───────────────────────────────────────────────────────────────────────────────
-- 4. Discover load RPCs (server-driven Featured / Hot / Applied)
-- ───────────────────────────────────────────────────────────────────────────────
create or replace function public.list_discover_brands()
returns table (
  id                uuid,
  name              text,
  category          text,
  tagline           text,
  icon_url          text,
  symbol            text,
  colors            text,
  featured_rank     int,
  active_campaigns  int,
  application_count bigint
)
language sql stable security definer set search_path = public
as $$
  select
    b.id, b.name, b.category, b.tagline, b.icon_url, b.symbol, b.colors, b.featured_rank,
    (select count(*) from public.campaigns c where c.brand_id = b.id)::int as active_campaigns,
    (select count(*)
       from public.campaign_applications a
       join public.campaigns c on c.id = a.campaign_id
      where c.brand_id = b.id) as application_count
  from public.brands b
  order by (b.featured_rank is null), b.featured_rank asc, b.name asc;
$$;
grant execute on function public.list_discover_brands() to authenticated;

create or replace function public.list_discover_campaigns()
returns table (
  id                uuid,
  title             text,
  brand             text,
  brand_id          uuid,
  budget            text,
  tags              text[],
  deadline          text,
  description       text,
  icon_url          text,
  symbol            text,
  colors            text,
  spots_left        int,
  application_count bigint,
  applied           boolean
)
language sql stable security definer set search_path = public
as $$
  select
    c.id, c.title, c.brand, c.brand_id, c.budget, c.tags, c.deadline, c.description,
    c.icon_url, c.symbol, c.colors, c.spots_left,
    (select count(*) from public.campaign_applications a where a.campaign_id = c.id) as application_count,
    exists (select 1 from public.campaign_applications a
            where a.campaign_id = c.id and a.user_id = auth.uid()) as applied
  from public.campaigns c
  order by c.created_at desc;
$$;
grant execute on function public.list_discover_campaigns() to authenticated;

-- ───────────────────────────────────────────────────────────────────────────────
-- 5. Extend the admin upsert RPCs with the new columns
-- ───────────────────────────────────────────────────────────────────────────────
-- Brand: + p_icon_url
drop function if exists public.admin_upsert_brand(text, uuid, text, text, text, text, int, int);
drop function if exists public.admin_upsert_brand(text, uuid, text, text, text, text, int, int, text);
create or replace function public.admin_upsert_brand(
  p_name text,
  brand_id uuid default null,
  p_category text default null,
  p_tagline text default null,
  p_symbol text default null,
  p_colors text default null,
  p_active_campaigns int default null,
  p_featured_rank int default null,
  p_icon_url text default null
)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare new_id uuid;
begin
  if not public.is_admin_caller() then raise exception 'forbidden'; end if;
  if brand_id is null then
    insert into public.brands (name, category, tagline, symbol, colors, active_campaigns, featured_rank, icon_url)
    values (p_name, p_category, p_tagline, p_symbol, p_colors, p_active_campaigns, p_featured_rank, p_icon_url)
    returning id into new_id;
    return new_id;
  else
    update public.brands set
      name = p_name, category = p_category, tagline = p_tagline,
      symbol = p_symbol, colors = p_colors,
      active_campaigns = p_active_campaigns, featured_rank = p_featured_rank,
      icon_url = p_icon_url
    where id = brand_id;
    return brand_id;
  end if;
end;
$$;
grant execute on function public.admin_upsert_brand(text, uuid, text, text, text, text, int, int, text) to authenticated;

-- Campaign: + p_icon_url, p_description, p_brand_id. When p_brand_id is given, the
-- denormalized brand name is filled from the brand row (keeps display in sync).
drop function if exists public.admin_upsert_campaign(uuid, text, text, text, text[], text, text, text, text, int);
drop function if exists public.admin_upsert_campaign(text, uuid, text, text, text[], text, text, text, text, int);
drop function if exists public.admin_upsert_campaign(text, uuid, text, text, text[], text, text, text, text, int, text, text, uuid);
create or replace function public.admin_upsert_campaign(
  p_title text,
  campaign_id uuid default null,
  p_brand text default null,
  p_budget text default null,
  p_tags text[] default null,
  p_deadline text default null,
  p_symbol text default null,
  p_color_a text default null,
  p_color_b text default null,
  p_spots_left int default null,
  p_icon_url text default null,
  p_description text default null,
  p_brand_id uuid default null
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

  if campaign_id is null then
    insert into public.campaigns
      (title, brand, brand_id, budget, tags, deadline, symbol, colors, spots_left, icon_url, description)
    values
      (p_title, v_brand, p_brand_id, p_budget, coalesce(p_tags, '{}'), p_deadline, p_symbol, v_colors,
       p_spots_left, p_icon_url, p_description)
    returning id into new_id;
    return new_id;
  else
    update public.campaigns set
      title = p_title, brand = v_brand, brand_id = p_brand_id, budget = p_budget,
      tags = coalesce(p_tags, '{}'), deadline = p_deadline, symbol = p_symbol,
      colors = v_colors, spots_left = p_spots_left, icon_url = p_icon_url, description = p_description
    where id = campaign_id;
    return campaign_id;
  end if;
end;
$$;
grant execute on function public.admin_upsert_campaign(text, uuid, text, text, text[], text, text, text, text, int, text, text, uuid) to authenticated;

-- ───────────────────────────────────────────────────────────────────────────────
-- 6. Public Storage bucket "discover" for brand/campaign icons
--    (public read so Discover can show them; admin-only write)
-- ───────────────────────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('discover', 'discover', true)
on conflict (id) do update set public = true;

drop policy if exists discover_public_read on storage.objects;
create policy discover_public_read on storage.objects
  for select using (bucket_id = 'discover');

drop policy if exists discover_admin_insert on storage.objects;
create policy discover_admin_insert on storage.objects
  for insert to authenticated with check (bucket_id = 'discover' and public.is_admin_caller());

drop policy if exists discover_admin_update on storage.objects;
create policy discover_admin_update on storage.objects
  for update to authenticated using (bucket_id = 'discover' and public.is_admin_caller());

drop policy if exists discover_admin_delete on storage.objects;
create policy discover_admin_delete on storage.objects
  for delete to authenticated using (bucket_id = 'discover' and public.is_admin_caller());

commit;
