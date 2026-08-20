-- ═══════════════════════════════════════════════════════════════════════════
-- 0022 · GRANTS, RPC EXPOSURE & REALTIME
--
-- Supabase revokes access to new public entities by default. This migration
-- explicitly states what each API role may touch, so the surface is auditable
-- in one place.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Schema usage ──────────────────────────────────────────────────────────
grant usage on schema public to anon, authenticated, service_role;
grant usage on schema extensions to anon, authenticated;
-- `app` stays private: only SECURITY DEFINER functions (owned by postgres) enter it.
grant usage on schema app to service_role;
grant usage on schema analytics to authenticated, service_role;

-- ─── Table privileges ──────────────────────────────────────────────────────
-- SELECT everywhere; RLS decides which rows. Writes are deliberately narrow.
grant select on all tables in schema public to anon, authenticated;
grant all on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;

-- Client-writable tables. Everything else is function-only.
grant insert, update, delete on public.addresses to authenticated;
grant insert, update, delete on public.carts to authenticated;
grant insert, update, delete on public.cart_items to authenticated;
grant insert, update, delete on public.cart_item_modifiers to authenticated;
grant insert, update, delete on public.device_tokens to authenticated;
grant insert on public.search_queries to authenticated;
grant update on public.notifications to authenticated;
grant update on public.profiles to authenticated;
grant insert on public.delivery_partner_documents to authenticated;
grant insert on public.delivery_partner_availability to authenticated;
grant insert, update on public.delivery_partner_locations to authenticated;
grant insert on public.delivery_location_events to authenticated;
grant update on public.delivery_partners to authenticated;

-- Back-office CRUD. RLS still requires the matching permission.
grant insert, update, delete on
  public.categories, public.subcategories, public.products, public.product_images,
  public.product_variants, public.modifier_groups, public.modifiers,
  public.product_modifier_groups, public.product_availability, public.product_schedules,
  public.collections, public.collection_products,
  public.coupons, public.coupon_rules, public.coupon_customers, public.promotions,
  public.cms_sections, public.cms_banners, public.cms_documents, public.cms_faqs,
  public.settings, public.feature_flags, public.branch_hours, public.branch_holidays,
  public.delivery_zones, public.tax_categories, public.cancellation_policies,
  public.refund_policies, public.delivery_payout_config,
  public.notification_templates, public.notification_campaigns, public.campaign_recipients,
  public.staff_members, public.user_roles, public.roles, public.permissions,
  public.role_permissions, public.ingredients, public.inventory_items, public.recipes,
  public.purchase_entries, public.purchase_entry_items
  to authenticated;

grant update on public.branches to authenticated;
grant insert on public.branches to authenticated;
grant insert on public.branch_status_log to authenticated;
grant insert on public.order_notes to authenticated;
grant insert on public.stock_movements to authenticated;
grant update on public.support_tickets to authenticated;
grant update on public.reviews to authenticated;
grant update on public.delivery_partner_documents to authenticated;

-- ─── Function exposure ─────────────────────────────────────────────────────
-- Default: revoke everything in public, then grant per function. Prevents an
-- internal helper from accidentally becoming a public API.
do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
  loop
    execute format('revoke all on function %s from public, anon, authenticated', fn.sig);
    execute format('grant execute on function %s to service_role', fn.sig);
  end loop;

  -- The private `app` schema is never callable by a client.
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app'
  loop
    execute format('revoke all on function %s from public, anon, authenticated', fn.sig);
    execute format('grant execute on function %s to service_role', fn.sig);
  end loop;
end;
$$;

