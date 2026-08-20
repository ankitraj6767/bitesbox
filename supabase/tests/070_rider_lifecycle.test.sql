-- ═══════════════════════════════════════════════════════════════════════════
-- RIDER LIFECYCLE
--
-- Covers migration 0029, which turned `rider_onboarding_status` from a column
-- that described a progression into one that enforces it:
--
--   PENDING → DOCUMENTS_SUBMITTED → VERIFIED → ACTIVE
--
-- plus the earnings adjustments that the ledger allowed but nothing could write.
-- ═══════════════════════════════════════════════════════════════════════════
begin;

select tap.suite('Rider lifecycle');

select tap.reset();

-- Suraj is seeded mid-onboarding, which is exactly the state under test.
select tap.eq(
  (select onboarding_status::text from public.delivery_partners
    where id = tap.seed('dp_suraj')),
  'DOCUMENTS_SUBMITTED',
  'the fixture rider is awaiting document review'
);

-- Start from PENDING so the first transition is observable.
update public.delivery_partners
set onboarding_status = 'PENDING', partner_code = null, approved_at = null, approved_by = null
where id = tap.seed('dp_suraj');

delete from public.delivery_partner_documents
where delivery_partner_id = tap.seed('dp_suraj');

-- ─── A rider submits their own documents ────────────────────────────────────
select tap.as_user(tap.seed('rider_suraj'));

select tap.no_throw(
  'select public.my_rider_onboarding()',
  'a rider can read their own onboarding checklist'
);

select tap.eq(
  (select jsonb_array_length(public.my_rider_onboarding() -> 'outstanding')),
  3,
  'three required documents are outstanding'
);

-- The storage path must sit under the rider's own uid prefix, matching the
-- bucket policy. A crafted path pointing at someone else's file is refused.
select tap.throws(
  'select public.submit_rider_document(
     ''DRIVING_LICENCE'',
     ''90000000-0000-0000-0000-000000000101/licence.jpg''
   )',
  'PERMISSION_DENIED',
  'a rider cannot claim another rider''s uploaded file'
);

