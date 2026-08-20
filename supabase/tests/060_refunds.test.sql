-- ═══════════════════════════════════════════════════════════════════════════
-- REFUNDS
--
-- Refunds move money out of the business, so the rules that matter are: only
-- someone with the permission may ask, the amount can never exceed what was
-- actually paid less what has already been returned, approval is a separate act
-- from the request, and every decision is audited.
-- ═══════════════════════════════════════════════════════════════════════════
begin;

select tap.suite('Refunds');

select tap.reset();

select tap.remember('delivered', tap.seed_order(1)::text);   -- DELIVERED, paid 566
select tap.remember('partly',    tap.seed_order(9)::text);   -- already partially refunded
select tap.remember('unpaid',    tap.seed_order(10)::text);  -- PENDING_PAYMENT

-- ─── Only the right people may ask ──────────────────────────────────────────
select tap.as_user(tap.seed('customer_a'));

select tap.throws(
  format('select public.request_refund(%L, ''FULL_REFUND'', ''QUALITY_ISSUE'')',
         tap.recall_uuid('delivered')),
  'PERMISSION_DENIED',
  'a customer cannot refund themselves'
);

-- What a customer *can* do is ask for help, which raises a ticket for a human.
select tap.no_throw(
  format('select public.request_order_help(%L, ''FOOD_QUALITY'', ''The biryani was cold'')',
         tap.recall_uuid('delivered')),
  'a customer can raise a problem with their order'
);

select tap.no_throw(
  format('select public.refund_eligibility(%L)', tap.recall_uuid('delivered')),
  'a customer can see whether a refund is possible'
);

select tap.reset();

select tap.as_user(tap.seed('kitchen'));

select tap.throws(
  format('select public.request_refund(%L, ''FULL_REFUND'', ''QUALITY_ISSUE'')',
         tap.recall_uuid('delivered')),
  'PERMISSION_DENIED',
  'kitchen staff cannot issue refunds'
);

select tap.reset();

-- ─── An unpaid order has nothing to refund ──────────────────────────────────
select tap.as_user(tap.seed('support'));

select tap.throws(
  format('select public.request_refund(%L, ''FULL_REFUND'', ''PAYMENT_ISSUE'')',
         tap.recall_uuid('unpaid')),
  'REFUND_NOT_ALLOWED',
  'an unpaid order cannot be refunded'
);

-- ─── Amount validation ──────────────────────────────────────────────────────
select tap.throws(
  format(
    'select public.request_refund(%L, ''PARTIAL_REFUND'', ''QUALITY_ISSUE'', 999999)',
    tap.recall_uuid('delivered')
  ),
  'REFUND_AMOUNT_EXCEEDS_REFUNDABLE',
  'a refund cannot exceed what was paid'
);

select tap.throws(
  format(
    'select public.request_refund(%L, ''PARTIAL_REFUND'', ''QUALITY_ISSUE'', -50)',
    tap.recall_uuid('delivered')
  ),
  'REFUND_AMOUNT_REQUIRED',
  'a negative refund is refused'
);

select tap.throws(
  format(
    'select public.request_refund(%L, ''PARTIAL_REFUND'', ''QUALITY_ISSUE'', 0)',
    tap.recall_uuid('delivered')
  ),
  'REFUND_AMOUNT_REQUIRED',
  'a zero refund is refused'
);

-- ─── A valid partial refund ─────────────────────────────────────────────────
select tap.remember(
  'refund_id',
  (public.request_refund(
     tap.recall_uuid('delivered'),
     'PARTIAL_REFUND',
     'QUALITY_ISSUE',
     100,
     'WALLET_CREDIT',
     'Cold on arrival',
     null,
     'bb-test-refund-1'
   ) ->> 'refund_id')
);

select tap.ok(tap.recall('refund_id') is not null, 'support can request a partial refund');

-- Idempotency: a retried request must not create a second refund.
select tap.eq(
  (public.request_refund(
     tap.recall_uuid('delivered'),
     'PARTIAL_REFUND',
     'QUALITY_ISSUE',
     100,
     'WALLET_CREDIT',
     'Cold on arrival',
     null,
     'bb-test-refund-1'
   ) ->> 'refund_id'),
  tap.recall('refund_id'),
  'replaying the refund key returns the same refund'
);

select tap.reset();

select tap.eq(
  (select count(*) from public.refunds where idempotency_key = 'bb-test-refund-1'),
  1::bigint,
  'only one refund row exists for the key'
);