-- ── RLS policy helpers ──
-- Row-level security expressions are evaluated with the *caller's* privileges,
-- so any function named inside a policy must be executable by the roles that
-- policy applies to. Without these grants a plain `select` on orders fails with
-- "permission denied for function app.has_permission".
--
-- Exposing them is safe: each is STABLE, reads only the caller's own grants, and
-- returns strictly less than `public.has_permission`, which is already public.
grant execute on function app.has_permission(text, uuid) to authenticated;
grant execute on function app.has_any_permission(text[], uuid) to authenticated;
grant execute on function app.has_role(public.app_role, uuid) to authenticated;
grant execute on function app.is_staff() to authenticated;
grant execute on function app.is_rider() to authenticated;
grant execute on function app.can_access_branch(uuid) to authenticated;
grant execute on function app.accessible_branch_ids() to authenticated;
grant execute on function app.primary_role() to authenticated;
grant execute on function app.account_is_active() to authenticated;
grant execute on function app.owns_order(uuid) to authenticated;
grant execute on function app.is_rider_for_order(uuid) to authenticated;
grant execute on function app.order_branch(uuid) to authenticated;
grant execute on function app.is_active_status(public.order_status) to anon, authenticated;
grant execute on function app.is_cancelled_status(public.order_status) to anon, authenticated;
grant execute on function app.is_terminal_status(public.order_status) to anon, authenticated;
grant execute on function app.is_service_role() to anon, authenticated;
grant execute on function app.jwt_claim(text) to anon, authenticated;
grant execute on function app.current_user_id() to anon, authenticated;
-- Storage policies call these while resolving object paths.
grant execute on function app.setting(text, jsonb) to anon, authenticated;
grant execute on function app.setting_bool(text, boolean) to anon, authenticated;
grant execute on function app.setting_text(text, text) to anon, authenticated;
grant execute on function app.setting_numeric(text, numeric) to anon, authenticated;
grant execute on function app.setting_int(text, integer) to anon, authenticated;
-- Availability + orderability are read by the public menu views.
grant execute on function app.product_orderable(uuid, uuid, timestamptz) to anon, authenticated;
grant execute on function app.variant_orderable(uuid, timestamptz) to anon, authenticated;
grant execute on function app.modifier_orderable(uuid, timestamptz) to anon, authenticated;
grant execute on function app.product_in_schedule(uuid, uuid, timestamptz) to anon, authenticated;
grant execute on function app.default_branch_id() to anon, authenticated;
grant execute on function app.is_within_trading_hours(uuid, timestamptz) to anon, authenticated;
grant execute on function app.haversine_km(numeric, numeric, numeric, numeric) to anon, authenticated;

-- ── Guest-accessible (menu browsing before sign-in) ──
grant execute on function public.app_config(uuid) to anon, authenticated;
grant execute on function public.home_feed(uuid) to anon, authenticated;
grant execute on function public.menu_catalog(uuid, uuid) to anon, authenticated;
grant execute on function public.product_detail(uuid, text, uuid) to anon, authenticated;
grant execute on function public.search_menu(text, uuid, int) to anon, authenticated;
grant execute on function public.search_suggestions(uuid) to anon, authenticated;
grant execute on function public.branch_ordering_state(uuid) to anon, authenticated;
grant execute on function public.check_serviceability(numeric, numeric, uuid, numeric) to anon, authenticated;
grant execute on function public.feature_enabled(text, uuid) to anon, authenticated;

-- ── Authenticated: identity & profile ──
grant execute on function public.my_session() to authenticated;
grant execute on function public.has_permission(text, uuid) to authenticated;
grant execute on function public.update_my_profile(text, text, date, text, text, boolean, text, boolean, boolean, boolean, boolean) to authenticated;
grant execute on function public.upsert_address(text, text, text, numeric, numeric, uuid, text, text, text, text, text, text, text, text, text, text, text, boolean) to authenticated;
grant execute on function public.delete_address(uuid) to authenticated;
grant execute on function public.refresh_address_serviceability(uuid) to authenticated;

-- ── Authenticated: cart & checkout ──
grant execute on function public.cart_add_item(uuid, uuid, smallint, jsonb, text, uuid, boolean) to authenticated;
grant execute on function public.cart_update_item(uuid, smallint) to authenticated;
grant execute on function public.cart_remove_item(uuid) to authenticated;
grant execute on function public.cart_clear(uuid) to authenticated;
grant execute on function public.cart_set_options(uuid, public.fulfilment_type, uuid, public.order_timing, timestamptz, text, text, boolean, boolean) to authenticated;
grant execute on function public.calculate_checkout(uuid, uuid, public.payment_mode, numeric, int) to authenticated;
grant execute on function public.apply_coupon(text, uuid, uuid) to authenticated;
grant execute on function public.remove_coupon(uuid) to authenticated;
grant execute on function public.available_coupons(uuid) to authenticated;

-- ── Authenticated: orders ──
grant execute on function public.order_detail(uuid) to authenticated;
grant execute on function public.my_orders(text, int, int) to authenticated;
grant execute on function public.reorder(uuid) to authenticated;
grant execute on function public.cancel_order(uuid, public.cancellation_reason, text) to authenticated;
grant execute on function public.cancellation_options(uuid) to authenticated;
grant execute on function public.submit_review(uuid, smallint, smallint, smallint, text, text[], jsonb) to authenticated;
grant execute on function public.refund_eligibility(uuid) to authenticated;
grant execute on function public.request_order_help(uuid, public.ticket_category, text, uuid[]) to authenticated;