select tap.throws(
  'select public.submit_rider_document(''DRIVING_LICENCE'', '''')',
  'CHECKOUT_INVALID',
  'a document needs an actual file'
);

select tap.throws(
  format(
    'select public.submit_rider_document(
       ''DRIVING_LICENCE'', %L, ''DL-123'', null, ''2020-01-01''
     )',
    tap.seed('rider_suraj')::text || '/licence.jpg'
  ),
  'CHECKOUT_INVALID',
  'an already-expired document is refused'
);

select tap.no_throw(
  format('select public.submit_rider_document(''DRIVING_LICENCE'', %L, ''DL-123'')',
         tap.seed('rider_suraj')::text || '/licence.jpg'),
  'a rider can submit their licence'
);

select tap.reset();

select tap.eq(
  (select onboarding_status::text from public.delivery_partners
    where id = tap.seed('dp_suraj')),
  'PENDING',
  'one document is not enough to advance'
);

select tap.as_user(tap.seed('rider_suraj'));

select tap.no_throw(
  format('select public.submit_rider_document(''AADHAAR'', %L)',
         tap.seed('rider_suraj')::text || '/aadhaar.jpg'),
  'a rider can submit their identity document'
);

select tap.no_throw(
  format('select public.submit_rider_document(''PROFILE_PHOTO'', %L)',
         tap.seed('rider_suraj')::text || '/photo.jpg'),
  'a rider can submit their photo'
);

select tap.reset();

select tap.eq(
  (select onboarding_status::text from public.delivery_partners
    where id = tap.seed('dp_suraj')),
  'DOCUMENTS_SUBMITTED',
  'submitting everything advances to documents submitted'
);

-- ─── A rider cannot approve their own paperwork ─────────────────────────────
select tap.as_user(tap.seed('rider_suraj'));

select tap.remember(
  'licence_doc',
  (select id::text from public.delivery_partner_documents
    where delivery_partner_id = tap.seed('dp_suraj') and document_type = 'DRIVING_LICENCE')
);

select tap.throws(
  format('select public.review_rider_document(%L, true)', tap.recall_uuid('licence_doc')),
  'PERMISSION_DENIED',
  'a rider cannot approve their own document'
);

select tap.throws(
  format('select public.approve_rider(%L)', tap.seed('dp_suraj')),
  'PERMISSION_DENIED',
  'a rider cannot activate themselves'
);

-- Nor by writing the row directly. Before migration 0031 a rider could set
-- onboarding_status to VERIFIED, zero their cash_in_hand, inflate rating_average
-- and raise max_concurrent_orders, because the self-update policy placed no
-- restriction on which columns they could change.
-- With no permissive policy the row is invisible to UPDATE, so these statements
-- affect zero rows rather than raising. That is the shape of the guarantee:
-- silently nothing, not an error the client could probe.
select tap.remember(
  'guard_before',
  (select format('%s|%s|%s|%s',
     onboarding_status, cash_in_hand, rating_average, max_concurrent_orders)
   from public.delivery_partners where id = tap.seed('dp_suraj'))
);

select tap.no_throw(
  format(
    'update public.delivery_partners
       set onboarding_status = ''VERIFIED'',
           cash_in_hand = 0,
           rating_average = 5,
           total_deliveries = 9999,
           max_concurrent_orders = 10
       where id = %L',
    tap.seed('dp_suraj')
  ),
  'a rider''s attempt to rewrite their record is accepted but matches nothing'
);

select tap.eq(
  (select format('%s|%s|%s|%s',
     onboarding_status, cash_in_hand, rating_average, max_concurrent_orders)
   from public.delivery_partners where id = tap.seed('dp_suraj')),
  tap.recall('guard_before'),
  'status, cash owed, rating and order limit are all unchanged'
);

-- What they may maintain is their contact details, through a narrow function.
select tap.no_throw(
  'select public.update_my_rider_profile(
     ''9900000999'', ''Sunita Mahto'', ''9900000888'', ''suraj@upi''
   )',
  'a rider can update their own contact details'
);

select tap.reset();

select tap.eq(
  (select emergency_contact_name from public.delivery_partners
    where id = tap.seed('dp_suraj')),
  'Sunita Mahto',
  'the contact details are saved'
);

-- ─── An owner reviews ───────────────────────────────────────────────────────
-- rider.approve and rider.suspend are held by ADMIN and OWNER only; a MANAGER can
-- maintain a rider (rider.update) but not decide whether they may work.
select tap.as_user(tap.seed('owner'));

select tap.throws(
  format('select public.review_rider_document(%L, false)', tap.recall_uuid('licence_doc')),
  'CHECKOUT_INVALID',
  'a rejection must carry a reason the rider can act on'
);

select tap.no_throw(
  format('select public.review_rider_document(%L, false, ''The photo is blurred'')',
         tap.recall_uuid('licence_doc')),
  'a manager can reject a document'
);

-- Activation is refused while a required document is outstanding.
select tap.throws(
  format('select public.approve_rider(%L)', tap.seed('dp_suraj')),
  'RIDER_NOT_ACTIVE',
  'a rider cannot be activated before verification'
);

select tap.reset();

-- The rider re-uploads, and review re-opens.
select tap.as_user(tap.seed('rider_suraj'));

select tap.no_throw(
  format('select public.submit_rider_document(''DRIVING_LICENCE'', %L, ''DL-456'')',
         tap.seed('rider_suraj')::text || '/licence-v2.jpg'),
  'a rider can replace a rejected document'
);

select tap.reset();

select tap.eq(
  (select status::text from public.delivery_partner_documents
    where id = tap.recall_uuid('licence_doc')),
  'PENDING',
  'replacing a document re-opens the review rather than adding a row'
);

select tap.eq(
  (select count(*) from public.delivery_partner_documents
    where delivery_partner_id = tap.seed('dp_suraj')),
  3::bigint,
  'a resubmission replaces in place, it does not duplicate'
);

-- ─── Verification, then activation ──────────────────────────────────────────
select tap.as_user(tap.seed('owner'));

select public.review_rider_document(d.id, true)
from public.delivery_partner_documents d
where d.delivery_partner_id = tap.seed('dp_suraj');

select tap.reset();

select tap.eq(
  (select onboarding_status::text from public.delivery_partners
    where id = tap.seed('dp_suraj')),
  'VERIFIED',
  'approving every required document verifies the rider'
);

select tap.as_user(tap.seed('owner'));

select tap.no_throw(
  format('select public.approve_rider(%L, ''Joined the Bakhtiyarpur team'')',
         tap.seed('dp_suraj')),
  'an owner can activate a verified rider'
);

select tap.reset();

select tap.eq(
  (select onboarding_status::text from public.delivery_partners
    where id = tap.seed('dp_suraj')),
  'ACTIVE',
  'the rider is active'
);

select tap.ok(
  (select partner_code is not null and partner_code <> ''
     from public.delivery_partners where id = tap.seed('dp_suraj')),
  'activation issues a partner code'
);

select tap.ok(
  (select approved_at is not null and approved_by = tap.seed('owner')
     from public.delivery_partners where id = tap.seed('dp_suraj')),
  'the approval records who did it and when'
);

select tap.eq(
  (select duty_state::text from public.delivery_partners where id = tap.seed('dp_suraj')),
  'OFFLINE',
  'a newly activated rider starts off duty and chooses when to begin'
);

select tap.ok(
  (select count(*) from public.audit_logs
    where entity_type = 'delivery_partner'
      and entity_id = tap.seed('dp_suraj')::text) >= 1,
  'activation is audited'
);

-- Partner codes are unique, which matters because they appear on cash sheets.
select tap.eq(
  (select count(*) from (
     select partner_code from public.delivery_partners
     where partner_code is not null
     group by partner_code having count(*) > 1
   ) as dupes),
  0::bigint,
  'partner codes are unique'
);

-- ─── Now that they are active, they can go on duty ──────────────────────────
select tap.as_user(tap.seed('rider_suraj'));

select tap.no_throw(
  'select public.set_duty_state(''AVAILABLE'', 25.4610, 85.5230)',
  'an active rider can go on duty'
);

select tap.reset();

select tap.eq(
  (select duty_state::text from public.delivery_partners where id = tap.seed('dp_suraj')),
  'AVAILABLE',
  'the duty state is recorded'
);

select tap.eq(
  (select count(*) from public.delivery_partner_locations
    where delivery_partner_id = tap.seed('dp_suraj')),
  1::bigint,
  'going on duty seeds a position so dispatch can rank by proximity'
);

-- ─── Suspension ─────────────────────────────────────────────────────────────
select tap.as_user(tap.seed('owner'));

select tap.throws(
  format('select public.suspend_rider(%L, '''')', tap.seed('dp_suraj')),
  'CHECKOUT_INVALID',
  'a suspension must be explained'
);

