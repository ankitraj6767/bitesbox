-- SEED 40 · USERS, STAFF, RIDERS & ADDRESSES

-- Run as the service role so the seed can drive the real business functions.
select set_config('request.jwt.claims', '{"role":"service_role"}', false);

-- ═══════════════════════════════════════════════════════════════════════════
-- USERS
--
-- The seed runs as the service role so it can exercise the real business
-- functions (app.place_order, app.transition_order, complete_delivery …) rather
-- than hand-writing order rows. This is what keeps the seed honest: if the
-- pricing engine or state machine breaks, `supabase db reset` fails loudly.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Owner & back office ──
select app.seed_user('90000000-0000-0000-0000-000000000001', '9431100001', 'owner@bitesbox.in',      'Ankit Raj');
select app.seed_user('90000000-0000-0000-0000-000000000002', '9431100002', 'manager@bitesbox.in',    'Sunita Kumari');
select app.seed_user('90000000-0000-0000-0000-000000000003', '9431100003', 'operations@bitesbox.in', 'Rakesh Prasad');
select app.seed_user('90000000-0000-0000-0000-000000000004', '9431100004', 'finance@bitesbox.in',    'Neha Sinha');
select app.seed_user('90000000-0000-0000-0000-000000000005', '9431100005', 'support@bitesbox.in',    'Imran Ali');
select app.seed_user('90000000-0000-0000-0000-000000000006', '9431100006', 'marketing@bitesbox.in',  'Priya Verma');

select app.seed_grant_role('90000000-0000-0000-0000-000000000001', 'OWNER');
select app.seed_grant_role('90000000-0000-0000-0000-000000000002', 'MANAGER');
select app.seed_grant_role('90000000-0000-0000-0000-000000000003', 'OPERATIONS');
select app.seed_grant_role('90000000-0000-0000-0000-000000000004', 'FINANCE');
select app.seed_grant_role('90000000-0000-0000-0000-000000000005', 'SUPPORT');
select app.seed_grant_role('90000000-0000-0000-0000-000000000006', 'MARKETING');

-- ── Kitchen staff (mobile kitchen shell) ──
select app.seed_user('90000000-0000-0000-0000-000000000201', '9900000201', 'kitchen1@bitesbox.in', 'Ramesh Thakur');
select app.seed_user('90000000-0000-0000-0000-000000000202', '9900000202', 'kitchen2@bitesbox.in', 'Dinesh Paswan');

select app.seed_grant_role('90000000-0000-0000-0000-000000000201', 'KITCHEN_STAFF');
select app.seed_grant_role('90000000-0000-0000-0000-000000000202', 'KITCHEN_STAFF');

-- Manager also signs in to the kitchen tablet.
select app.seed_user('90000000-0000-0000-0000-000000000301', '9900000301', 'headchef@bitesbox.in', 'Mohammad Sabir');
select app.seed_grant_role('90000000-0000-0000-0000-000000000301', 'MANAGER');
select app.seed_grant_role('90000000-0000-0000-0000-000000000301', 'KITCHEN_STAFF', '11111111-1111-1111-1111-111111111111', false);

