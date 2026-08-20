-- ═══════════════════════════════════════════════════════════════════════════
-- 0028 · SECURITY, STORAGE & REALTIME HARDENING
--
-- Three defects found while auditing the deployed surface:
--
--   1. `public.available_riders` was granted to `authenticated` but, unlike every
--      other privileged read, carried no permission check in its body. Because it
--      is SECURITY DEFINER, any signed-in customer could call it directly and get
--      the full roster — names, phone numbers, duty state and live proximity.
--      The edge function guarded it; the RPC did not.
--
--   2. Storage buckets existed only in `config.toml`, which `supabase start` reads
--      and `supabase db push` does not. On the hosted project the buckets were
--      therefore absent, so every upload the RLS policies were written for would
--      have failed with "Bucket not found".
--
--   3. Four tables were in the realtime publication without REPLICA IDENTITY
--      FULL. Realtime needs the old row to authorise an UPDATE against RLS, so
--      those change events were being dropped — including `delivery_partners`
--      (rider duty state) and `support_tickets` (the support inbox).
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── 1 · available_riders needs the same guard as every other dispatch read ──
-- Signature and return type are unchanged, so the existing grant still applies.
create or replace function public.available_riders(
  p_branch_id uuid default null,
  p_order_id uuid default null
)
returns table (
  delivery_partner_id uuid,
  full_name text,
  phone text,
  photo_path text,
  vehicle_type public.vehicle_type,
  duty_state public.rider_duty_state,
  active_load int,
  max_concurrent_orders smallint,
  distance_to_store_km numeric,
  last_location_at timestamptz,
  rating_average numeric,
  successful_deliveries int,
  score numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  -- Dispatch is the primary caller; view permissions are enough to *read* the
  -- roster, which is what the operations board and rider directory need.
  if not app.has_any_permission(
    array['delivery.assign', 'delivery.view', 'rider.view'],
    v_branch
  ) then
    perform app.fail(
      'PERMISSION_DENIED',
      'You do not have permission to view delivery partners.',
      jsonb_build_object('permission', 'delivery.view')
    );
  end if;

  return query
  with branch as (
    select b.id, b.latitude, b.longitude
    from public.branches b
    where b.id = v_branch
  )
  select
    dp.id,
    dp.full_name,
    dp.phone::text,
    dp.photo_path,
    dp.vehicle_type,
    dp.duty_state,
    app.rider_active_load(dp.id) as active_load,
    dp.max_concurrent_orders,
    case
      when loc.latitude is not null
      then app.haversine_km(loc.latitude, loc.longitude, br.latitude, br.longitude)
      else null
    end as distance_to_store_km,
    loc.recorded_at,
    dp.rating_average,
    dp.successful_deliveries,
    -- Lower score = better candidate. Unchanged, so manual and automatic
    -- dispatch keep ranking identically.
    (
      app.rider_active_load(dp.id) * 100
      + coalesce(
          case
            when loc.latitude is not null
            then app.haversine_km(loc.latitude, loc.longitude, br.latitude, br.longitude)
            else 15
          end, 15
        ) * 10
      + (5 - dp.rating_average) * 5
      + case when dp.duty_state = 'AVAILABLE' then 0 else 50 end
    )::numeric as score
  from public.delivery_partners dp
  cross join branch br
  left join public.delivery_partner_locations loc on loc.delivery_partner_id = dp.id
  where dp.deleted_at is null
    and dp.onboarding_status = 'ACTIVE'
    and dp.branch_id = br.id
    and dp.duty_state in ('AVAILABLE', 'BUSY')
    and app.rider_active_load(dp.id) < dp.max_concurrent_orders
  order by score;
end;
$$;

comment on function public.available_riders is
  'Dispatch candidate list, ranked. Requires delivery.assign, delivery.view or rider.view.';

-- ─── 2 · Storage buckets, as version-controlled schema ──────────────────────
-- config.toml provisions these for a local stack only. Declaring them here means
-- `supabase db push` creates them on every environment, which is the same
-- guarantee the rest of the schema has.
do $$
declare
  b record;
begin
  for b in
    select *
    from (
      values
        ('menu-images',         true,   8388608, array['image/png','image/jpeg','image/webp','image/avif']),
        ('banners',             true,   8388608, array['image/png','image/jpeg','image/webp','image/avif']),
        ('brand-assets',        true,   4194304, array['image/png','image/jpeg','image/webp','image/svg+xml','image/x-icon']),
        ('staff-photos',        false,  4194304, array['image/png','image/jpeg','image/webp']),
        ('rider-documents',     false, 10485760, array['image/png','image/jpeg','image/webp','application/pdf']),
        ('delivery-proofs',     false,  6291456, array['image/png','image/jpeg','image/webp']),
        ('support-attachments', false, 10485760, array['image/png','image/jpeg','image/webp','application/pdf']),
        ('invoices',            false,  5242880, array['application/pdf'])
    ) as t(id, is_public, size_limit, mime_types)
  loop
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values (b.id, b.id, b.is_public, b.size_limit, b.mime_types)
    on conflict (id) do update
      set public = excluded.public,
          file_size_limit = excluded.file_size_limit,
          allowed_mime_types = excluded.allowed_mime_types;
  end loop;
end;
$$;

-- ─── 2b · Guests could not read the catalog they were granted access to ─────
--
-- `grant select on all tables in schema public to anon` was in place, and the
-- catalog policies read
--
--     using (deleted_at is null and (is_active or app.has_permission('menu.view')))
--
-- but `app.has_permission` was granted to `authenticated` only. RLS expressions
-- run with the caller's privileges, and the planner is free to evaluate the
-- second branch of an OR first, so a guest selecting from `products` or
-- `categories` got "permission denied for function has_permission" instead of the
-- menu.
--
-- The SECURITY DEFINER read functions (`menu_catalog`, `home_feed`) masked this,
-- which is why the mobile app still worked — but any direct table read or
-- Realtime subscription by an anonymous client failed, and a storefront added
-- later would have hit it immediately.
--
-- Granting these is safe and consistent with the other RLS helpers already
-- exposed to `anon`: each is STABLE, reads only the caller's own grants, and with
-- no JWT `auth.uid()` is null, so every one of them returns false.
grant execute on function app.has_permission(text, uuid) to anon;
grant execute on function app.has_any_permission(text[], uuid) to anon;
grant execute on function app.has_role(public.app_role, uuid) to anon;
grant execute on function app.is_staff() to anon;
grant execute on function app.is_rider() to anon;
grant execute on function app.can_access_branch(uuid) to anon;
grant execute on function app.accessible_branch_ids() to anon;
grant execute on function app.primary_role() to anon;
grant execute on function app.account_is_active() to anon;
grant execute on function app.owns_order(uuid) to anon;

-- ─── 3 · Realtime needs old-row values to authorise updates against RLS ─────
alter table public.order_items replica identity full;
alter table public.delivery_partners replica identity full;
alter table public.branches replica identity full;
alter table public.support_tickets replica identity full;

-- ─── 4 · Review moderation, as an audited operation ─────────────────────────
-- The admin dashboard previously updated `public.reviews` directly through the
-- table grant. That works, but it records neither who moderated nor why, and a
-- hidden review is exactly the kind of action an operator may later be asked to
-- justify. Routing it through a function makes the audit entry unavoidable.
create or replace function public.moderate_review(
  p_review_id uuid,
  p_status public.review_status default null,
  p_response text default null,
  p_internal_note text default null,
  p_flagged_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_review public.reviews;
  v_updated public.reviews;
begin
  select * into v_review from public.reviews where id = p_review_id;

  if not found then
    perform app.fail('ITEM_NOT_FOUND', 'That review no longer exists.');
  end if;

  perform app.require_permission('review.moderate', v_review.branch_id);

  if p_status is null
     and p_response is null
     and p_internal_note is null
     and p_flagged_reason is null then
    perform app.fail('CHECKOUT_INVALID', 'Nothing to change on this review.');
  end if;

  update public.reviews
  set status = coalesce(p_status, status),
      flagged_reason = case
        when p_status = 'FLAGGED' then coalesce(p_flagged_reason, flagged_reason)
        when p_status is not null and p_status <> 'FLAGGED' then null
        else coalesce(p_flagged_reason, flagged_reason)
      end,
      internal_note = coalesce(p_internal_note, internal_note),
      response_body = coalesce(nullif(btrim(coalesce(p_response, '')), ''), response_body),
      responded_by = case
        when nullif(btrim(coalesce(p_response, '')), '') is not null then auth.uid()
        else responded_by
      end,
      responded_at = case
        when nullif(btrim(coalesce(p_response, '')), '') is not null then now()
        else responded_at
      end,
      moderated_by = auth.uid(),
      moderated_at = now(),
      updated_at = now()
  where id = p_review_id
  returning * into v_updated;

  perform app.audit(
    'UPDATE',
    'review',
    p_review_id::text,
    jsonb_build_object('status', v_review.status, 'response_body', v_review.response_body),
    jsonb_build_object('status', v_updated.status, 'response_body', v_updated.response_body),
    p_flagged_reason,
    format('Review on order %s', v_review.order_id),
    v_review.branch_id
  );

  return jsonb_build_object(
    'review_id', p_review_id,
    'status', v_updated.status,
    'has_response', v_updated.response_body is not null,
    'moderated_at', v_updated.moderated_at
  );
end;
$$;

comment on function public.moderate_review is
  'Hide, publish, flag or publicly answer a review. Writes an audit entry naming the operator.';

-- Hiding a review recalculates the rider's rating over *published* reviews only.
-- When the hidden one was their only rated review, `avg()` returns null and the
-- NOT NULL column rejects it — so the moderation attempt failed outright with a
-- constraint error. A rider with no visible ratings has no rating, which is 0.
create or replace function app.tg_review_aggregates()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.delivery_partner_id is not null and new.delivery_rating is not null then
    update public.delivery_partners dp
    set rating_count = agg.cnt,
        rating_average = agg.avg_rating,
        updated_at = now()
    from (
      select
        count(*)::int as cnt,
        -- No published ratings means no rating, not null.
        coalesce(round(avg(delivery_rating)::numeric, 2), 0) as avg_rating
      from public.reviews
      where delivery_partner_id = new.delivery_partner_id
        and delivery_rating is not null
        and status = 'PUBLISHED'
    ) agg
    where dp.id = new.delivery_partner_id;
  end if;

  return new;
end;
$$;

-- Direct table writes are no longer needed now that moderation is a function,
-- and removing the grant closes the un-audited path.
revoke update on public.reviews from authenticated;

grant execute on function public.moderate_review(
  uuid, public.review_status, text, text, text
) to authenticated;
