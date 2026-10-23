# Release status

Last updated: 23 October 2026. This source release adds complete edit/archive
controls for operator-managed settings, with local database and application
verification. No production website or mobile build was published, and no
hosted Supabase migration was applied.

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

This checkout contains **63 migration files**. Migration
`20261023135427_settings_crud_audit_and_public_sync.sql` was applied to the
local Supabase stack and passed its SQL/RLS suite. No hosted migration was
pushed. Hosted migration state for this migration is **unverified**. The last
recorded read-only hosted check before the previous source release reported
history through `20261023114100`; that older observation has not been refreshed
for this release, so migrations after it must be checked before any hosted
deployment.

Supabase deployment and production admin/mobile release workflows remain
manual. This source-only change does not deploy the admin site, apply migrations,
or publish an APK. No production credentials were used for local build checks.

## Version

Workspace, admin, storefront, and shared-types packages: **1.2.2**. Flutter
source version: **1.2.2+15**. This is a source version bump, not a signed mobile
release. No APK was built locally and no signed iOS release was run.

## Verification record

Local results on 23 October 2026:

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
| GitHub workflow for this source-only change | Not run locally | Check the repository Actions page after pushing; no GitHub status is claimed here |
| Hosted migration | Unverified | No hosted inspection or migration write was performed for this release |
| Device/store behavior | Not verified | No physical device or signed store build was run |

See [testing.md](testing.md), [deployment.md](deployment.md), and
[operations-runbook.md](operations-runbook.md) for procedures.
