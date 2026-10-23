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

## Delivery-zone changes

Open Admin → Settings → Delivery with the intended outlet selected. Branch
managers and higher can add a radius or polygon zone, edit its fee/minimum/ETA/COD
limits, adjust peak or live operations surcharges, and change the priority used
when zones overlap. Checkout reads these values from the database for each new
quote, so saved changes take effect immediately; an order already placed keeps
its confirmed delivery fee and zone snapshot.

Permission is checked against the selected outlet, even for users whose role
grants delivery-zone management in another outlet. If controls are unavailable,
confirm the active outlet and ask an owner to review the staff role's branch
assignment and `branch.manage` grant for that outlet.

Use **Live** to remove a zone from matching new addresses, and **Accept orders**
to keep its coverage visible while preventing new orders in that zone. Deleting
a zone archives it and stops it matching future quotes; it preserves audit and
historical order records. Confirm the outlet and test a serviceability address
after changing a zone boundary or priority. Do not change delivery-zone rows in
SQL or use a client-selected outlet as authorization; branch permissions and RLS
remain authoritative.

## Other settings and outlet records

Open Admin → Settings and select the intended outlet before changing its Branch
tab. A user needs `branch.manage` for that outlet to edit its profile, weekly
trading hours, or dated holiday exceptions. Schedule and exception changes are
audited and affect future order availability. The customer app re-reads public
configuration after a Realtime change signal and when it resumes; confirmed
orders keep their saved terms.

An outlet cannot be hard-deleted. **Archive** is a soft removal that preserves
historical orders and audit records. It is blocked while the outlet has
non-terminal orders and while it is the last active outlet. Archiving the
default outlet also selects an active replacement the operator can manage. If
the archive option is disabled, check that another active outlet exists and that
the selected outlet can be managed. If availability cannot be verified, refresh
and retry instead of treating the check as proof that this is the last outlet.

Tax categories require `settings.update`. Make the replacement category default
before archiving the current default; category archival preserves menu and
historical order references. Changing tax configuration affects future quotes,
while order tax snapshots remain unchanged. Singleton settings and feature flag
keys are application contracts: edit their values or rollout percentages, but
do not delete the keys. Every such change is audited. Do not mutate these tables
directly in SQL.

## Pickup-code handoff

When a delivery order is ready and has an active assigned rider, use **Share
pickup code** at the bottom of its Ready card in the kitchen app. The server
issues a fresh code for that rider assignment and invalidates any earlier code.
**Copy code** copies only the code; **Share with rider** opens a prefilled SMS to
the assigned rider, and kitchen staff still confirms sending it in the messaging
app. The plaintext code is returned only for this authorized request and is not
written to the audit trail.

After a rider is reassigned, issue a new code from the Ready card before pickup;
the previous assignment's code cannot verify for the new rider. If the action is
missing, confirm the order is a ready delivery, the rider is accepted or waiting
at the outlet, and the signed-in staff member has `kitchen.operate` for that
outlet. A code cannot be issued when there is no active assignment.

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

## Referral attribution and reward reversals

The referral program has two independent gates: an OWNER or ADMIN must configure
and enable terms through Admin → Referrals with AAL2, and the referrals feature
flag must be enabled separately. Both gates start off. Confirm the approved
reward amounts, minimum eligible order, cap, and wallet expiry before opening the
flag. Do not take commercial values from test data or sample copy.

If a customer reports a missing referral, check the server-side attribution row
and its status in the referral activity view. Qualification requires the referred
customer's first eligible delivered/completed order, captured payment, no refund,
the configured minimum amount, and COD settlement where applicable. Retries use
ledger idempotency keys. A completed partial or full refund reverses unspent
referral credits; the refund's own wallet credit is preserved. The audit event
records any reward amount that could not be recovered. Never edit a wallet balance
or referral status directly. Stop new attributions by disabling the flag while
finance reviews an incident.

Each newly issued reward also queues a localized transactional notification.
The profile's saved language selects Hindi or English; push opt-out suppresses
push, while the in-app account notice remains available. If the wallet credit is
present but the customer did not receive a push, check that customer's push
preference and active device token. This notification does not use campaign or
marketing consent because it reports an earned account credit and contains no
offer.

## Guest cart recovery

After phone verification, the storefront shows items still saved on the device and
offers an explicit import into the selected outlet's account cart. Import submits
only product/variant/modifier/quantity intent; Postgres rechecks current menu
availability and prices. A stable per-cart idempotency key makes a retry safe if
the browser lost the import response. If import fails, keep the device cart and
ask the customer to retry after choosing an outlet with current availability. Do
not clear browser cart data until the database confirms the import.

## Hindi content maintenance

Canonical English content remains the fallback. Only staff with the existing
menu/CMS/coupon permissions can edit Hindi fields, and product translation edits
go through the audited translation RPC. A Hindi field being present does not mean
the food, allergen, or offer claim has been reviewed. Have a fluent reviewer
compare it with English and check small-screen rendering before publication.

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
