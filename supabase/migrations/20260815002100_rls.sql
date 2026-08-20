-- ═══════════════════════════════════════════════════════════════════════════
-- 0021 · ROW LEVEL SECURITY
--
-- Principles
--   · RLS is ON for every table in `public`. Default deny.
--   · Customers see only their own rows.
--   · Riders see only their own assignments and the orders attached to them.
--   · Staff read/write is gated by permission, not by role name.
--   · Financial tables (orders, payments, refunds, ledgers) are READ-ONLY to
--     clients. All writes go through SECURITY DEFINER functions.
--   · service_role bypasses RLS by design; the key never ships to a client.
-- ═══════════════════════════════════════════════════════════════════════════

-- Enable RLS everywhere in public, then add policies.
do $$
declare
  r record;
begin
  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
  loop
    execute format('alter table public.%I enable row level security', r.relname);
    execute format('alter table public.%I force row level security', r.relname);
  end loop;
end;
$$;

-- FORCE ROW LEVEL SECURITY also applies to the table owner (postgres), which
-- would break our SECURITY DEFINER functions. Re-disable forcing; ENABLE is the
-- protection that matters for anon/authenticated.
do $$
declare
  r record;
begin
  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
  loop
    execute format('alter table public.%I no force row level security', r.relname);
  end loop;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- RECURSION BREAKERS
--
-- `orders` and `delivery_assignments` need to reference each other: a rider may
-- read the order they are carrying, and a customer may see who is carrying it.
-- Expressing that directly in both policies makes Postgres evaluate each policy
-- from inside the other — "infinite recursion detected in policy".
--
-- These SECURITY DEFINER helpers read the join table with RLS bypassed, so each
-- policy asks a plain question instead of triggering the other policy.
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.is_rider_for_order(p_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.delivery_assignments da
    join public.delivery_partners dp on dp.id = da.delivery_partner_id
    where da.order_id = p_order_id
      and dp.user_id = auth.uid()
      and da.status in ('OFFERED', 'ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER', 'COMPLETED')
  );
$$;

comment on function app.is_rider_for_order is
  'True when the caller is the delivery partner on this order. SECURITY DEFINER to break RLS recursion.';

create or replace function app.owns_order(p_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.orders o
    where o.id = p_order_id and o.user_id = auth.uid()
  );
$$;

