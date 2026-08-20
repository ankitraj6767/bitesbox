-- ═══════════════════════════════════════════════════════════════════════════
-- READ SURFACES — SMOKE
--
-- Why this suite exists.
--
-- `supabase db lint` reported two functions at *error* level, and both turned out
-- to throw on every call:
--
--   public.search_suggestions  42803  "p.order_count" must appear in the GROUP BY
--   public.svc_audit           42804  actor_kind is enum, expression is text
--
-- `search_suggestions` is called by the customer search screen, so search was
-- broken for every user including guests. Neither function was touched by any of
-- the eight behavioural suites, and a plpgsql body is only parsed when it runs — so
-- a query that cannot possibly execute still installs cleanly through
-- `supabase db reset` without a murmur.
--
-- The other suites test *behaviour*: that the right person can do the right thing
-- and nobody else can. This one tests something duller and, it turns out, equally
-- necessary: that every read surface a client can call actually executes. It makes
-- no claim about what the answers mean.
--
-- Every function is called as a role that is allowed to call it, with arguments a
-- real client would send.
-- ═══════════════════════════════════════════════════════════════════════════
begin;

select tap.suite('Read surfaces (smoke)');

select tap.reset();

select tap.remember('delivered', tap.seed_order(1)::text);
select tap.remember('ready',     tap.seed_order(5)::text);
select tap.remember('product',   '55555555-0000-0000-0000-000000000052');

select tap.remember(
  'ticket',
  (select id::text from public.support_tickets order by created_at limit 1)
);

-- ─── Guest ──────────────────────────────────────────────────────────────────
-- A guest browses before signing in. Every one of these runs with no JWT at all,
-- which is also the case that the `anon` grants on the RLS helpers were added for.
select tap.note('as a guest');

select tap.as_anon();

select tap.no_throw('select public.app_config()', 'app_config');
select tap.no_throw('select public.home_feed()', 'home_feed');
select tap.no_throw('select public.menu_catalog()', 'menu_catalog');
select tap.no_throw(
  format('select public.product_detail(%L)', tap.recall_uuid('product')),
  'product_detail'
);
-- This is the one that was broken.
select tap.no_throw('select public.search_suggestions()', 'search_suggestions');
-- Also broken: invoker-rights, so it could not name the `app` schema.
select tap.no_throw('select public.branch_ordering_state()', 'branch_ordering_state');
select tap.no_throw('select public.check_serviceability(25.4612, 85.5238)', 'check_serviceability');

-- `my_session` is authenticated-only and deliberately not granted to `anon`. Both
-- clients guard on having a session before calling it
-- (auth_repository.loadSession returns AppSession.guest() first), so this asserts
-- the boundary rather than treating it as a gap.
select tap.throws(
  'select public.my_session()',
  'PERMISSION_DENIED',
  'a guest cannot load a session'
);

-- "Is the restaurant open?" gates the whole ordering flow, so an answer that is
-- merely non-throwing is not enough — the shape has to be usable.
select tap.ok(
  (select (public.branch_ordering_state() ->> 'accepting_orders') is not null),
  'branch_ordering_state answers whether orders are being taken'
);

select tap.ok(
  (select (public.branch_ordering_state() ->> 'branch_id') is not null),
  'and names the branch it answered for'
);

-- `has_permission` is authenticated-only, like `my_session`. A guest holds nothing,
-- so there is no question for it to answer. Suite 010 asserts that it reports on
-- the caller rather than on the owner it now runs as.
select tap.throws(
  'select public.has_permission(''order.accept'')',
  'PERMISSION_DENIED',
  'a guest cannot ask about permissions'
);

-- The shape matters as much as the absence of an exception: a screen that renders
-- three empty lists is indistinguishable from a broken one.
select tap.ok(
  (select jsonb_typeof(public.search_suggestions() -> 'popular_products') = 'array'),
  'search_suggestions returns a popular_products array'
);

select tap.ok(
  (select jsonb_array_length(public.search_suggestions() -> 'popular_products') > 0),
  'popular products are actually populated'
);

