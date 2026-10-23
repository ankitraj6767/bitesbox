# Release status

Last updated: 23 October 2026. This release is being prepared on
`codex/reliability-production-readiness`. The implementation has **not** been
applied to a hosted Supabase project and has **not** been deployed.

## Source and hosted-state observations

The local migration directory contains **56 migration files**. A read-only
`npx supabase migration list --linked` check on 23 October 2026 showed 54 remote
migrations through `20261023045839_serialize_cart_line_mutations_for_group_merge`
and two local migrations not recorded remotely:

- `20261023053104_storefront_white_background.sql`
- `20261023065006_production_readiness_preferences_tracking_mfa.sql`

No migration was pushed. This read-only result is a point-in-time observation;
current hosted state after that check is **unverified**. It does not establish
whether a database schema has drifted or whether the development, staging, or
production projects match each other.

The local SQL stack could not be started because Docker/Colima was unavailable in
this environment. Therefore local reset, schema lint, SQL/RLS suites, and generated
database type comparison remain unverified here. The linked project's hosted
advisors were not run because no database password was available. The new
migration is forward-only; do not apply it to a hosted project until the database
CI job passes and the staged MFA rollout checklist in
[operations-runbook.md](operations-runbook.md) is reviewed.

## Product and release notes

Bites Box remains a single-brand ordering and delivery product. The release closes
known preference, location-sharing, staff assurance, telemetry, payment-provider
and CI coverage gaps without adding marketplace, grocery, dine-in, or dispatch
business models. The Swiggy comparison records deliberate product boundaries in
[swiggy-comparison.md](swiggy-comparison.md).

Hindi strings exist in profile data, but the repository does not establish Hindi
UI as a launch promise. Full Flutter localization remains a separate product
decision; this reliability release does not represent it as complete.

App version: **1.1.4+12**. This is a source version bump, not a signed store
release. No local APK build or iOS release build is claimed.

## Verification record

This section is updated from commands actually run on this release branch. A
GitHub workflow result will be recorded after CI runs for the pushed branch. A
passing workflow on an earlier commit is not evidence for this release.

| Area | Result | Evidence / limitation |
| --- | --- | --- |
| Flutter unit and widget tests | Passed: 139 tests | `flutter test --reporter compact` |
| Flutter static analysis | Passed | `flutter analyze` |
| Admin unit/component tests | Passed: 67 tests | `npm run test --workspace=@bitesbox/admin` |
| Admin browser journey | Passed: 5 tests | Playwright deterministic local Auth/REST fakes; no hosted credentials |
| Admin build | Passed | Next.js production build with placeholder Supabase configuration |
| Edge Functions | Passed | Deno checks, lint, formatting, logger and Razorpay contracts |
| SQL/RLS tests and generated types | Not run locally | Docker/Colima socket unavailable |
| Secret scan | Passed | `npm run secrets:check`; no committed credentials found |
| Android/iOS background location | Not device-verified | Follow physical-device plan in `docs/testing.md` |
| Hosted migration state | Unverified after read-only check | No hosted write was made |
| Store release signing | Not run | Requires release signing material and human review |

## Operational inventory

The checked-in schema contains 56 migrations. The application has customer,
kitchen, delivery-partner, and admin surfaces; the admin dashboard contains 29
page modules. Current test counts and exact command results are recorded in
[testing.md](testing.md). Local database execution remains blocked by the
unavailable Docker/Colima service; GitHub CI is the remaining migration/schema
verification for this branch.

## Important design decisions

- Marketing consent is independent of transactional channel delivery preferences;
  new-account marketing and WhatsApp defaults are off.
- GPS sharing is explicit, server-authorized, and tied to the current active
  assignment. Capture timestamps are checked server-side, and the direct table
  write paths are revoked. Location is not required to finish a delivery.
- Back-office sessions need Supabase-signed AAL2 for sensitive operations. Role
  and branch RBAC still apply. Hosted MFA settings and plan support are not
  verified by this repository change.
- A timed-out Razorpay write is treated as an unknown outcome, never replayed
  automatically without documented provider idempotency. Refund reconciliation
  is described in the operations runbook.
- Sentry is optional and best-effort. Redaction removes account identifiers,
  credentials, contact data, addresses, document paths, and image payloads before
  transmission.