create or replace function app.order_branch(p_order_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select o.branch_id from public.orders o where o.id = p_order_id;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- PUBLIC CATALOG — readable by everyone, including guests browsing the menu
-- ═══════════════════════════════════════════════════════════════════════════
create policy categories_public_read on public.categories
  for select to anon, authenticated
  using (deleted_at is null and (is_active or app.has_permission('menu.view')));

create policy categories_staff_write on public.categories
  for all to authenticated
  using (app.has_permission('menu.view'))
  with check (app.has_permission('menu.create') or app.has_permission('menu.update'));

create policy subcategories_public_read on public.subcategories
  for select to anon, authenticated
  using (deleted_at is null and (is_active or app.has_permission('menu.view')));

create policy subcategories_staff_write on public.subcategories
  for all to authenticated
  using (app.has_permission('menu.view'))
  with check (app.has_permission('menu.create') or app.has_permission('menu.update'));

create policy products_public_read on public.products
  for select to anon, authenticated
  using (deleted_at is null and (is_active or app.has_permission('menu.view')));

create policy products_staff_write on public.products
  for all to authenticated
  using (app.has_permission('menu.view'))
  with check (app.has_permission('menu.create') or app.has_permission('menu.update'));

create policy product_images_public_read on public.product_images
  for select to anon, authenticated using (true);

create policy product_images_staff_write on public.product_images
  for all to authenticated
  using (app.has_permission('menu.view'))
  with check (app.has_permission('menu.update'));

create policy product_variants_public_read on public.product_variants
  for select to anon, authenticated
  using (deleted_at is null and (is_active or app.has_permission('menu.view')));

create policy product_variants_staff_write on public.product_variants
  for all to authenticated
  using (app.has_permission('menu.view'))
  with check (app.has_permission('menu.update'));

create policy modifier_groups_public_read on public.modifier_groups
  for select to anon, authenticated
  using (deleted_at is null and (is_active or app.has_permission('menu.view')));

create policy modifier_groups_staff_write on public.modifier_groups
  for all to authenticated
  using (app.has_permission('menu.view'))
  with check (app.has_permission('menu.update'));

create policy modifiers_public_read on public.modifiers
  for select to anon, authenticated
  using (deleted_at is null and (is_active or app.has_permission('menu.view')));

create policy modifiers_staff_write on public.modifiers
  for all to authenticated
  using (app.has_permission('menu.view'))
  with check (app.has_permission('menu.update'));

create policy product_modifier_groups_public_read on public.product_modifier_groups
  for select to anon, authenticated using (true);

create policy product_modifier_groups_staff_write on public.product_modifier_groups
  for all to authenticated
  using (app.has_permission('menu.view'))
  with check (app.has_permission('menu.update'));

-- Availability is public read (the customer app subscribes to it in realtime)
-- but writes go only through set_product_availability().
create policy product_availability_public_read on public.product_availability
  for select to anon, authenticated using (true);

create policy product_availability_staff_write on public.product_availability
  for all to authenticated
  using (app.has_permission('menu.availability'))
  with check (app.has_permission('menu.availability'));

create policy product_schedules_public_read on public.product_schedules
  for select to anon, authenticated using (true);

create policy product_schedules_staff_write on public.product_schedules
  for all to authenticated
  using (app.has_permission('menu.view'))
  with check (app.has_permission('menu.update'));

create policy collections_public_read on public.collections
  for select to anon, authenticated
  using (deleted_at is null and (is_active or app.has_permission('menu.view')));

create policy collections_staff_write on public.collections
  for all to authenticated
  using (app.has_permission('cms.view'))
  with check (app.has_permission('cms.update'));

create policy collection_products_public_read on public.collection_products
  for select to anon, authenticated using (true);

create policy collection_products_staff_write on public.collection_products
  for all to authenticated
  using (app.has_permission('cms.view'))
  with check (app.has_permission('cms.update'));

create policy tax_categories_read on public.tax_categories
  for select to anon, authenticated using (deleted_at is null);

create policy tax_categories_staff_write on public.tax_categories
  for all to authenticated
  using (app.has_permission('settings.view'))
  with check (app.has_permission('settings.update'));

-- ═══════════════════════════════════════════════════════════════════════════
-- BRANCH & CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════
create policy branches_public_read on public.branches
  for select to anon, authenticated using (deleted_at is null);

create policy branches_manage on public.branches
  for update to authenticated
  using (app.has_permission('branch.manage', id))
  with check (app.has_permission('branch.manage', id));

create policy branches_insert on public.branches
  for insert to authenticated
  with check (app.has_permission('settings.update'));

create policy branch_hours_public_read on public.branch_hours
  for select to anon, authenticated using (true);

create policy branch_hours_manage on public.branch_hours
  for all to authenticated
  using (app.has_permission('branch.manage', branch_id))
  with check (app.has_permission('branch.manage', branch_id));

create policy branch_holidays_public_read on public.branch_holidays
  for select to anon, authenticated using (true);

create policy branch_holidays_manage on public.branch_holidays
  for all to authenticated
  using (app.has_permission('branch.manage', branch_id))
  with check (app.has_permission('branch.manage', branch_id));

create policy branch_status_log_read on public.branch_status_log
  for select to authenticated
  using (app.has_permission('order.view', branch_id));

create policy branch_status_log_insert on public.branch_status_log
  for insert to authenticated
  with check (app.has_permission('branch.manage', branch_id));

-- Delivery zones: customers need fees and thresholds; polygons are harmless.
create policy delivery_zones_public_read on public.delivery_zones
  for select to anon, authenticated using (deleted_at is null and is_active);

create policy delivery_zones_manage on public.delivery_zones
  for all to authenticated
  using (app.has_permission('branch.manage', branch_id))
  with check (app.has_permission('branch.manage', branch_id));

-- Only non-secret, public settings reach clients.
create policy settings_public_read on public.settings
  for select to anon, authenticated
  using (is_public or app.has_permission('settings.view'));

create policy settings_write on public.settings
  for all to authenticated
  using (app.has_permission('settings.update'))
  with check (app.has_permission('settings.update'));

create policy settings_history_read on public.settings_history
  for select to authenticated using (app.has_permission('audit.view'));

create policy feature_flags_public_read on public.feature_flags
  for select to anon, authenticated using (true);

create policy feature_flags_write on public.feature_flags
  for all to authenticated
  using (app.has_permission('feature_flag.update'))
  with check (app.has_permission('feature_flag.update'));

create policy cancellation_policies_read on public.cancellation_policies
  for select to anon, authenticated using (true);

create policy cancellation_policies_write on public.cancellation_policies
  for all to authenticated
  using (app.has_permission('settings.update'))
  with check (app.has_permission('settings.update'));

create policy refund_policies_read on public.refund_policies
  for select to authenticated using (app.has_permission('refund.view'));

create policy refund_policies_write on public.refund_policies
  for all to authenticated
  using (app.has_permission('settings.update'))
  with check (app.has_permission('settings.update'));

create policy order_status_transitions_read on public.order_status_transitions
  for select to anon, authenticated using (true);

create policy delivery_payout_config_read on public.delivery_payout_config
  for select to authenticated using (app.is_staff());

create policy delivery_payout_config_write on public.delivery_payout_config
  for all to authenticated
  using (app.has_permission('settings.update'))
  with check (app.has_permission('settings.update'));

-- ═══════════════════════════════════════════════════════════════════════════
-- IDENTITY & RBAC
-- ═══════════════════════════════════════════════════════════════════════════
create policy profiles_self_read on public.profiles
  for select to authenticated
  using (id = auth.uid() or app.has_permission('customer.view') or app.has_permission('staff.view'));

-- A customer may edit their own profile but can never change status or stats.
create policy profiles_self_update on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy profiles_staff_update on public.profiles
  for update to authenticated
  using (app.has_permission('customer.update'))
  with check (app.has_permission('customer.update'));

create policy roles_read on public.roles
  for select to authenticated using (true);

create policy roles_write on public.roles
  for all to authenticated
  using (app.has_permission('role.manage'))
  with check (app.has_permission('role.manage'));

create policy permissions_read on public.permissions
  for select to authenticated using (true);

create policy permissions_write on public.permissions
  for all to authenticated
  using (app.has_permission('role.manage'))
  with check (app.has_permission('role.manage'));

create policy role_permissions_read on public.role_permissions
  for select to authenticated using (true);

create policy role_permissions_write on public.role_permissions
  for all to authenticated
  using (app.has_permission('role.manage'))
  with check (app.has_permission('role.manage'));

create policy user_roles_self_read on public.user_roles
  for select to authenticated
  using (user_id = auth.uid() or app.has_permission('staff.view'));

create policy user_roles_write on public.user_roles
  for all to authenticated
  using (app.has_permission('role.assign'))
  with check (app.has_permission('role.assign'));

create policy staff_members_read on public.staff_members
  for select to authenticated
  using (user_id = auth.uid() or app.has_permission('staff.view'));

create policy staff_members_write on public.staff_members
  for all to authenticated
  using (app.has_permission('staff.update'))
  with check (app.has_permission('staff.create') or app.has_permission('staff.update'));

-- ═══════════════════════════════════════════════════════════════════════════
-- ADDRESSES
-- ═══════════════════════════════════════════════════════════════════════════
create policy addresses_owner_all on public.addresses
  for all to authenticated
  using (user_id = auth.uid() and deleted_at is null)
  with check (user_id = auth.uid());

create policy addresses_staff_read on public.addresses
  for select to authenticated using (app.has_permission('customer.view'));

-- ═══════════════════════════════════════════════════════════════════════════
-- CART — owned entirely by the customer
-- ═══════════════════════════════════════════════════════════════════════════
create policy carts_owner_all on public.carts
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy carts_staff_read on public.carts
  for select to authenticated using (app.has_permission('order.view', branch_id));

create policy cart_items_owner_all on public.cart_items
  for all to authenticated
  using (exists (select 1 from public.carts c where c.id = cart_id and c.user_id = auth.uid()))
  with check (exists (select 1 from public.carts c where c.id = cart_id and c.user_id = auth.uid()));

create policy cart_item_modifiers_owner_all on public.cart_item_modifiers
  for all to authenticated
  using (exists (
    select 1 from public.cart_items ci
    join public.carts c on c.id = ci.cart_id
    where ci.id = cart_item_id and c.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.cart_items ci
    join public.carts c on c.id = ci.cart_id
    where ci.id = cart_item_id and c.user_id = auth.uid()
  ));

create policy search_queries_owner on public.search_queries
  for select to authenticated
  using (user_id = auth.uid() or app.has_permission('analytics.view'));

create policy search_queries_insert on public.search_queries
  for insert to authenticated with check (user_id = auth.uid() or user_id is null);

-- ═══════════════════════════════════════════════════════════════════════════
-- ORDERS — read-only to clients; every write is a function
-- ═══════════════════════════════════════════════════════════════════════════
create policy orders_customer_read on public.orders
  for select to authenticated
  using (
    user_id = auth.uid()
    or app.has_permission('order.view', branch_id)
    -- Riders may read the orders they are actively carrying. Routed through a
    -- SECURITY DEFINER helper so this does not recurse into the
    -- delivery_assignments policy, which in turn reads orders.
    or app.is_rider_for_order(id)
  );

-- Deliberately no INSERT/UPDATE/DELETE policy: orders are written only by
-- app.place_order() / app.transition_order() running as SECURITY DEFINER.

create policy order_items_read on public.order_items
  for select to authenticated
  using (
    app.owns_order(order_id)
    or app.has_permission('order.view', app.order_branch(order_id))
    or app.is_rider_for_order(order_id)
  );

create policy order_item_modifiers_read on public.order_item_modifiers
  for select to authenticated
  using (exists (
    select 1 from public.order_items oi
    where oi.id = order_item_id
      and (
        app.owns_order(oi.order_id)
        or app.has_permission('order.view', app.order_branch(oi.order_id))
        or app.is_rider_for_order(oi.order_id)
      )
  ));

create policy order_status_history_read on public.order_status_history
  for select to authenticated
  using (
    app.owns_order(order_id)
    or app.has_permission('order.view', app.order_branch(order_id))
    or app.is_rider_for_order(order_id)
  );

-- Internal notes are staff-only, never visible to the customer.
create policy order_notes_staff on public.order_notes
  for select to authenticated
  using (app.has_permission('order.view', app.order_branch(order_id)));

create policy order_notes_insert on public.order_notes
  for insert to authenticated
  with check (app.has_permission('order.note', app.order_branch(order_id)));

-- ═══════════════════════════════════════════════════════════════════════════
-- PAYMENTS & REFUNDS — read-only to clients
-- ═══════════════════════════════════════════════════════════════════════════
create policy payments_read on public.payments
  for select to authenticated
  using (user_id = auth.uid() or app.has_permission('payment.view', branch_id));

create policy payment_events_read on public.payment_events
  for select to authenticated using (app.has_permission('payment.view'));

create policy cod_collections_read on public.cod_collections
  for select to authenticated
  using (
    app.has_permission('payment.view')
    or exists (
      select 1 from public.delivery_partners dp
      where dp.id = delivery_partner_id and dp.user_id = auth.uid()
    )
    or app.owns_order(order_id)
  );

create policy refunds_read on public.refunds
  for select to authenticated
  using (user_id = auth.uid() or app.has_permission('refund.view'));

create policy refund_items_read on public.refund_items
  for select to authenticated
  using (exists (
    select 1 from public.refunds r
    where r.id = refund_id and (r.user_id = auth.uid() or app.has_permission('refund.view'))
  ));

-- ═══════════════════════════════════════════════════════════════════════════
-- PROMOTIONS
-- ═══════════════════════════════════════════════════════════════════════════
-- Customers see live, visible coupons. Hidden/campaign coupons are applied by
-- code through apply_coupon(), which runs as SECURITY DEFINER.
create policy coupons_public_read on public.coupons
  for select to anon, authenticated
  using (
    (deleted_at is null and is_active and is_visible
     and starts_at <= now() and (ends_at is null or ends_at > now()))
    or app.has_permission('coupon.view')
  );

create policy coupons_write on public.coupons
  for all to authenticated
  using (app.has_permission('coupon.view'))
  with check (app.has_permission('coupon.create') or app.has_permission('coupon.update'));

create policy coupon_rules_read on public.coupon_rules
  for select to authenticated using (app.has_permission('coupon.view'));

create policy coupon_rules_write on public.coupon_rules
  for all to authenticated
  using (app.has_permission('coupon.update'))
  with check (app.has_permission('coupon.update'));

create policy coupon_customers_read on public.coupon_customers
  for select to authenticated
  using (user_id = auth.uid() or app.has_permission('coupon.view'));

create policy coupon_customers_write on public.coupon_customers
  for all to authenticated
  using (app.has_permission('coupon.update'))
  with check (app.has_permission('coupon.update'));

create policy coupon_redemptions_read on public.coupon_redemptions
  for select to authenticated
  using (user_id = auth.uid() or app.has_permission('coupon.view'));

create policy promotions_public_read on public.promotions
  for select to anon, authenticated
  using (
    (deleted_at is null and is_active and starts_at <= now()
     and (ends_at is null or ends_at > now()))
    or app.has_permission('coupon.view')
  );

create policy promotions_write on public.promotions
  for all to authenticated
  using (app.has_permission('promotion.manage'))
  with check (app.has_permission('promotion.manage'));

-- ═══════════════════════════════════════════════════════════════════════════
-- DELIVERY
-- ═══════════════════════════════════════════════════════════════════════════
create policy delivery_partners_self_read on public.delivery_partners
  for select to authenticated
  using (user_id = auth.uid() or app.has_permission('rider.view', branch_id));

-- A rider may maintain a narrow set of their own profile fields.
create policy delivery_partners_self_update on public.delivery_partners
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy delivery_partners_staff_write on public.delivery_partners
  for all to authenticated
  using (app.has_permission('rider.update', branch_id))
  with check (app.has_permission('rider.create', branch_id) or app.has_permission('rider.update', branch_id));

create policy delivery_partner_documents_self on public.delivery_partner_documents
  for select to authenticated
  using (
    exists (select 1 from public.delivery_partners dp
            where dp.id = delivery_partner_id and dp.user_id = auth.uid())
    or app.has_permission('rider.view')
  );

create policy delivery_partner_documents_self_insert on public.delivery_partner_documents
  for insert to authenticated
  with check (exists (
    select 1 from public.delivery_partners dp
    where dp.id = delivery_partner_id and dp.user_id = auth.uid()
  ));

create policy delivery_partner_documents_review on public.delivery_partner_documents
  for update to authenticated
  using (app.has_permission('rider.approve'))
  with check (app.has_permission('rider.approve'));

create policy delivery_partner_availability_read on public.delivery_partner_availability
  for select to authenticated
  using (
    exists (select 1 from public.delivery_partners dp
            where dp.id = delivery_partner_id and dp.user_id = auth.uid())
    or app.has_permission('rider.view')
  );

create policy delivery_partner_availability_insert on public.delivery_partner_availability
  for insert to authenticated
  with check (exists (
    select 1 from public.delivery_partners dp
    where dp.id = delivery_partner_id and dp.user_id = auth.uid()
  ));

create policy delivery_assignments_read on public.delivery_assignments
  for select to authenticated
  using (
    exists (select 1 from public.delivery_partners dp
            where dp.id = delivery_partner_id and dp.user_id = auth.uid())
    or app.has_permission('delivery.view', branch_id)
    -- The customer sees who is bringing their food. Helper avoids recursing
    -- back into the orders policy, which reads this table.
    or app.owns_order(order_id)
  );

-- Live location: the customer tracking the order, the rider themselves, and
-- staff with tracking rights.
create policy delivery_partner_locations_read on public.delivery_partner_locations
  for select to authenticated
  using (
    exists (select 1 from public.delivery_partners dp
            where dp.id = delivery_partner_id and dp.user_id = auth.uid())
    or app.has_permission('delivery.track')
    or (order_id is not null and app.owns_order(order_id))
  );

create policy delivery_partner_locations_self_write on public.delivery_partner_locations
  for all to authenticated
  using (exists (select 1 from public.delivery_partners dp
                 where dp.id = delivery_partner_id and dp.user_id = auth.uid()))
  with check (exists (select 1 from public.delivery_partners dp
                      where dp.id = delivery_partner_id and dp.user_id = auth.uid()));

create policy delivery_location_events_read on public.delivery_location_events
  for select to authenticated
  using (
    exists (select 1 from public.delivery_partners dp
            where dp.id = delivery_partner_id and dp.user_id = auth.uid())
    or app.has_permission('delivery.track')
  );

create policy delivery_location_events_insert on public.delivery_location_events
  for insert to authenticated
  with check (exists (
    select 1 from public.delivery_partners dp
    where dp.id = delivery_partner_id and dp.user_id = auth.uid()
  ));

create policy delivery_earnings_read on public.delivery_earnings
  for select to authenticated
  using (
    exists (select 1 from public.delivery_partners dp
            where dp.id = delivery_partner_id and dp.user_id = auth.uid())
    or app.has_permission('finance.view')
    or app.has_permission('rider.view')
  );

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTIFICATIONS
-- ═══════════════════════════════════════════════════════════════════════════
create policy notifications_owner_read on public.notifications
  for select to authenticated
  using (user_id = auth.uid() or app.has_permission('notification.send'));

create policy notifications_owner_update on public.notifications
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy notification_templates_read on public.notification_templates
  for select to authenticated using (app.has_permission('notification.template') or app.is_staff());

create policy notification_templates_write on public.notification_templates
  for all to authenticated
  using (app.has_permission('notification.template'))
  with check (app.has_permission('notification.template'));

create policy device_tokens_owner on public.device_tokens
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy notification_campaigns_read on public.notification_campaigns
  for select to authenticated using (app.has_permission('campaign.manage'));

create policy notification_campaigns_write on public.notification_campaigns
  for all to authenticated
  using (app.has_permission('campaign.manage'))
  with check (app.has_permission('campaign.manage'));

create policy campaign_recipients_manage on public.campaign_recipients
  for all to authenticated
  using (app.has_permission('campaign.manage'))
  with check (app.has_permission('campaign.manage'));

-- Verification codes hold OTP hashes. No client ever reads them.
create policy verification_codes_no_client_read on public.verification_codes
  for select to authenticated using (false);

create policy rate_limits_no_client_read on public.rate_limits
  for select to authenticated using (app.has_permission('audit.view'));

-- ═══════════════════════════════════════════════════════════════════════════
-- SUPPORT & REVIEWS
-- ═══════════════════════════════════════════════════════════════════════════
create policy support_tickets_owner_read on public.support_tickets
  for select to authenticated
  using (user_id = auth.uid() or app.has_permission('support.view'));

create policy support_tickets_staff_update on public.support_tickets
  for update to authenticated
  using (app.has_permission('support.respond'))
  with check (app.has_permission('support.respond'));

-- Internal notes stay internal.
create policy support_messages_read on public.support_messages
  for select to authenticated
  using (
    (not is_internal and exists (
      select 1 from public.support_tickets t
      where t.id = ticket_id and t.user_id = auth.uid()
    ))
    or app.has_permission('support.view')
  );

create policy reviews_public_read on public.reviews
  for select to anon, authenticated
  using (status = 'PUBLISHED' or user_id = auth.uid() or app.has_permission('review.view'));

create policy reviews_moderate on public.reviews
  for update to authenticated
  using (app.has_permission('review.moderate'))
  with check (app.has_permission('review.moderate'));

create policy review_items_public_read on public.review_items
  for select to anon, authenticated
  using (exists (
    select 1 from public.reviews r
    where r.id = review_id
      and (r.status = 'PUBLISHED' or r.user_id = auth.uid() or app.has_permission('review.view'))
  ));

-- ═══════════════════════════════════════════════════════════════════════════
-- CMS
-- ═══════════════════════════════════════════════════════════════════════════
create policy cms_sections_public_read on public.cms_sections
  for select to anon, authenticated
  using (deleted_at is null and (is_active or app.has_permission('cms.view')));

create policy cms_sections_write on public.cms_sections
  for all to authenticated
  using (app.has_permission('cms.update'))
  with check (app.has_permission('cms.update'));

create policy cms_banners_public_read on public.cms_banners
  for select to anon, authenticated
  using (deleted_at is null and (is_active or app.has_permission('cms.view')));

create policy cms_banners_write on public.cms_banners
  for all to authenticated
  using (app.has_permission('cms.update'))
  with check (app.has_permission('cms.update'));

create policy cms_documents_public_read on public.cms_documents
  for select to anon, authenticated
  using (is_published or app.has_permission('cms.view'));

create policy cms_documents_write on public.cms_documents
  for all to authenticated
  using (app.has_permission('cms.update'))
  with check (app.has_permission('cms.update'));

create policy cms_faqs_public_read on public.cms_faqs
  for select to anon, authenticated
  using (is_published or app.has_permission('cms.view'));

create policy cms_faqs_write on public.cms_faqs
  for all to authenticated
  using (app.has_permission('cms.update'))
  with check (app.has_permission('cms.update'));

-- ═══════════════════════════════════════════════════════════════════════════
-- LEDGERS — read-only to owners; writes only via ledger functions
-- ═══════════════════════════════════════════════════════════════════════════
create policy wallet_accounts_owner_read on public.wallet_accounts
  for select to authenticated
  using (user_id = auth.uid() or app.has_permission('customer.view'));

create policy wallet_transactions_owner_read on public.wallet_transactions
  for select to authenticated
  using (user_id = auth.uid() or app.has_permission('finance.view') or app.has_permission('customer.view'));

create policy loyalty_accounts_owner_read on public.loyalty_accounts
  for select to authenticated
  using (user_id = auth.uid() or app.has_permission('customer.view'));

create policy loyalty_transactions_owner_read on public.loyalty_transactions
  for select to authenticated
  using (user_id = auth.uid() or app.has_permission('customer.view'));

-- ═══════════════════════════════════════════════════════════════════════════
-- INVENTORY
-- ═══════════════════════════════════════════════════════════════════════════
create policy ingredients_staff on public.ingredients
  for select to authenticated using (app.has_permission('inventory.view'));

create policy ingredients_write on public.ingredients
  for all to authenticated
  using (app.has_permission('inventory.update'))
  with check (app.has_permission('inventory.update'));

create policy inventory_items_staff on public.inventory_items
  for select to authenticated using (app.has_permission('inventory.view', branch_id));

create policy inventory_items_write on public.inventory_items
  for all to authenticated
  using (app.has_permission('inventory.update', branch_id))
  with check (app.has_permission('inventory.update', branch_id));

create policy recipes_staff on public.recipes
  for select to authenticated using (app.has_permission('inventory.view'));

create policy recipes_write on public.recipes
  for all to authenticated
  using (app.has_permission('inventory.update'))
  with check (app.has_permission('inventory.update'));

create policy stock_movements_staff on public.stock_movements
  for select to authenticated using (app.has_permission('inventory.view', branch_id));

create policy stock_movements_insert on public.stock_movements
  for insert to authenticated with check (app.has_permission('inventory.update', branch_id));

create policy purchase_entries_staff on public.purchase_entries
  for all to authenticated
  using (app.has_permission('inventory.view', branch_id))
  with check (app.has_permission('inventory.update', branch_id));

create policy purchase_entry_items_staff on public.purchase_entry_items
  for all to authenticated
  using (exists (
    select 1 from public.purchase_entries pe
    where pe.id = purchase_entry_id and app.has_permission('inventory.view', pe.branch_id)
  ))
  with check (exists (
    select 1 from public.purchase_entries pe
    where pe.id = purchase_entry_id and app.has_permission('inventory.update', pe.branch_id)
  ));

-- ═══════════════════════════════════════════════════════════════════════════
-- AUDIT — readable only with audit.view; never writable from a client
-- ═══════════════════════════════════════════════════════════════════════════
create policy audit_logs_read on public.audit_logs
  for select to authenticated using (app.has_permission('audit.view'));

-- ═══════════════════════════════════════════════════════════════════════════
-- STORAGE POLICIES
-- ═══════════════════════════════════════════════════════════════════════════
-- Public buckets are world-readable through the CDN; writes need permission.
create policy storage_menu_images_write on storage.objects
  for insert to authenticated
  with check (bucket_id = 'menu-images' and app.has_permission('menu.update'));

create policy storage_menu_images_update on storage.objects
  for update to authenticated
  using (bucket_id = 'menu-images' and app.has_permission('menu.update'));

create policy storage_menu_images_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'menu-images' and app.has_permission('menu.delete'));