-- Ordering is the point of "popular", so a change that drops the sort must fail.
select tap.ok(
  (
    with ranked as (
      select
        (item ->> 'id')::uuid as id,
        row_number() over () as position
      from jsonb_array_elements(public.search_suggestions() -> 'popular_products') as item
    )
    select bool_and(a.order_count >= b.order_count)
    from ranked ra
    join ranked rb on rb.position = ra.position + 1
    join public.products a on a.id = ra.id
    join public.products b on b.id = rb.id
  ),
  'popular products come back most-ordered first'
);

select tap.reset();

-- ─── Customer ───────────────────────────────────────────────────────────────
select tap.note('as a customer');

select tap.as_user(tap.seed('customer_a'));

select tap.no_throw('select public.my_session()', 'my_session');
select tap.no_throw('select public.my_orders()', 'my_orders');
select tap.no_throw('select public.my_wallet()', 'my_wallet');
select tap.no_throw('select public.available_coupons()', 'available_coupons');
select tap.no_throw('select public.calculate_checkout()', 'calculate_checkout');
select tap.no_throw('select public.search_suggestions()', 'search_suggestions with a session');
select tap.no_throw(
  format('select public.order_detail(%L)', tap.recall_uuid('delivered')),
  'order_detail'
);
select tap.no_throw(
  format('select public.order_invoice(%L)', tap.recall_uuid('delivered')),
  'order_invoice'
);
select tap.no_throw(
  format('select public.cancellation_options(%L)', tap.recall_uuid('delivered')),
  'cancellation_options'
);
select tap.no_throw(
  format('select public.refund_eligibility(%L)', tap.recall_uuid('delivered')),
  'refund_eligibility'
);
select tap.no_throw('select public.feature_enabled(''wallet'')', 'feature_enabled');

-- `recent` is the only branch of search_suggestions that depends on a session, so
-- it must differ from the guest answer in shape, not just in content.
select tap.ok(
  (select jsonb_typeof(public.search_suggestions() -> 'recent') = 'array'),
  'a signed-in customer gets a recent-searches array'
);

select tap.reset();

-- ─── Kitchen ────────────────────────────────────────────────────────────────
select tap.note('as kitchen staff');

select tap.as_user(tap.seed('kitchen'));

select tap.no_throw('select public.kitchen_queue()', 'kitchen_queue');
select tap.no_throw('select public.kitchen_availability()', 'kitchen_availability');

select tap.reset();

-- ─── Rider ──────────────────────────────────────────────────────────────────
-- A rider holds no permissions at all, so these read surfaces are the whole of
-- what the delivery shell can see.
select tap.note('as a rider');

select tap.as_user(tap.seed('rider_rahul'));

select tap.no_throw('select public.my_deliveries()', 'my_deliveries');
select tap.no_throw('select public.my_deliveries(true)', 'my_deliveries with history');
select tap.no_throw('select public.my_earnings()', 'my_earnings');
select tap.no_throw('select public.my_rider_onboarding()', 'my_rider_onboarding');
select tap.no_throw('select public.my_session()', 'my_session');

select tap.reset();

-- ─── Operations ─────────────────────────────────────────────────────────────
select tap.note('as operations');

select tap.as_user(tap.seed('operations'));

select tap.no_throw('select public.live_operations()', 'live_operations');
select tap.no_throw('select * from public.available_riders()', 'available_riders');
select tap.no_throw('select public.rider_directory()', 'rider_directory');
select tap.no_throw(
  format('select public.rider_onboarding(%L)', tap.seed('dp_rahul')),
  'rider_onboarding'
);
select tap.no_throw('select public.admin_orders()', 'admin_orders');
select tap.no_throw(
  format('select public.admin_orders(null, null, array[''PREPARING'']::public.order_status[])'),
  'admin_orders filtered by status'
);

select tap.reset();

-- ─── Manager ────────────────────────────────────────────────────────────────
select tap.note('as a manager');

select tap.as_user(tap.seed('manager'));

select tap.no_throw('select public.dashboard_overview()', 'dashboard_overview');
select tap.no_throw('select public.dashboard_charts()', 'dashboard_charts');
select tap.no_throw('select public.staff_directory()', 'staff_directory');
select tap.no_throw('select public.admin_customers()', 'admin_customers');
select tap.no_throw(
  format('select public.customer_detail(%L)', tap.seed('customer_a')),
  'customer_detail'
);
select tap.no_throw('select public.admin_support_inbox()', 'admin_support_inbox');

