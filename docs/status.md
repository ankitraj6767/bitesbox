# Release status

Last updated: 23 October 2026. This source release includes the delivery-zone,
kitchen handoff, and settings fixes, plus rider-bound pickup-code sharing. It
bumps workspace/mobile source to **1.2.5 / 1.2.5+37**. The latest recorded signed
Android update remains **1.2.4+36**, built and published by [GitHub Actions run
39974820119](https://github.com/ankitraj6767/bitesbox/actions/runs/39974820119);
the 1.2.5 source has not been published as an Android update. The new pickup-code
migration has not been applied to hosted Supabase. The admin deployment workflow
was not dispatched; any separate Vercel Git integration deployment is unverified.

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
and passed `npm run db:lint` with no error-level findings. No hosted migration
was pushed; hosted state is **unverified**. The last recorded read-only hosted
check before the previous source release reported history through
`20261023114100`; that older observation has not been refreshed. Check hosted
migration history and apply the pending migration before releasing a mobile
client that calls its RPC.

Supabase migration pushes, admin deployments, and Android releases remain manual.
The Android release workflow has not been dispatched for 1.2.5+37, and no local
APK was built. The new migration was applied only to the local Supabase stack;
no hosted database migration or admin deployment was performed.

## Version

Workspace, admin, storefront, and shared-types packages: **1.2.5**. Flutter
source version: **1.2.5+37**. Latest signed Android update published:
**1.2.4+36**. No signed iOS release was run.

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
| Android release workflow | Passed | [Run 39974820119](https://github.com/ankitraj6767/bitesbox/actions/runs/39974820119); built split APKs and published manifest for 1.2.4+36 |
| Pickup-code sharing change | Passed in CI | [Run 39978939242](https://github.com/ankitraj6767/bitesbox/actions/runs/39978939242): database migration reset, SQL/RLS suite, generated-type check, Flutter analysis/tests, and CI debug APK all passed. Local Flutter analysis and database lint also passed. No signed Android release or hosted migration was run. |
| Admin deployment | Not dispatched | Separate Vercel Git integration status is unverified |
| Hosted migration | Unverified | No hosted inspection or migration write was performed for this release |
| Device/store behavior | Not verified | No physical device or signed store build was run |

See [testing.md](testing.md), [deployment.md](deployment.md), and
[operations-runbook.md](operations-runbook.md) for procedures.
