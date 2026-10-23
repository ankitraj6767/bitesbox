# Release status

Last updated: 23 October 2026. The owner delivery-zone access fix and source
version bump are on `main` in implementation commit `a1392a4`. The production
admin site was not replaced, no Android update was published, and no hosted
Supabase migration was applied.

## Delivery-zone owner error

The owner role and `branch.manage` permission were present. Read-only hosted
Postgres logs showed `42501 permission denied for schema app` on delivery-zone
updates. The RLS policy calls `app.has_permission(...)`; Postgres requires API
roles to have schema `USAGE` to resolve that helper while evaluating the policy.
The application had only granted function execution, which was insufficient. The
fix grants schema `USAGE` to `anon` and `authenticated`; it does not add `app` to
PostgREST's exposed schemas, and existing function grants, signed AAL2 checks, and
RLS still enforce access. The admin error copy now describes a database
authorization failure without incorrectly telling an owner that their outlet
assignment changed.

## Migration and hosted state

The repository contains **62 migration files**. Migration
`20261023132322_grant_rls_helper_schema_usage.sql` is applied and tested on the
local Supabase stack. Read-only inspection of the linked hosted project showed its
applied migration history current through `20261023114100` before this change;
the new migration is **pending remotely**. No hosted migration was pushed by this
work. The owner edit will work against that hosted project after the pending
migration is applied.

Matching pushes run Supabase migration verification, but the hosted deploy job is
manual-only. The GitHub Vercel admin and Android release jobs are also
manual-only. A source push to `main` therefore does not apply migrations or publish
APKs. The normal CI workflow still runs on pushes to `main`. Vercel Git integration
is connected to the repository; the Vercel ignore command skips this source-only
commit (marked `[source-only]`) while preserving normal deployment behavior for
subsequent commits.

## Version

Workspace, admin, storefront, and shared-types packages: **1.2.1**. Flutter source
version: **1.2.1+14**. This is a source version bump, not a signed release. No APK
was built locally; GitHub CI's debug APK check passed. No signed iOS build was run.

## Verification record

Local and GitHub results on 23 October 2026:

| Area | Result | Evidence / limitation |
| --- | --- | --- |
| Local migration | Passed | New grant applied to local Supabase; hosted project unchanged |
| SQL/RLS tests | Passed: 12 suites, 433 assertions | `npm run db:test`; includes owner AAL2 delivery-zone update and schema-usage checks |
| Database lint | Passed | `npm run db:lint`; warning-level findings remain |
| Admin lint and typecheck | Passed | `npm run admin:lint`, `npm run admin:typecheck` |
| Admin unit tests | Passed: 76 tests | `npm run admin:test`, 9 files |
| Admin browser journey | Passed: 10 tests | `npm run e2e --workspace=@bitesbox/admin`; owner delivery-zone create/edit/pause/delete covered with deterministic local fakes |
| Admin build | Passed | `npm run admin:build` with placeholder Supabase configuration; no hosted credentials |
| GitHub CI | Passed: 6 jobs | [Run 39962577075](https://github.com/ankitraj6767/bitesbox/actions/runs/39962577075), commit `a1392a4` |
| Supabase workflow | Verification passed; deploy skipped | [Run 39962577056](https://github.com/ankitraj6767/bitesbox/actions/runs/39962577056); no hosted write occurred |
| Vercel Git deployment | Canceled | Source-only marker prevented publishing a deployment for commit `a1392a4` |
| Hosted migration | Pending | Requires a separately authorized workflow dispatch and environment review |
| Device/store behavior | Not verified | No physical device or signed store build was run |

## Remaining operator step

After review, an operator with access to the protected GitHub environment must
explicitly dispatch `Deploy Supabase` to apply the pending migration to the
intended environment. Verify the migration list and retry delivery-zone editing
after deployment. The source push alone does not fix the live database. Do not
dispatch the Android or admin deployment workflows unless those releases are
separately intended.

See [testing.md](testing.md), [deployment.md](deployment.md), and
[operations-runbook.md](operations-runbook.md) for procedures.
