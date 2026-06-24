-- migration-admin-campaigns.sql
-- Admin curation for the Discover "Open Campaigns" strip, gated by the existing
-- is_admin flag — the campaign half of the admin-curated Discover page.
--
--   * Admin RPCs (SECURITY DEFINER, is_admin-gated) to create / edit / delete the
--     campaigns shown on Discover. Reads stay public; only writes are gated, and
--     via RPC so we don't touch the campaigns table's RLS.
--   * Campaigns have NO featured_rank — Discover shows ALL open campaigns from the
--     table (the app only falls back to SampleData when the table is empty).
--   * Colors are passed as two values (color_a / color_b) and stored as the JSON
--     `[a,b]` text the app's parseColors expects, mirroring the brand pattern.
--
-- Run AFTER migration-admin-curation.sql (which defines is_admin_caller). Idempotent.
-- Does NOT redefine is_admin_caller — it already exists.

begin;

-- Create (campaign_id null) or update a campaign. Returns the campaign id. p_title
-- is the only required arg; everything else defaults so the call resolves regardless
-- of which nil args the Supabase client omits. (Required param comes first.)
drop function if exists public.admin_upsert_campaign(uuid, text, text, text, text[], text, text, text, text, int);
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
  p_spots_left int default null
)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  new_id uuid;
  v_colors text;
begin
  if not public.is_admin_caller() then raise exception 'forbidden'; end if;
  -- Combine the two color values into the JSON [a,b] text the app's parseColors
  -- expects. Null when neither is supplied (the column stays null and the client
  -- falls back to its default gradient).
  if p_color_a is not null or p_color_b is not null then
    v_colors := '[' || coalesce(p_color_a, '0') || ',' || coalesce(p_color_b, '0') || ']';
  else
    v_colors := null;
  end if;

  if campaign_id is null then
    insert into public.campaigns (title, brand, budget, tags, deadline, symbol, colors, spots_left)
    values (p_title, coalesce(p_brand, ''), p_budget, coalesce(p_tags, '{}'), p_deadline, p_symbol, v_colors, p_spots_left)
    returning id into new_id;
    return new_id;
  else
    update public.campaigns set
      title = p_title, brand = coalesce(p_brand, ''), budget = p_budget,
      tags = coalesce(p_tags, '{}'), deadline = p_deadline, symbol = p_symbol,
      colors = v_colors, spots_left = p_spots_left
    where id = campaign_id;
    return campaign_id;
  end if;
end;
$$;
grant execute on function public.admin_upsert_campaign(text, uuid, text, text, text[], text, text, text, text, int) to authenticated;

create or replace function public.admin_delete_campaign(target uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin_caller() then raise exception 'forbidden'; end if;
  delete from public.campaigns where id = target;
end;
$$;
grant execute on function public.admin_delete_campaign(uuid) to authenticated;

commit;
