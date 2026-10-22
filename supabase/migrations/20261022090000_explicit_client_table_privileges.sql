-- Normalize client table privileges after the schema has finished creating its
-- tables. Supabase defaults can grant broad table access; RLS alone turns a
-- forbidden UPDATE into a successful no-op, which is easy for clients to
-- misread as a saved change. Clear client grants, restore read access, then
-- reapply only the explicitly supported write paths.

alter default privileges for role postgres in schema public
  revoke all on tables from public, anon, authenticated;

revoke all privileges on all tables in schema public
  from public, anon, authenticated;

grant select on all tables in schema public to anon, authenticated;

-- Customer and rider self-service writes guarded by table policies.
grant insert, update, delete on public.addresses to authenticated;
grant insert, update, delete on public.carts to authenticated;
grant insert, update, delete on public.cart_items to authenticated;
grant insert, update, delete on public.cart_item_modifiers to authenticated;
grant insert, update, delete on public.device_tokens to authenticated;
grant insert on public.search_queries to authenticated;
grant update on public.notifications to authenticated;
grant update on public.profiles to authenticated;
grant insert on public.delivery_partner_availability to authenticated;
grant insert, update on public.delivery_partner_locations to authenticated;
grant insert on public.delivery_location_events to authenticated;
-- There is deliberately no rider UPDATE policy; attempts return zero rows.
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

-- Reviews and rider documents are now changed only through audited RPCs.
-- Rider-record RPCs are the only effective write path because RLS has no direct
-- UPDATE policy. Orders, payments, refunds and ledgers are function-only too.
