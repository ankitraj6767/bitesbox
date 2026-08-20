-- Keep the RLS helper grants explicit on hosted projects. These functions are
-- referenced by public table policies and must be executable by the policy
-- caller, while the helpers themselves continue to enforce auth.uid()-scoped
-- permissions.

grant execute on function app.has_permission(text, uuid) to anon, authenticated;
grant execute on function app.has_any_permission(text[], uuid) to anon, authenticated;
grant execute on function app.has_role(public.app_role, uuid) to anon, authenticated;
grant execute on function app.is_staff() to anon, authenticated;
grant execute on function app.is_rider() to anon, authenticated;
grant execute on function app.can_access_branch(uuid) to anon, authenticated;
grant execute on function app.accessible_branch_ids() to anon, authenticated;
grant execute on function app.primary_role() to anon, authenticated;
grant execute on function app.account_is_active() to anon, authenticated;
grant execute on function app.owns_order(uuid) to anon, authenticated;
grant execute on function app.is_rider_for_order(uuid) to authenticated;
grant execute on function app.order_branch(uuid) to authenticated;

grant execute on function app.is_active_status(public.order_status) to anon, authenticated;
grant execute on function app.is_cancelled_status(public.order_status) to anon, authenticated;
grant execute on function app.is_terminal_status(public.order_status) to anon, authenticated;
grant execute on function app.is_service_role() to anon, authenticated;
grant execute on function app.jwt_claim(text) to anon, authenticated;
grant execute on function app.current_user_id() to anon, authenticated;

grant execute on function app.setting(text, jsonb) to anon, authenticated;
grant execute on function app.setting_bool(text, boolean) to anon, authenticated;
grant execute on function app.setting_text(text, text) to anon, authenticated;
grant execute on function app.setting_numeric(text, numeric) to anon, authenticated;
grant execute on function app.setting_int(text, integer) to anon, authenticated;

grant execute on function app.product_orderable(uuid, uuid, timestamptz) to anon, authenticated;
grant execute on function app.variant_orderable(uuid, timestamptz) to anon, authenticated;
grant execute on function app.modifier_orderable(uuid, timestamptz) to anon, authenticated;
grant execute on function app.product_in_schedule(uuid, uuid, timestamptz) to anon, authenticated;
grant execute on function app.default_branch_id() to anon, authenticated;
grant execute on function app.is_within_trading_hours(uuid, timestamptz) to anon, authenticated;
grant execute on function app.haversine_km(numeric, numeric, numeric, numeric) to anon, authenticated;