-- ── Authenticated: wallet, notifications, support ──
grant execute on function public.my_wallet() to authenticated;
grant execute on function public.mark_notifications_read(uuid[]) to authenticated;
grant execute on function public.register_device_token(text, public.device_platform, text, text, text, text, text, text) to authenticated;
grant execute on function public.unregister_device_token(text) to authenticated;
grant execute on function public.create_support_ticket(public.ticket_category, text, text, uuid, jsonb) to authenticated;
grant execute on function public.post_support_message(uuid, text, boolean, jsonb) to authenticated;

-- ── Kitchen / operations (permission checked inside each function) ──
grant execute on function public.kitchen_queue(uuid) to authenticated;
grant execute on function public.kitchen_availability(uuid) to authenticated;
grant execute on function public.live_operations(uuid) to authenticated;
grant execute on function public.accept_order(uuid, int) to authenticated;
grant execute on function public.reject_order(uuid, public.cancellation_reason, text) to authenticated;
grant execute on function public.start_preparing(uuid) to authenticated;
grant execute on function public.mark_order_ready(uuid) to authenticated;
grant execute on function public.cancel_order_item(uuid, text) to authenticated;
grant execute on function public.set_product_availability(uuid, public.availability_state, uuid, int, text, int) to authenticated;
grant execute on function public.set_products_availability(uuid[], public.availability_state, uuid, int, text) to authenticated;
grant execute on function public.set_branch_status(public.branch_status, public.branch_closure_reason, text, uuid, int) to authenticated;

-- ── Delivery ──
grant execute on function public.set_duty_state(public.rider_duty_state, numeric, numeric, smallint, text) to authenticated;
grant execute on function public.my_deliveries(boolean) to authenticated;
grant execute on function public.my_earnings(date, date) to authenticated;
grant execute on function public.respond_to_assignment(uuid, boolean, text) to authenticated;
grant execute on function public.rider_arrived_at_store(uuid) to authenticated;
grant execute on function public.verify_pickup(uuid, text) to authenticated;
grant execute on function public.rider_arrived_at_customer(uuid) to authenticated;
grant execute on function public.complete_delivery(uuid, text, numeric, text, text, boolean) to authenticated;
grant execute on function public.fail_delivery(uuid, text, text) to authenticated;
grant execute on function public.publish_rider_location(numeric, numeric, numeric, numeric, numeric, smallint, boolean) to authenticated;
grant execute on function public.available_riders(uuid, uuid) to authenticated;
grant execute on function public.assign_rider(uuid, uuid, public.assignment_mode, int) to authenticated;
grant execute on function public.settle_cod(uuid, uuid[], text) to authenticated;

-- ── Back office ──
grant execute on function public.customer_detail(uuid) to authenticated;
grant execute on function public.request_refund(uuid, public.refund_kind, public.refund_reason, numeric, public.refund_destination, text, jsonb, text, uuid) to authenticated;
grant execute on function public.approve_refund(uuid, text) to authenticated;
grant execute on function public.reject_refund(uuid, text) to authenticated;
grant execute on function public.audit_trail(text, text, uuid, public.audit_action, timestamptz, timestamptz, int, int) to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- REALTIME
-- Only tables a client legitimately needs to watch. RLS still filters rows on
-- every broadcast, so a customer receives events for their own orders only.
-- ═══════════════════════════════════════════════════════════════════════════
alter publication supabase_realtime add table public.orders;
alter publication supabase_realtime add table public.order_status_history;
alter publication supabase_realtime add table public.order_items;
alter publication supabase_realtime add table public.product_availability;
alter publication supabase_realtime add table public.delivery_assignments;
alter publication supabase_realtime add table public.delivery_partner_locations;
alter publication supabase_realtime add table public.delivery_partners;
alter publication supabase_realtime add table public.branches;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.support_messages;
alter publication supabase_realtime add table public.support_tickets;

-- REPLICA IDENTITY FULL makes old-row values available to RLS on UPDATE/DELETE,
-- which Realtime needs in order to authorise the change event.
alter table public.orders replica identity full;
alter table public.order_status_history replica identity full;
alter table public.product_availability replica identity full;
alter table public.delivery_assignments replica identity full;
alter table public.delivery_partner_locations replica identity full;
alter table public.notifications replica identity full;
alter table public.support_messages replica identity full;

comment on table public.delivery_partner_locations is
  'Single mutable row per rider, published over Realtime. RLS restricts each customer to their own active order.';
