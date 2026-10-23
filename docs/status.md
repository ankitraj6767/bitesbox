# Release status

Last updated: 23 October 2026. The customer-growth release is on review branch
`codex/five-product-features`, based on `76d99d40419ea58e47265f1235c12abd7b1a93e3`.
Source changes are prepared for review. No hosted Supabase project, website, DNS,
payment provider, or app store has been changed by this work.

## Source and hosted state

The checkout contains **61 migration files**. A local Supabase stack reset applied
the migrations and seed successfully, and the SQL/RLS suite passed against that
local database. This proves local schema setup only. Hosted migration state is
**unverified**: no linked project state was read during this release, and no
hosted migration was pushed.

The repository's `deploy-supabase.yml` runs a hosted staging migration/function
deployment on matching pushes to `main`; `deploy-admin.yml` can deploy the admin
site when Vercel credentials are configured; and `android-auto-release.yml` can
publish a signed Android update when release secrets exist. The attached brief
requires review before any of those side effects, so this release is pushed to the
`codex/five-product-features` review branch and is not pushed to `main`. The CI
workflow runs for `codex/**`; its result for this release must be checked after
the branch push. A CI pass does not mean that hosted migrations or application
deployments ran.

## Product scope

The source adds server-configured referrals, generated English/Hindi Flutter
resources, Hindi database content fields, a separate public customer storefront,
cross-device favorites, and customer/admin outlet selection. The existing
single-brand order, payment, wallet, and staff authorization paths remain the
authority for customer-visible and money-moving outcomes.

Referral rewards remain disabled until an authorized owner approves and saves
actual program terms and separately enables the feature flag. Guest cart import
uses a server-side idempotency record and revalidates each item through the
existing cart RPC. New and high-traffic Flutter flows and the storefront use
English/Hindi resources, but several legacy Flutter address, support, wallet,
group-order, and tracking screens still contain English literals. Full extraction
and translation of those remaining strings is a known localization gap, not a
completed acceptance criterion. Human translation review and physical-device
Devanagari layout review remain release gates. No Hindi food, allergen, or
promotional claim was invented.

## Version

Workspace and web packages: **1.2.0**. Flutter source version: **1.2.0+13**.
This is a source version bump, not a signed release. No local APK was built at the
request of the project owner. CI's mobile job may build a debug APK when the
workflow runs; that is not store release evidence. No signed iOS build was run.

## Verification record

These are local commands completed on this checkout. A workflow run for the final
commit was not available when this document was written; GitHub CI should be
reviewed before merging.

| Area | Result | Evidence / limitation |
| --- | --- | --- |
| Local database reset | Passed | All 61 migrations and seed applied to local Supabase/Postgres |
| SQL/RLS tests | Passed: 12 suites | `npm run db:test`; includes growth, referral, favorites, branch, and guest-cart cases |
| Database lint | Passed | `npm run db:lint`; warning-level advisories remain documented by the tool |
| Generated database types | Refreshed | `npm run db:types`; generated types include the five new migrations |
| Edge Functions | Passed | `npm run fn:check`, `npm run fn:lint`, and `npm run secrets:check` |
| Admin unit tests | Passed: 67 tests | `npm run admin:test` |
| Admin browser journey | Passed: 7 tests | Deterministic local Auth/REST fake; includes two authorized branches, rejection of an out-of-scope branch, AAL2 referral terms, and refund gates |
| Admin build | Passed | Next.js production build with placeholder Supabase configuration |
| Storefront lint, typecheck, unit tests | Passed: 4 unit tests | Playwright/build rerun sequentially after a temporary artifact collision |
| Storefront browser journey | Passed: 5 tests | Guest browsing/outlet/language, referral OTP attribution, guest-cart import → server-priced COD order → tracking, fake online-payment callback, favorites |
| Storefront production build | Passed | Next.js production build with placeholder Supabase configuration |
| Flutter static analysis | Passed | `npm run mobile:analyze` |
| Flutter unit/widget tests | Passed: 144 tests | `npm run mobile:test`; does not replace device validation |
| Device behavior | Not verified | No physical Android/iOS location, notification, deep-link, or Devanagari layout run |
| Hosted migration/configuration state | Unverified | No hosted project was inspected or modified |
| GitHub CI for final commit | Pending | Run after pushing the review branch |

## Release gates and known limits

- Keep the `referrals` flag disabled until owner-approved reward terms and finance
  review are recorded; verify the rollout with a non-production account first.
- Set public storefront environment variables in a preview deployment and test
  with non-production Supabase credentials. No website deployment or DNS update
  is included.
- Have a Hindi reviewer validate customer copy and test Android/iOS screen sizes,
  text scaling, deep links, and offline behavior before release.
- Multi-outlet authorization continues to come from session branch scope and
  server serviceability. A client-selected branch never grants database access.
- Hosted migration status, hosted feature flags, payment credentials, notification
  configuration, store signing, and provider setup remain unverified.

See [testing.md](testing.md), [customer-growth.md](customer-growth.md), and
[operations-runbook.md](operations-runbook.md) for detailed procedures.