select tap.no_throw(
  format('select public.suspend_rider(%L, ''Repeated late deliveries'')',
         tap.seed('dp_suraj')),
  'an owner can suspend a rider'
);

select tap.reset();

select tap.eq(
  (select duty_state::text from public.delivery_partners where id = tap.seed('dp_suraj')),
  'OFFLINE',
  'suspension takes the rider off duty immediately'
);

select tap.as_user(tap.seed('rider_suraj'));

select tap.throws(
  'select public.set_duty_state(''AVAILABLE'')',
  'RIDER_NOT_ACTIVE',
  'a suspended rider cannot come back on duty'
);

select tap.reset();

-- ─── Earnings adjustments ───────────────────────────────────────────────────
select tap.as_user(tap.seed('manager'));

-- The six adjustment types had no writer at all before migration 0029.
select tap.no_throw(
  format('select public.post_delivery_earning(%L, ''INCENTIVE'', 200, ''Diwali week bonus'')',
         tap.seed('dp_rahul')),
  'a manager can post an incentive'
);

select tap.eq(
  (select amount::numeric from public.delivery_earnings
    where delivery_partner_id = tap.seed('dp_rahul') and entry_type = 'INCENTIVE'),
  200::numeric,
  'the incentive is credited'
);

-- The sign follows the entry type, so a mistyped minus cannot turn a penalty into
-- a bonus — or the reverse.
select tap.no_throw(
  format('select public.post_delivery_earning(%L, ''PENALTY'', 150, ''Late without notice'')',
         tap.seed('dp_rahul')),
  'a manager can post a penalty'
);