select tap.no_throw(
  format('select public.support_ticket_detail(%L)', tap.recall_uuid('ticket')),
  'support_ticket_detail'
);

-- A manager runs an outlet; reading the audit trail is a different kind of
-- authority and sits with `audit.view`, which they do not hold.
select tap.throws(
  'select public.audit_trail()',
  'PERMISSION_DENIED',
  'a manager cannot read the audit trail'
);

select tap.reset();

-- ─── Owner ──────────────────────────────────────────────────────────────────
select tap.note('as the owner');

select tap.as_user(tap.seed('owner'));

select tap.no_throw('select public.audit_trail()', 'audit_trail');
select tap.no_throw(
  'select public.audit_trail(null, null, null, null, now() - interval ''7 days'', now())',
  'audit_trail over an explicit window'
);

select tap.reset();

-- ─── Finance ────────────────────────────────────────────────────────────────
-- The report surfaces are the least-exercised code in the schema and the most
-- likely to carry an aggregate mistake exactly like the one this suite was written
-- for.
select tap.note('as finance');

select tap.as_user(tap.seed('finance'));

select tap.no_throw('select public.report_sales()', 'report_sales');
select tap.no_throw('select public.report_products()', 'report_products');
select tap.no_throw('select public.report_customers()', 'report_customers');
select tap.no_throw('select public.report_payments()', 'report_payments');
select tap.no_throw('select public.report_tax_summary()', 'report_tax_summary');
select tap.no_throw('select public.admin_refund_queue()', 'admin_refund_queue');

-- An explicit window, since a null range and a real one take different paths.
select tap.no_throw(
  'select public.report_sales(null, now() - interval ''30 days'', now())',
  'report_sales over an explicit window'
);

select tap.no_throw(
  'select public.dashboard_charts(null, now() - interval ''7 days'', now(), ''day'')',
  'dashboard_charts by day'
);

select tap.reset();

-- ─── Marketing ──────────────────────────────────────────────────────────────
select tap.note('as marketing');

select tap.as_user(tap.seed('marketing'));

select tap.no_throw(
  (
    select format('select public.campaign_audience_size(%L)', c.id)
    from public.notification_campaigns c
    order by c.created_at
    limit 1
  ),
  'campaign_audience_size'
);

select tap.reset();

-- ─── Service role ───────────────────────────────────────────────────────────
-- svc_audit was the second broken function. It is how an Edge Function attributes
-- a write to the human who asked for it, so a failure here means the audit trail
-- for every service-role action is unreachable.
select tap.note('as the service role');

select tap.as_service();

select tap.no_throw(
  'select public.svc_audit(''UPDATE'', ''smoke'', ''system-actor'')',
  'svc_audit with no actor'
);

select tap.no_throw(
  format(
    'select public.svc_audit(''UPDATE'', ''smoke'', ''human-actor'', null, null, null, null, null, %L)',
    tap.seed('manager')
  ),
  'svc_audit attributed to a human'
);

select tap.reset();

-- Attribution is the entire reason the function exists, so assert it rather than
-- just that it did not throw.
select tap.eq(
  (select actor_kind::text from public.audit_logs
    where entity_type = 'smoke' and entity_id = 'system-actor'),
  'SYSTEM',
  'an unattributed service write is recorded as SYSTEM'
);

select tap.eq(
  (select actor_kind::text from public.audit_logs
    where entity_type = 'smoke' and entity_id = 'human-actor'),
  'USER',
  'an attributed service write is recorded as USER'
);

select tap.eq(
  (select actor_role::text from public.audit_logs
    where entity_type = 'smoke' and entity_id = 'human-actor'),
  'MANAGER',
  'the actor''s role is resolved and stored'
);

select tap.ok(
  (select actor_name is not null from public.audit_logs
    where entity_type = 'smoke' and entity_id = 'human-actor'),
  'the actor''s name is resolved at write time, so it survives their deletion'
);

-- ─── A client cannot reach the service API ──────────────────────────────────
select tap.as_user(tap.seed('manager'));

select tap.throws(
  'select public.svc_audit(''UPDATE'', ''smoke'', ''forged'')',
  'PERMISSION_DENIED',
  'even a manager cannot write an audit entry through the service API'
);

select tap.reset();

select tap.done('Read surfaces (smoke)');

rollback;
