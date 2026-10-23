begin;
select tap.suite('Settings CRUD and customer sync');

-- Branch managers can manage schedules only inside their outlet. Each write is
-- captured by the generic audit trigger added with this feature.
select tap.as_user(tap.seed('manager'));
insert into public.branch_hours (
  id, branch_id, day_of_week, opens_at, closes_at, day_part
) values (
  '13333333-0000-0000-0000-000000000001',
  '11111111-1111-1111-1111-111111111111', 3, '14:00', '16:00', 'SNACKS'
);
select tap.no_throw(
  'update public.branch_hours set closes_at = ''16:30''
   where id = ''13333333-0000-0000-0000-000000000001''',
  'branch manager can edit this outlet''s trading hours'
);
insert into public.branch_holidays (
  id, branch_id, holiday_on, label, is_closed
) values (
  '13333333-0000-0000-0000-000000000002',
  '11111111-1111-1111-1111-111111111111', '2026-12-25', 'Christmas', true
);
select tap.no_throw(
  'update public.branch_holidays set label = ''Christmas Day''
   where id = ''13333333-0000-0000-0000-000000000002''',
  'branch manager can edit this outlet''s holiday exception'
);
select tap.no_throw(
  'delete from public.branch_hours where id = ''13333333-0000-0000-0000-000000000001''',
  'branch manager can delete a weekly service window'
);
select tap.no_throw(
  'delete from public.branch_holidays where id = ''13333333-0000-0000-0000-000000000002''',
  'branch manager can delete a dated exception'
);

select tap.reset();
select tap.as_user(tap.seed('customer_a'));
select tap.throws(
  $sql$insert into public.branch_holidays (branch_id, holiday_on, label)
       values ('11111111-1111-1111-1111-111111111111', '2026-12-26', 'Blocked')$sql$,
  'PERMISSION_DENIED',
  'a customer cannot create a branch exception'
);
select tap.throws(
  'select public.archive_branch(''11111111-1111-1111-1111-111111111111'')',
  'PERMISSION_DENIED',
  'a customer cannot invoke outlet archival'
);

select tap.reset();
select tap.as_user(tap.seed('support'));
select tap.throws(
  'select public.set_default_tax_category(''22222222-0000-0000-0000-000000000002'')',
  'PERMISSION_DENIED',
  'support cannot change tax configuration'
);

select tap.reset();
select tap.as_user(tap.seed('owner'));
insert into public.tax_categories (
  id, code, name, description, rate, cgst_rate, sgst_rate, igst_rate,
  cess_rate, is_inclusive, is_default
) values (
  '13333333-0000-0000-0000-000000000003', 'GST_TEST', 'Test category',
  'Test only', 0.1200, 0.0600, 0.0600, 0, 0, true, false
);
select tap.no_throw(
  'select public.set_default_tax_category(''13333333-0000-0000-0000-000000000003'')',
  'owner can atomically select the default tax category'
);
select tap.no_throw(
  'select public.archive_tax_category(''22222222-0000-0000-0000-000000000001'')',
  'owner can soft archive the former default after selecting a replacement'
);
select tap.throws(
  'select public.archive_tax_category(''13333333-0000-0000-0000-000000000003'')',
  'DEFAULT_TAX_CATEGORY_CANNOT_BE_ARCHIVED',
  'the active default tax category cannot be archived'
);
select tap.no_throw(
  'update public.feature_flags set rollout_percentage = 25 where key = ''loyalty''',
  'owner can change a feature flag rollout percentage'
);
select tap.eq(
  (select rollout_percentage::numeric from public.feature_flags where key = 'loyalty'),
  25::numeric,
  'feature flag rollout persists'
);
select tap.ok(
  (select deleted_at is not null and not is_active
   from public.tax_categories where id = '22222222-0000-0000-0000-000000000001'),
  'archiving keeps a tax category row for historical references'
);
select tap.reset();
select tap.ok(
  exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'branch_hours')
  and exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'branch_holidays')
  and exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'settings')
  and exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'feature_flags'),
  'customer-visible settings tables publish refresh signals'
);

-- Outlet archive is transactional and preserves all history. Active orders
-- block it; a safe non-default outlet can be archived while one replacement
-- remains, and the final active outlet can never be removed.
insert into public.branches (
  id, code, name, slug, address_line1, city, state, postal_code,
  latitude, longitude, phone, timezone, service_mode, status, status_reason,
  accepting_orders, is_default, is_active, display_order
) values (
  '13333333-0000-0000-0000-000000000004', 'TEST-SET-A', 'Settings Test Outlet',
  'settings-test-outlet', 'Test Road', 'Patna', 'Bihar', '800001',
  25.6100, 85.1400, '+919999999991', 'Asia/Kolkata', 'BOTH', 'CLOSED', 'OTHER',
  false, false, true, 99
);
select tap.as_user(tap.seed('owner'));
select tap.throws(
  'select public.archive_branch(''11111111-1111-1111-1111-111111111111'')',
  'BRANCH_HAS_ACTIVE_ORDERS',
  'an outlet with active orders cannot be archived'
);
select tap.no_throw(
  'select public.archive_branch(''13333333-0000-0000-0000-000000000004'')',
  'owner can soft archive an outlet with no live orders and a replacement'
);
select tap.reset();
select tap.ok(
  (select deleted_at is not null and not is_active and not accepting_orders
   from public.branches where id = '13333333-0000-0000-0000-000000000004'),
  'archived outlet remains in the database but leaves active service'
);

insert into public.branches (
  id, code, name, slug, address_line1, city, state, postal_code,
  latitude, longitude, phone, timezone, service_mode, status, status_reason,
  accepting_orders, is_default, is_active, display_order
) values (
  '13333333-0000-0000-0000-000000000005', 'TEST-SET-B', 'Last Outlet Test',
  'last-outlet-test', 'Test Road', 'Patna', 'Bihar', '800001',
  25.6100, 85.1400, '+919999999992', 'Asia/Kolkata', 'BOTH', 'CLOSED', 'OTHER',
  false, false, true, 100
);
select tap.reset();
update public.branches
set is_active = false
where id = '11111111-1111-1111-1111-111111111111';
select tap.as_user(tap.seed('owner'));
select tap.throws(
  'select public.archive_branch(''13333333-0000-0000-0000-000000000005'')',
  'LAST_ACTIVE_BRANCH',
  'the last active outlet cannot be archived'
);

select tap.reset();
select tap.as_user(tap.seed('owner'));
select tap.ok(
  (select count(*) >= 3 from public.audit_logs where entity_type = 'branch_hours'
    and entity_id = '13333333-0000-0000-0000-000000000001'),
  'create, update and delete schedule changes are audited'
);
select tap.ok(
  exists (select 1 from public.audit_logs where entity_type = 'branch_holiday'
    and entity_id = '13333333-0000-0000-0000-000000000002'),
  'holiday changes are audited'
);

rollback;