create policy storage_banners_write on storage.objects
  for insert to authenticated
  with check (bucket_id = 'banners' and app.has_permission('cms.update'));

create policy storage_banners_modify on storage.objects
  for update to authenticated
  using (bucket_id = 'banners' and app.has_permission('cms.update'));

create policy storage_brand_assets_write on storage.objects
  for insert to authenticated
  with check (bucket_id = 'brand-assets' and app.has_permission('cms.update'));

-- Private: staff photos
create policy storage_staff_photos_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'staff-photos'
    and (app.has_permission('staff.view') or owner_id = auth.uid()::text)
  );

create policy storage_staff_photos_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'staff-photos'
    and (app.has_permission('staff.update') or owner_id = auth.uid()::text)
  );

-- Private: rider documents. A rider uploads into their own uid/ prefix.
create policy storage_rider_documents_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'rider-documents'
    and (app.has_permission('rider.view') or (storage.foldername(name))[1] = auth.uid()::text)
  );

create policy storage_rider_documents_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'rider-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or app.has_permission('rider.update')
    )
  );

-- Private: delivery proof photos
create policy storage_delivery_proofs_read on storage.objects
  for select to authenticated
  using (bucket_id = 'delivery-proofs' and (app.has_permission('delivery.view') or owner_id = auth.uid()::text));

create policy storage_delivery_proofs_write on storage.objects
  for insert to authenticated
  with check (bucket_id = 'delivery-proofs' and app.is_rider());

-- Private: support attachments. Customers write into their own uid/ prefix.
create policy storage_support_attachments_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'support-attachments'
    and (app.has_permission('support.view') or (storage.foldername(name))[1] = auth.uid()::text)
  );

create policy storage_support_attachments_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'support-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Private: invoices. Customers read their own; finance reads all.
create policy storage_invoices_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'invoices'
    and (app.has_permission('finance.view') or (storage.foldername(name))[1] = auth.uid()::text)
  );
