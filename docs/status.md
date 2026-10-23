# Release status

Last updated: 23 October 2026. This source release includes the delivery-zone,
kitchen handoff, and settings fixes, plus rider-bound pickup-code sharing. It
bumps workspace/mobile source to **1.2.5 / 1.2.5+37**. Signed Android update
**1.2.5+57** was built and published by [GitHub Actions run
39981155832](https://github.com/ankitraj6767/bitesbox/actions/runs/39981155832).
The pickup-code migration is present in hosted migration history through
`20261023151817`; the admin deployment workflow was not dispatched and any
separate Vercel Git integration deployment is unverified.

## Settings and outlet controls

Branch details, trading hours, dated holiday exceptions, tax categories, delivery
zones, and feature-flag rollout can now be managed from Settings according to
their existing branch or settings permissions. Outlet and tax-category removal
is a soft archive that preserves history and references. Archiving is blocked
when it would remove the last active outlet, strand the default outlet, or leave
non-terminal orders behind. Trading-hour and holiday changes are audited.

Singleton settings and feature flags are stable application keys; their values
and rollouts can be changed, but the keys are not deletable. The mobile customer
app listens for public settings changes and refreshes configuration, menu,
product, cart, coupons, and outlet data. It also refreshes these values when
resuming after backgrounding.

## Delivery-zone owner error

The earlier owner-access fix addressed `42501 permission denied for schema app`
when an RLS policy resolved `app.has_permission(...)`. It grants `USAGE` on the
private `app` schema to API roles without exposing that schema through PostgREST;
function grants, signed AAL2 checks, and RLS remain authoritative. That earlier
change was verified locally. The linked hosted project's state was not checked
again for this settings release.

## Migration and hosted state

This checkout contains **65 migration files**. Migration
`20261023135427_settings_crud_audit_and_public_sync.sql` was applied to the
local Supabase stack and passed its SQL/RLS suite. The new
`20261023151817_kitchen_pickup_handoff_code.sql` was applied to the local stack
and passed `npm run db:lint` with no error-level findings. A read-only hosted
query confirmed that this migration is also recorded as applied in
`supabase_migrations.schema_migrations` for the `bitesbox` project. No hosted
migration write was performed in this release.

Mobile source changes pushed to `main` now trigger the signed Android release
workflow automatically; manual dispatch from `main` remains available. Supabase
migration pushes and admin deployments remain separately gated. No local APK
was built.

## Version

Workspace, admin, storefront, and shared-types packages: **1.2.5**. Flutter
source version: **1.2.5+37**. Latest signed Android update published:
**1.2.5+57**. No signed iOS release was run.

## Verification record

Previously recorded local results on 23 October 2026 (before pickup-code sharing):

| Area | Result | Evidence / limitation |
| --- | --- | --- |
| Local migration | Passed | New settings migration applied to local Supabase; no hosted write |
| SQL/RLS tests | Passed: 13 suites, 472 assertion calls in source | `npm run db:test`; includes branch schedule CRUD, tax archive/default guards, outlet archive protections, unauthorized archive refusal, and Realtime publication |
| Database lint | Passed | `npm run db:lint`; no error-level findings; existing warning-level findings remain |
| Admin lint and typecheck | Passed | `npm run admin:lint`, `npm run admin:typecheck` |
| Admin unit tests | Passed: 82 tests | `npm run admin:test`, 10 files |
| Admin browser journey | Passed: 11 tests | `npm run e2e --workspace=@bitesbox/admin`; deterministic local Supabase fake, including outlet edit/archive confirmation |
| Admin build | Passed | `npm run admin:build` with a local placeholder Supabase URL/key |
| Edge Function checks | Passed | `npm run fn:check`, `npm run fn:lint`; Deno lint checked 29 files and Deno format checked 30 |
| Flutter analysis and tests | Passed | `npm run mobile:analyze`, `npm run mobile:test`; 144 tests |
| Android release workflow | Passed | [Run 39981155832](https://github.com/ankitraj6767/bitesbox/actions/runs/39981155832); signed split APKs built and published as 1.2.5+57; public manifest and all ABI download links verified |
| Automatic Android release policy | Implemented | Mobile changes on `main` now trigger `.github/workflows/android-auto-release.yml`; it reruns Flutter analysis/tests and publishes only after they pass. |
| Pickup-code sharing change | Passed in CI | [Run 39978939242](https://github.com/ankitraj6767/bitesbox/actions/runs/39978939242): database migration reset, SQL/RLS suite, generated-type check, Flutter analysis/tests, and CI debug APK all passed. Local Flutter analysis and database lint also passed. Hosted migration history was separately verified read-only through `20261023151817`. |
| Admin deployment | Not dispatched | Separate Vercel Git integration status is unverified |
| Hosted migration | Verified applied | Read-only query of `supabase_migrations.schema_migrations` shows `20261023151817_kitchen_pickup_handoff_code`; no hosted migration write was performed in this release |
| Device/store behavior | Not verified | No physical device or signed store build was run |

See [testing.md](testing.md), [deployment.md](deployment.md), and
[operations-runbook.md](operations-runbook.md) for procedures.