-- ─── Requesting is not approving ────────────────────────────────────────────
select tap.as_user(tap.seed('support'));

-- Support may raise a refund but not sign it off; that separation is the point.
select tap.throws(
  format('select public.approve_refund(%L)', tap.recall_uuid('refund_id')),
  'PERMISSION_DENIED',
  'the same person cannot both request and approve'
);

select tap.reset();

select tap.as_user(tap.seed('finance'));

select tap.no_throw(
  format('select public.approve_refund(%L, ''Verified with the kitchen'')',
         tap.recall_uuid('refund_id')),
  'finance can approve a refund'
);

select tap.reset();

select tap.ok(
  (select status::text in ('APPROVED', 'PROCESSING', 'COMPLETED')
     from public.refunds where id = tap.recall_uuid('refund_id')),
  'the refund moves out of the pending state'
);

-- ─── Settlement is a separate, service-role step ────────────────────────────
-- Approval records a decision; it does not move money. The Edge Function settles
-- a wallet credit immediately and waits for the gateway webhook otherwise, which
-- is why the ledger entry does not exist yet.
select tap.eq(
  (select count(*) from public.wallet_transactions
    where refund_id = tap.recall_uuid('refund_id')),
  0::bigint,
  'approval alone does not credit the wallet'
);

select tap.as_service();

select tap.no_throw(
  format('select public.svc_complete_refund(%L, 100)', tap.recall_uuid('refund_id')),
  'the settlement worker completes a wallet refund'
);

select tap.reset();

select tap.eq(
  (select status::text from public.refunds where id = tap.recall_uuid('refund_id')),
  'COMPLETED',
  'the refund is completed'
);

select tap.eq(
  (select count(*) from public.wallet_transactions
    where refund_id = tap.recall_uuid('refund_id')),
  1::bigint,
  'settlement writes exactly one ledger entry'
);

-- Balances are derived from the ledger, never stored as a bare mutable number.
select tap.ok(
  (select balance_after >= amount from public.wallet_transactions
    where refund_id = tap.recall_uuid('refund_id')),
  'the ledger entry records the balance it produced'
);

-- Settling twice must not credit twice.
select tap.as_service();

select tap.no_throw(
  format('select public.svc_complete_refund(%L, 100)', tap.recall_uuid('refund_id')),
  'settling an already-completed refund is a no-op'
);

select tap.reset();

select tap.eq(
  (select count(*) from public.wallet_transactions
    where refund_id = tap.recall_uuid('refund_id')),
  1::bigint,
  'a replayed settlement does not credit the wallet twice'
);

-- ─── Every refund decision is audited ───────────────────────────────────────
select tap.ok(
  (select count(*) from public.audit_logs
    where entity_type = 'refund'
      and entity_id = tap.recall('refund_id')
      and action in ('REFUND_REQUEST', 'REFUND_APPROVE')) >= 1,
  'the refund decision is written to the audit log'
);

-- ─── Already-refunded value cannot be returned twice ────────────────────────
select tap.as_user(tap.seed('finance'));

-- 566 was paid and 100 has now been returned, so asking for the full amount again
-- must be refused rather than quietly refunding 566 a second time.
select tap.throws(
  format(
    'select public.request_refund(%L, ''PARTIAL_REFUND'', ''QUALITY_ISSUE'', 566,
       ''WALLET_CREDIT'', null, null, %L)',
    tap.recall_uuid('delivered'), 'bb-test-refund-2'
  ),
  'REFUND_AMOUNT_EXCEEDS_REFUNDABLE',
  'the full amount is refused once part of the order is already refunded'
);

-- What remains is refundable, and not a paisa more.
select tap.no_throw(
  format(
    'select public.request_refund(%L, ''PARTIAL_REFUND'', ''QUALITY_ISSUE'', 466,
       ''WALLET_CREDIT'', null, null, %L)',
    tap.recall_uuid('delivered'), 'bb-test-refund-3'
  ),
  'the remaining balance can still be refunded'
);

select tap.reset();

-- ─── Refund rows are never client-writable ──────────────────────────────────
select tap.as_user(tap.seed('finance'));

select tap.throws(
  format('update public.refunds set amount = 1 where id = %L', tap.recall_uuid('refund_id')),
  'PERMISSION_DENIED',
  'a refund amount cannot be edited by hand'
);

select tap.reset();

select tap.done('Refunds');

rollback;