insert into public.staff_members (
  user_id, branch_id, employee_code, designation, department, joined_on, shift_start, shift_end
) values
  ('90000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'BB-EMP-001', 'Branch Manager',   'Operations', '2025-06-01', '09:00', '22:00'),
  ('90000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'BB-EMP-002', 'Operations Lead',  'Operations', '2025-07-15', '11:00', '23:00'),
  ('90000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'BB-EMP-003', 'Finance Executive','Finance',    '2025-08-01', '10:00', '19:00'),
  ('90000000-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'BB-EMP-004', 'Support Agent',    'Support',    '2025-09-10', '09:00', '18:00'),
  ('90000000-0000-0000-0000-000000000006', '11111111-1111-1111-1111-111111111111', 'BB-EMP-005', 'Marketing Executive','Marketing','2025-10-05', '10:00', '19:00'),
  ('90000000-0000-0000-0000-000000000201', '11111111-1111-1111-1111-111111111111', 'BB-EMP-006', 'Kitchen Staff',    'Kitchen',    '2025-06-15', '08:00', '17:00'),
  ('90000000-0000-0000-0000-000000000202', '11111111-1111-1111-1111-111111111111', 'BB-EMP-007', 'Kitchen Staff',    'Kitchen',    '2025-06-15', '15:00', '23:30'),
  ('90000000-0000-0000-0000-000000000301', '11111111-1111-1111-1111-111111111111', 'BB-EMP-008', 'Head Chef',        'Kitchen',    '2025-05-20', '09:00', '23:00');

-- ── Delivery partners ──
select app.seed_user('90000000-0000-0000-0000-000000000101', '9900000101', 'rahul.rider@bitesbox.in', 'Rahul Kumar');
select app.seed_user('90000000-0000-0000-0000-000000000102', '9900000102', 'amit.rider@bitesbox.in',  'Amit Sharma');
select app.seed_user('90000000-0000-0000-0000-000000000103', '9900000103', 'rohit.rider@bitesbox.in', 'Rohit Yadav');
select app.seed_user('90000000-0000-0000-0000-000000000104', '9900000104', 'suraj.rider@bitesbox.in', 'Suraj Mahto');

select app.seed_grant_role('90000000-0000-0000-0000-000000000101', 'DELIVERY_PARTNER');
select app.seed_grant_role('90000000-0000-0000-0000-000000000102', 'DELIVERY_PARTNER');
select app.seed_grant_role('90000000-0000-0000-0000-000000000103', 'DELIVERY_PARTNER');
select app.seed_grant_role('90000000-0000-0000-0000-000000000104', 'DELIVERY_PARTNER');

insert into public.delivery_partners (
  id, user_id, branch_id, partner_code, full_name, phone, email, photo_path,
  address_line1, city, state, postal_code,
  vehicle_type, vehicle_number, driving_licence_no, licence_expiry,
  bank_account_masked, bank_ifsc, bank_holder_name, upi_id,
  emergency_contact_name, emergency_contact_phone,
  onboarding_status, duty_state, is_salaried, approved_by, approved_at,
  max_concurrent_orders, total_deliveries, successful_deliveries, rating_average, rating_count
) values
  ('a1000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000101',
   '11111111-1111-1111-1111-111111111111', 'BB-DP-001', 'Rahul Kumar', '+919900000101',
   'rahul.rider@bitesbox.in', 'staff-photos/riders/rahul.jpg',
   'Ward 6, Station Road', 'Bakhtiyarpur', 'Bihar', '803212',
   'MOTORCYCLE', 'BR01AB1234', 'BR0120210001234', '2029-08-14',
   'XXXXXX4521', 'SBIN0001234', 'Rahul Kumar', 'rahulkumar@upi',
   'Sita Devi', '+919431100901',
   'ACTIVE', 'AVAILABLE', true, '90000000-0000-0000-0000-000000000002', now() - interval '60 days',
   2, 184, 179, 4.72, 96),

  ('a1000000-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000102',
   '11111111-1111-1111-1111-111111111111', 'BB-DP-002', 'Amit Sharma', '+919900000102',
   'amit.rider@bitesbox.in', 'staff-photos/riders/amit.jpg',
   'Ward 9, Athmalgola Road', 'Bakhtiyarpur', 'Bihar', '803212',
   'SCOOTER', 'BR01CD5678', 'BR0120200005678', '2028-11-30',
   'XXXXXX8834', 'PUNB0123456', 'Amit Sharma', 'amitsharma@upi',
   'Rekha Sharma', '+919431100902',
   'ACTIVE', 'AVAILABLE', true, '90000000-0000-0000-0000-000000000002', now() - interval '45 days',
   2, 142, 138, 4.61, 78),

  ('a1000000-0000-0000-0000-000000000003', '90000000-0000-0000-0000-000000000103',
   '11111111-1111-1111-1111-111111111111', 'BB-DP-003', 'Rohit Yadav', '+919900000103',
   'rohit.rider@bitesbox.in', 'staff-photos/riders/rohit.jpg',
   'Karauta Village', 'Bakhtiyarpur', 'Bihar', '803212',
   'MOTORCYCLE', 'BR01EF9012', 'BR0120220009012', '2030-02-28',
   'XXXXXX2210', 'HDFC0000123', 'Rohit Yadav', 'rohityadav@upi',
   'Manoj Yadav', '+919431100903',
   'ACTIVE', 'OFFLINE', true, '90000000-0000-0000-0000-000000000002', now() - interval '20 days',
   3, 67, 65, 4.85, 41),

  -- Awaiting approval: exercises the onboarding gate in the rider app.
  ('a1000000-0000-0000-0000-000000000004', '90000000-0000-0000-0000-000000000104',
   '11111111-1111-1111-1111-111111111111', 'BB-DP-004', 'Suraj Mahto', '+919900000104',
   'suraj.rider@bitesbox.in', null,
   'Sabalpur', 'Bakhtiyarpur', 'Bihar', '803212',
   'BICYCLE', null, 'BR0120240001111', '2031-01-15',
   null, null, null, null,
   'Kamla Devi', '+919431100904',
   'DOCUMENTS_SUBMITTED', 'OFFLINE', true, null, null,
   1, 0, 0, 0, 0);

insert into public.delivery_partner_documents (
  delivery_partner_id, document_type, storage_path, document_number,
  issued_on, expires_on, status, reviewed_by, reviewed_at
) values
-- Paths follow the `{user_id}/{document_type}` convention the rider-documents
-- storage policy enforces (`foldername(name)[1] = auth.uid()`) and that
-- `submit_rider_document` validates. A path shaped any other way would be
-- unreadable by the rider who owns it and would be refused on submission, so the
-- seed uses the real shape rather than a decorative one.
  ('a1000000-0000-0000-0000-000000000001', 'DRIVING_LICENCE', '90000000-0000-0000-0000-000000000101/driving_licence.jpg', 'BR0120210001234', '2021-08-15', '2029-08-14', 'APPROVED', '90000000-0000-0000-0000-000000000002', now() - interval '60 days'),
  ('a1000000-0000-0000-0000-000000000001', 'AADHAAR',         '90000000-0000-0000-0000-000000000101/aadhaar.jpg', 'XXXX-XXXX-4521', null, null, 'APPROVED', '90000000-0000-0000-0000-000000000002', now() - interval '60 days'),
  ('a1000000-0000-0000-0000-000000000001', 'VEHICLE_RC',      '90000000-0000-0000-0000-000000000101/vehicle_rc.jpg', 'BR01AB1234',     '2021-07-01', '2036-06-30', 'APPROVED', '90000000-0000-0000-0000-000000000002', now() - interval '60 days'),
  ('a1000000-0000-0000-0000-000000000002', 'DRIVING_LICENCE', '90000000-0000-0000-0000-000000000102/driving_licence.jpg', 'BR0120200005678', '2020-12-01', '2028-11-30', 'APPROVED', '90000000-0000-0000-0000-000000000002', now() - interval '45 days'),
  ('a1000000-0000-0000-0000-000000000002', 'AADHAAR',         '90000000-0000-0000-0000-000000000102/aadhaar.jpg', 'XXXX-XXXX-8834', null, null, 'APPROVED', '90000000-0000-0000-0000-000000000002', now() - interval '45 days'),
  ('a1000000-0000-0000-0000-000000000003', 'DRIVING_LICENCE', '90000000-0000-0000-0000-000000000103/driving_licence.jpg', 'BR0120220009012', '2022-03-01', '2030-02-28', 'APPROVED', '90000000-0000-0000-0000-000000000002', now() - interval '20 days'),
  ('a1000000-0000-0000-0000-000000000004', 'DRIVING_LICENCE', '90000000-0000-0000-0000-000000000104/driving_licence.jpg', 'BR0120240001111', '2024-01-16', '2031-01-15', 'PENDING', null, null),
  ('a1000000-0000-0000-0000-000000000004', 'AADHAAR',         '90000000-0000-0000-0000-000000000104/aadhaar.jpg', 'XXXX-XXXX-7766', null, null, 'PENDING', null, null);

-- Live positions near the outlet so dispatch ranking has real data.
insert into public.delivery_partner_locations (
  delivery_partner_id, latitude, longitude, accuracy_meters, battery_level, is_moving, recorded_at
) values
  ('a1000000-0000-0000-0000-000000000001', 25.4615000, 85.5241000, 12, 78, false, now() - interval '40 seconds'),
  ('a1000000-0000-0000-0000-000000000002', 25.4589000, 85.5198000, 18, 54, true,  now() - interval '25 seconds');

-- ── Customers ──
select app.seed_user('91000000-0000-0000-0000-000000000001', '9900000001', 'aarav.customer@example.com',  'Aarav Kumar');
select app.seed_user('91000000-0000-0000-0000-000000000002', '9900000002', 'diya.customer@example.com',   'Diya Singh');
select app.seed_user('91000000-0000-0000-0000-000000000003', '9900000003', 'vivaan.customer@example.com', 'Vivaan Gupta');
select app.seed_user('91000000-0000-0000-0000-000000000004', '9900000004', 'ananya.customer@example.com', 'Ananya Mishra');
select app.seed_user('91000000-0000-0000-0000-000000000005', '9900000005', 'kabir.customer@example.com',  'Kabir Anand');

update public.profiles
set marketing_opt_in = true, onboarding_completed = true, profile_completed_at = now()
where id::text like '91000000%';

-- ── Customer addresses (real Bakhtiyarpur geography, varying distances) ──
insert into public.addresses (
  id, user_id, label, contact_name, contact_phone,
  address_line1, address_line2, landmark, area, city, state, postal_code,
  latitude, longitude, formatted_address, location_source,
  delivery_instructions, is_default
) values
  -- ~0.4 km — Zone A
  ('b1000000-0000-0000-0000-000000000001', '91000000-0000-0000-0000-000000000001',
   'HOME', 'Aarav Kumar', '+919900000001',
   'House 24, Gandhi Path', 'Ward 8', 'Behind Bakhtiyarpur Post Office', 'Station Area',
   'Bakhtiyarpur', 'Bihar', '803212',
   25.4632000, 85.5252000, 'House 24, Gandhi Path, Bakhtiyarpur, Bihar 803212', 'GPS',
   'Second floor, green gate. Please call on arrival.', true),

  -- ~1.9 km — Zone A
  ('b1000000-0000-0000-0000-000000000002', '91000000-0000-0000-0000-000000000002',
   'HOME', 'Diya Singh', '+919900000002',
   'Flat 3B, Shanti Apartments', 'Main Bazaar Road', 'Near Durga Mandir', 'Main Bazaar',
   'Bakhtiyarpur', 'Bihar', '803212',
   25.4761000, 85.5299000, 'Shanti Apartments, Main Bazaar, Bakhtiyarpur, Bihar 803212', 'MAP_PIN',
   'Leave with the security guard if I do not answer.', true),

  -- ~4.2 km — Zone B
  ('b1000000-0000-0000-0000-000000000003', '91000000-0000-0000-0000-000000000003',
   'HOME', 'Vivaan Gupta', '+919900000003',
   'Plot 112, Athmalgola Road', null, 'Opposite Petrol Pump', 'Athmalgola Road',
   'Bakhtiyarpur', 'Bihar', '803212',
   25.4930000, 85.5510000, 'Athmalgola Road, Bakhtiyarpur, Bihar 803212', 'GPS',
   null, true),

  -- ~6.8 km — Zone C (COD disabled here)
  ('b1000000-0000-0000-0000-000000000004', '91000000-0000-0000-0000-000000000004',
   'HOME', 'Ananya Mishra', '+919900000004',
   'Village Karauta, Near Primary School', null, 'Karauta Chowk', 'Karauta',
   'Bakhtiyarpur', 'Bihar', '803213',
   25.5108000, 85.5720000, 'Karauta, Bakhtiyarpur, Bihar 803213', 'MANUAL',
   'Ask for Mishra ji house.', true),

  -- ~1.1 km — Zone A, work address
  ('b1000000-0000-0000-0000-000000000005', '91000000-0000-0000-0000-000000000002',
   'WORK', 'Diya Singh', '+919900000002',
   'Bakhtiyarpur Block Office', 'First Floor', 'Beside Bus Stand', 'Block Office',
   'Bakhtiyarpur', 'Bihar', '803212',
   25.4685000, 85.5170000, 'Block Office, Bakhtiyarpur, Bihar 803212', 'GPS',
   'Reception on the ground floor.', false),

  -- ~14 km — deliberately outside the service area, for the not-serviceable path
  ('b1000000-0000-0000-0000-000000000006', '91000000-0000-0000-0000-000000000005',
   'HOME', 'Kabir Anand', '+919900000005',
   'Barh Main Road', null, 'Near Barh Junction', 'Barh',
   'Barh', 'Bihar', '803213',
   25.4780000, 85.7060000, 'Barh, Bihar 803213', 'GPS',
   null, true);

-- Cache the resolved zone on each address, exactly as the app would.
do $$
declare
  v_address public.addresses;
  v_result jsonb;
begin
  for v_address in select * from public.addresses loop
    v_result := public.check_serviceability(v_address.latitude, v_address.longitude);

    update public.addresses
    set resolved_zone_id = nullif(v_result ->> 'zone_id', '')::uuid,
        resolved_branch_id = nullif(v_result ->> 'branch_id', '')::uuid,
        distance_km = nullif(v_result ->> 'distance_km', '')::numeric,
        is_serviceable = (v_result ->> 'serviceable')::boolean,
        serviceability_checked_at = now()
    where id = v_address.id;
  end loop;
end;
$$;

-- Wallet & loyalty starting balances
select app.post_wallet_entry(
  '91000000-0000-0000-0000-000000000002', 'PROMOTION', 100,
  'Welcome credit for joining Bites Box', null, null, 'seed_welcome_diya'
);
select app.post_wallet_entry(
  '91000000-0000-0000-0000-000000000003', 'PROMOTION', 50,
  'Referral bonus', null, null, 'seed_referral_vivaan'
);

-- Device tokens so notification fan-out has real targets in development.
insert into public.device_tokens (user_id, token, platform, device_model, os_version, app_version, locale) values
  ('91000000-0000-0000-0000-000000000001', 'seed-fcm-token-aarav-android',  'ANDROID', 'Redmi Note 13',   'Android 14', '1.0.0', 'en'),
  ('91000000-0000-0000-0000-000000000002', 'seed-fcm-token-diya-android',   'ANDROID', 'Samsung Galaxy M14', 'Android 14', '1.0.0', 'en'),
  ('91000000-0000-0000-0000-000000000003', 'seed-fcm-token-vivaan-ios',     'IOS',     'iPhone 13',       'iOS 18.2',   '1.0.0', 'en'),
  ('90000000-0000-0000-0000-000000000101', 'seed-fcm-token-rahul-android',  'ANDROID', 'Moto G84',        'Android 14', '1.0.0', 'en'),
  ('90000000-0000-0000-0000-000000000201', 'seed-fcm-token-kitchen-tablet', 'ANDROID', 'Lenovo Tab M10',  'Android 13', '1.0.0', 'en');
