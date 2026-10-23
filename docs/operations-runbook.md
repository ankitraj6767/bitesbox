# Operations response runbook

Use this guide for the aggregate health alerts shown on the admin Live Operations
board. Alerts contain counts and ages only; use authenticated admin pages and
provider consoles for record-level investigation. Keep order, customer, rider,
address, and payment data out of screenshots and incident-chat messages.

## Payment webhooks

For `PAYMENT_WEBHOOK_FAILED`, check Razorpay webhook delivery status and the
matching `payment_events` row by its provider event id. Confirm the signature is
valid, whether the event is processed, and whether reconciliation has already
updated the payment. The webhook registers a verified event before applying side
effects and acknowledges registered handler failures for operator reconciliation.

For `PAYMENT_WEBHOOK_REPEATED`, verify that duplicates point to the same
`provider_event_id`; the duplicate counter increments without retaining another
copy of the payload. Replays should remain harmless because payment capture is
idempotent. Investigate any event that is repeatedly delivered but remains
unprocessed; do not manually create a second payment or order.

An invalid signature is rejected and is not a valid Razorpay delivery. Confirm the
configured webhook secret with the payment owner before changing provider settings.
Do not log or paste webhook signatures, request bodies, or payment credentials.

## Refunds and payment reconciliation

For `REFUND_STUCK`, find the refund in the admin Refunds page and compare its
provider refund id/status with Razorpay. An ambiguous network timeout or 5xx after
a refund request leaves Bites Box in `PROCESSING` with an unknown provider outcome.
**Do not approve or issue another gateway refund to “retry” it.** First inspect
Razorpay for an existing refund; reconcile the existing provider result using the
normal webhook/scheduled reconciliation path. Escalate mismatched provider and
database state to the finance owner.

For a failed scheduled/reconciliation job, open the job run and inspect the
sanitized Edge Function error in Sentry using its request id. Correct the cause,
then run the supported scheduled job once through the operator-approved path. A
repeat should be safe through the existing database idempotency keys. Never test
this by issuing a live charge or refund.

## Delayed orders

`ORDER_STATE_PROLONGED` uses state-specific age thresholds. Open the order in the
admin console, confirm its latest status history, payment state, kitchen progress,
and assignment state, then contact the responsible on-shift operator through the
approved internal channel. Use the existing audited order transition/override
actions. Do not update order status directly in SQL.

## Stale rider location

`DELIVERY_LOCATION_STALE` means an active rider-enabled assignment has no accepted
GPS fix in the last two minutes. The customer's tracking screen hides the old
marker from the live map and labels the last capture time as stale. Check whether
the rider has location services and foreground location permission, and check
network and battery restrictions. Android 13+ can hide a denied app notification
from the notification drawer while the foreground service remains visible in
Task Manager; notification permission denial alone does not stop tracking. After a settings change,
the rider must reopen Bites Box and a new OS-captured fix must arrive before the
position is live again. Offer the map/deep-link fallback and continue delivery
actions; GPS is not required for pickup, cash handling, completion, or failure.

Location is shared only for the current active assignment after rider consent. A
server-side stop request clears customer-visible linkage on sign-out, stop,
completion, cancellation, or reassignment. If a rider is offline when they stop,
the phone stops publishing immediately and the app retries the server-side stop
when connectivity returns. Do not interpret the last stored point as current.

## Telemetry setup and privacy

Configure Sentry separately per environment:

- Edge Functions: server-side `SENTRY_DSN`, `SENTRY_RELEASE`, and `APP_ENV`.
- Admin server: `SENTRY_DSN`, `SENTRY_RELEASE`, and `APP_ENV`.
- Admin browser: public Sentry DSN in `NEXT_PUBLIC_SENTRY_DSN`, with
  `NEXT_PUBLIC_APP_ENV` and `NEXT_PUBLIC_APP_RELEASE`.
- Flutter: `SENTRY_DSN` and `APP_ENV` through the selected Dart define file.

Use a non-production project for development and staging. An empty DSN disables
reporting and is supported. Telemetry is best-effort and must never gate checkout,
payment processing, or delivery. Scrubbers drop user identity, auth headers,
cookies, request bodies, arbitrary extras, OTPs, signatures, phone/email/address
data, rider document paths, and uploaded image bytes. Only route/feature, broad
role category, environment, release, and request correlation context are intended
to remain. Review Sentry project access and retention under the organization's
privacy process before enabling production reporting.

## Staff MFA enrollment and recovery

Sensitive back-office permissions require a Supabase-signed AAL2 session. MFA
does not add permissions; current role and branch grants remain required.

Before rollout:

1. Verify the hosted Supabase plan and Auth dashboard support TOTP factors and AAL
   enforcement for the project's current Auth version.
2. Confirm at least two owner accounts can sign in and that one owner has a second
   verified authenticator. Keep a separately verified owner available throughout.
3. Enable/configure the supported TOTP factor policy in the hosted Auth dashboard;
   the checked-in `supabase/config.toml` applies to local development only.
4. Pilot enrollment and a sensitive action with a test staff account. Confirm an
   AAL1 request is denied at the database/RPC boundary and the resulting AAL2
   request remains subject to RBAC and branch scope.
5. Roll out to owner/admin first, then finance, operations, support, marketing,
   and remaining back-office users. Monitor sign-in failures before expanding.

For a lost or revoked authenticator, verify the staff member's identity through
the established owner process, then use the Supabase Auth dashboard's supported
factor reset/revocation controls. Re-enrollment starts with AAL1 and must complete
the normal TOTP challenge. There is no email, support, query-parameter, or
metadata-based bypass. Record the operator and reason in the approved audit trail.

## Rollback and forward recovery

The production-readiness migration is additive/forward-only and changes defaults,
function behavior, grants, triggers, and RLS write paths. Do not delete the
migration record or edit an applied migration. If a release issue is found, stop
the relevant rollout, preserve evidence, and use a reviewed forward migration or
restore procedure. Do not relax AAL enforcement to regain access; use the verified
owner recovery process. No hosted migration should be applied until the database
CI job passes and the hosted target has been confirmed explicitly.