select tap.eq(
  (select amount::numeric from public.delivery_earnings
    where delivery_partner_id = tap.seed('dp_rahul') and entry_type = 'PENALTY'),
  -150::numeric,
  'a penalty is stored as a deduction whichever sign was supplied'
);

select tap.throws(
  format('select public.post_delivery_earning(%L, ''DELIVERY_PAYOUT'', 500)',
         tap.seed('dp_rahul')),
  'CHECKOUT_INVALID',
  'a system-generated payout cannot be posted by hand'
);

select tap.throws(
  format('select public.post_delivery_earning(%L, ''INCENTIVE'', 0)', tap.seed('dp_rahul')),
  'CHECKOUT_INVALID',
  'a zero adjustment is refused'
);

select tap.reset();

select tap.ok(
  (select count(*) from public.audit_logs
    where entity_type = 'delivery_earning' and action = 'WALLET_ADJUSTMENT') >= 2,
  'every earnings adjustment is audited'
);

-- The ledger is append-only, so a posted adjustment cannot be quietly rewritten.
select tap.as_user(tap.seed('manager'));

select tap.throws(
  format(
    'update public.delivery_earnings set amount = 9999
       where delivery_partner_id = %L and entry_type = ''PENALTY''',
    tap.seed('dp_rahul')
  ),
  'PERMISSION_DENIED',
  'an earnings entry cannot be edited after the fact'
);

select tap.reset();

-- ─── A rider sees their own earnings and nobody else's ──────────────────────
select tap.as_user(tap.seed('rider_rahul'));

select tap.no_throw('select public.my_earnings()', 'a rider can read their earnings');

select tap.eq(
  (select count(*) from public.delivery_earnings
    where delivery_partner_id <> tap.seed('dp_rahul')),
  0::bigint,
  'a rider sees no one else''s earnings'
);

select tap.reset();

-- ═══════════════════════════════════════════════════════════════════════════
-- STAFF READ SURFACE  ·  public.rider_onboarding
--
-- Added in migration 0032 so the dashboard can review documents. Before it, the
-- only rider action in the admin UI was "Approve rider", which the server
-- correctly refuses until every required document is approved — a button that
-- always failed with no way to make it succeed.
--
-- These identity documents are the most sensitive rows a rider owns, so the read
-- is checked from every direction.
-- ═══════════════════════════════════════════════════════════════════════════
select tap.note('rider_onboarding — the staff review surface');

-- A customer must not be able to read a rider's documents.
select tap.as_user(tap.seed('customer_a'));

select tap.throws(
  format('select public.rider_onboarding(%L)', tap.seed('dp_rahul')),
  'PERMISSION_DENIED',
  'a customer cannot read a rider''s documents'
);

select tap.reset();

-- Nor may a rider read another rider's.
select tap.as_user(tap.seed('rider_amit'));

select tap.throws(
  format('select public.rider_onboarding(%L)', tap.seed('dp_rahul')),
  'PERMISSION_DENIED',
  'one rider cannot read another rider''s documents'
);

select tap.reset();

-- Kitchen staff have no business here either.
select tap.as_user(tap.seed('kitchen'));

select tap.throws(
  format('select public.rider_onboarding(%L)', tap.seed('dp_rahul')),
  'PERMISSION_DENIED',
  'kitchen staff cannot read rider documents'
);

select tap.reset();

-- Operations holds rider.view, so this is the intended caller.
select tap.as_user(tap.seed('operations'));

select tap.no_throw(
  format('select public.rider_onboarding(%L)', tap.seed('dp_rahul')),
  'operations can read a rider''s onboarding'
);

select tap.throws(
  'select public.rider_onboarding(''00000000-0000-0000-0000-0000000000ff'')',
  'RIDER_NOT_FOUND',
  'an unknown rider is reported as such'
);

-- The required list must come from the setting, not from whatever happens to be
-- uploaded — otherwise a rider who uploaded nothing would look complete.
select tap.eq(
  (select jsonb_array_length(
     public.rider_onboarding(tap.seed('dp_rahul')) -> 'required_documents')),
  3,
  'the required list is the configured one, not the uploaded one'
);

-- Rahul has licence + aadhaar + RC approved, but no PROFILE_PHOTO, which is
-- required. So he is outstanding one document and not activatable.
select tap.eq(
  (select public.rider_onboarding(tap.seed('dp_rahul')) -> 'outstanding'),
  '["PROFILE_PHOTO"]'::jsonb,
  'a required document with nothing on file is reported outstanding'
);

select tap.eq(
  (select (public.rider_onboarding(tap.seed('dp_rahul')) ->> 'ready_to_activate')::boolean),
  false,
  'a rider missing a required document is not ready to activate'
);

-- His approved VEHICLE_RC is not in the required list, so it must be flagged
-- optional rather than counted towards the checklist.
select tap.eq(
  (select count(*) from jsonb_array_elements(
     public.rider_onboarding(tap.seed('dp_rahul')) -> 'documents') as d
   where d ->> 'document_type' = 'VEHICLE_RC'
     and (d ->> 'is_required')::boolean = false),
  1::bigint,
  'an uploaded document outside the required list is marked optional'
);

-- The reviewer needs the storage path to sign a URL; without it the dialog can
-- show metadata but not the document.
select tap.ok(
  (select bool_and(coalesce(d ->> 'storage_path', '') <> '')
   from jsonb_array_elements(
     public.rider_onboarding(tap.seed('dp_rahul')) -> 'documents') as d),
  'every document carries a storage path'
);

-- Seeded paths must obey the same convention the storage policy enforces
-- (`foldername[1] = auth.uid()`) and that submit_rider_document validates. They
-- previously embedded the bucket name, which made them unreadable by the rider
-- who owned them.
select tap.reset();

select tap.eq(
  (select count(*) from public.delivery_partner_documents d
   join public.delivery_partners dp on dp.id = d.delivery_partner_id
   where split_part(d.storage_path, '/', 1) <> dp.user_id::text),
  0::bigint,
  'every document path starts with its owner''s user id'
);

-- Suraj has been through the whole lifecycle above: three documents submitted,
-- all approved, activated, then suspended. The read surface must agree with what
-- actually happened rather than with the seed it started from.
select tap.as_user(tap.seed('operations'));

select tap.eq(
  (select (public.rider_onboarding(tap.seed('dp_suraj')) ->> 'awaiting_review_count')::int),
  0,
  'nothing is left awaiting review once every document is approved'
);

select tap.eq(
  (select public.rider_onboarding(tap.seed('dp_suraj')) -> 'outstanding'),
  '[]'::jsonb,
  'nothing is outstanding once every required document is approved'
);

-- Suspension is not a documents problem, so the checklist still reads complete.
-- Reinstating is an approval decision, and the reviewer needs to see that the
-- paperwork is not what is blocking it.
select tap.eq(
  (select (public.rider_onboarding(tap.seed('dp_suraj')) ->> 'ready_to_activate')::boolean),
  true,
  'a suspended rider with approved documents is still paperwork-complete'
);

select tap.eq(
  (select public.rider_onboarding(tap.seed('dp_suraj')) ->> 'onboarding_status'),
  'SUSPENDED',
  'the status reported is the real one, not derived from the documents'
);

select tap.ok(
  (select public.rider_onboarding(tap.seed('dp_suraj')) ->> 'suspended_reason'
     = 'Repeated late deliveries'),
  'the suspension reason is visible to the reviewer'
);

select tap.reset();

select tap.done('Rider lifecycle');

rollback;
