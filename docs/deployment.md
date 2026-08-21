# Deployment

## Environments

| | Database | Admin | Mobile |
| --- | --- | --- | --- |
| **local** | `supabase start` on Docker | `next dev` :3000 | `env/local.json` |
| **development** | hosted project `kqsbzafxntsksalchlgc` | Vercel preview | `env/dev.json` |
| **staging** | separate hosted project | Vercel preview | `env/staging.json` |
| **production** | separate hosted project | Vercel production | `env/prod.json` |

Staging and production are separate Supabase projects, not schemas in one.
Sharing a project means a migration under test can lock a table a real restaurant
is taking orders through.

## Prerequisites

```
Docker (or colima)   local Supabase stack
Node                 >= 20.11.0
Supabase CLI         >= 2.x
Deno                 v2.x        Edge Functions
Flutter              3.35.x      mobile
Java                 17          Android builds
```

## Local setup, from nothing

```bash
git clone <repo> && cd bitesbox
npm install

cp .env.example .env                       # fill in what you have

# Backend
npm run db:start                           # supabase start
npm run db:reset                           # migrations + seeds, ~3 min
npm run db:test                            # 8 suites, expect 8 passed

# Admin
cd apps/admin && cp ../../.env.example .env.local
npm run dev                                # http://localhost:3000

# Mobile
cd apps/mobile && flutter pub get
flutter run --dart-define-from-file=env/local.json
```

`db:reset` applies all 32 migrations to an empty database and then the seven seed
files in order. It is the only supported way to get a working local database —
there is no snapshot to restore.

Seeds live in `supabase/seeds/`, not a single `seed.sql`:

```
00_helpers.sql          seeding helpers
10_organisation.sql     brand, branch, roles, permissions, policies, settings
20_menu.sql             categories, products, modifiers, availability
30_content_promotions.sql  banners, coupons, CMS pages
40_users.sql            staff, riders, customers with real role grants
50_orders.sql           orders across every status, payments, refunds
90_finish.sql           advances sequences past the seeded rows
```

`90_finish.sql` matters: without it the first real support ticket collides with a
seeded `ticket_number`, which is a confusing failure to debug on a fresh machine.

## Migrations

Forward-only. There are no down migrations, because a down migration against a
database holding real orders is a fiction — you restore from a backup instead.

```bash
supabase migration new describe_the_change     # creates a timestamped file
npm run db:reset                               # verify from empty
npm run db:test                                # verify behaviour
npm run db:types                               # regenerate both type files
```

`db:types` writes `packages/shared-types/src/database.types.ts` and copies it to
`supabase/functions/_shared/database.types.ts`. CI fails if the committed file
drifts from the schema.

### Two rules learned the hard way

**A new enum value needs its own migration file.** Postgres cannot use an enum
value in the same transaction that adds it. `20260819085000_notification_events.sql`
exists solely to add three `notification_event` values so the next migration can
reference them.

**Storage buckets belong in SQL.** `config.toml` provisions buckets for
`supabase start` only. `supabase db push` does not read it, so buckets declared
there alone are absent on every hosted project — and every upload the RLS policies
were written for fails with "Bucket not found". They are created in
`20260819090000_security_and_storage_hardening.sql` instead.

### Pushing to a hosted project

```bash
supabase link --project-ref kqsbzafxntsksalchlgc
supabase migration list        # read this before pushing
supabase db push
```

`migration list` shows local versus remote, which is the record of what a given
push will do. Read it. `db push` against a live restaurant is irreversible.

## CI

`.github/workflows/ci.yml` — five parallel jobs on every push to `main`, every PR,
and on demand. Concurrency is grouped per ref with `cancel-in-progress`, so a new
push supersedes an in-flight run.

| Job | Timeout | Does |
| --- | --- | --- |
| Database | 25 min | `supabase start` → `db reset` → `db lint --level warning` → SQL suites → assert generated types are current |
| Edge Functions | 15 min | `deno check` each entry point, `deno lint`, `deno fmt --check` |
| Admin dashboard | 20 min | `npm ci` → lint → typecheck → vitest → `next build` |
| Mobile app | 25 min | `pub get` → `analyze` → `test` → debug APK |
| Secret scan | 10 min | `scripts/check-secrets.sh` |

The Database job starts the stack with
`--exclude studio,imgproxy,edge-runtime,logflare,vector` — none of them are needed
to run migrations and SQL tests, and excluding them takes minutes off every run.

The admin build uses placeholder `NEXT_PUBLIC_*` values. The publishable key is
designed to ship in a client and is useless without a session that passes RLS, so
a placeholder is enough to compile.

See [testing.md](testing.md#ci) for what each gate is protecting.

## Deploying Supabase

`.github/workflows/deploy-supabase.yml`. Triggered by a push to `main` touching
`supabase/migrations/**`, `supabase/functions/**` or `config.toml`, or manually
with a `staging` / `production` choice.

Migrations and functions deploy **together**, because a function almost always
depends on a schema change that must land first.

```
verify   supabase start → db reset → SQL suites     (throwaway database)
   ↓
deploy   link → migration list → db push
         → secrets set → functions deploy
```

The `verify` job re-runs what CI already ran. A migration is irreversible against
a live database, so it is worth twenty minutes to confirm it applies to an empty
one first.

Secrets are set **before** the functions that read them are deployed, so a new
function never starts against missing configuration. Unset secrets are skipped
with a log line rather than pushed as empty strings.

`razorpay-webhook` deploys with `--no-verify-jwt`; everything else keeps JWT
verification on.

### Gate it

Configure `staging` and `production` as GitHub Environments with **required
reviewers**. The `deploy` job declares `environment:`, so with reviewers set a
schema change to a live restaurant becomes a deliberate act rather than a side
effect of merging.

Required secrets per environment:

```
SUPABASE_ACCESS_TOKEN     SUPABASE_PROJECT_REF     SUPABASE_DB_PASSWORD
RAZORPAY_KEY_ID           RAZORPAY_KEY_SECRET      RAZORPAY_WEBHOOK_SECRET
FCM_PROJECT_ID            FCM_SERVICE_ACCOUNT
SMS_PROVIDER              SMS_API_KEY              SMS_SENDER_ID
EMAIL_PROVIDER            EMAIL_API_KEY            EMAIL_FROM
SENTRY_DSN
```

### Scheduled jobs

`pg_cron` registers three schedules from within the migrations, so they exist as
soon as the schema does. Nothing extra to configure after a deploy.

```
bitesbox_minute   * * * * *      run_scheduled_jobs('MINUTE')
bitesbox_hourly   5 * * * *      run_scheduled_jobs('HOURLY')
bitesbox_daily    30 3 * * *     run_scheduled_jobs('DAILY')   -- 09:00 IST
```

`run_scheduled_jobs(cadence)` is the orchestrator. Three schedules instead of
fifteen means one place to look at when something has not run.

| Cadence | Jobs |
| --- | --- |
| MINUTE | `restore_availability`, `auto_resume_branches`, `activate_scheduled_orders`, `expire_assignments`, `detect_delays`, `expire_unpaid_orders`, `launch_scheduled_campaigns` |
| HOURLY | `complete_delivered_orders`, `expire_coupons`, `abandoned_carts`, `unreconciled_payments`, `settle_running_campaigns` |
| DAILY | `daily_reset`, `rider_document_expiry`, `prune_location_history` |

The daily run is at 03:30 UTC, which is 09:00 IST — safely before the breakfast
service.

Registration is wrapped in an exception handler: if `pg_cron` is unavailable the
migration logs a notice instead of failing, and the `scheduled-jobs` Edge Function
becomes the driver. It requires the service role key in the `Authorization`
header, and `run_scheduled_jobs` itself refuses anyone who is not the service role
or an OWNER, so a signed-in user cannot trigger the job runner.

Every run is recorded in `job_runs` with status, duration and error, and
`app.run_job` catches per-job failures so one broken job does not abort the whole
cadence.

### Razorpay webhook

Point Razorpay at:

```
https://<project-ref>.supabase.co/functions/v1/razorpay-webhook
```

Subscribe to: `payment.captured`, `payment.authorized`, `payment.failed`,
`order.paid`, `refund.created`, `refund.processed`, `refund.failed`,
`refund.speed_changed`.

Set the webhook secret to match `RAZORPAY_WEBHOOK_SECRET`. Deliveries with a bad
signature get 401 and are not retried; a valid delivery whose handler fails gets
200 and is surfaced through `job_flag_unreconciled_payments` instead of retried
forever. See [payment-flow.md](payment-flow.md#razorpay-webhook).

## Deploying the admin dashboard

Vercel's Git integration is the usual route. `.github/workflows/deploy-admin.yml`
exists for the case where deployment should be gated on CI passing rather than on
a push landing — the safer default for a dashboard that can cancel orders and
issue refunds.

It skips itself entirely when `VERCEL_TOKEN` is absent, so a fork does not carry a
permanently red workflow.

```
guard (VERCEL_TOKEN set?) → npm ci → lint + typecheck + test
  → vercel pull → vercel build → vercel deploy --prebuilt
```

Secrets: `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`.
Environment variables set in Vercel: `NEXT_PUBLIC_SUPABASE_URL`,
`NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_SITE_URL`,
`NEXT_PUBLIC_APP_ENV`, and `SUPABASE_SERVICE_ROLE_KEY` for server actions.

`SUPABASE_SERVICE_ROLE_KEY` must **not** carry a `NEXT_PUBLIC_` prefix. That
prefix is what puts a value in the browser bundle.

## Releasing the mobile app

`.github/workflows/release-mobile.yml`, `workflow_dispatch` only. A store build is
a decision, not a consequence of merging.

For direct-distributed Android builds, `.github/workflows/android-auto-release.yml`
is the automatic channel. It runs on relevant pushes to `main`, builds ABI-split
APKs, publishes a versioned manifest to the public `app-releases` Supabase bucket,
and the installed app checks that manifest on launch. See
`docs/android-auto-updates.md` for the required signing and service-role secrets.

Inputs: `target` (staging / production) and `artefact` (appbundle / apk / both).

```
setup Java 17 + Flutter
  → assemble env/build.json from secrets
  → assert SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are non-empty
  → restore the keystore from ANDROID_KEYSTORE_BASE64
  → pub get → analyze → test
  → build appbundle / apk
  → upload artefact (30-day retention)
  → delete build.json, key.properties and the keystore
```

The env assertion is there because a signed release that cannot reach the backend
is worse than a failed build — it reaches a store before anyone notices.

`analyze` and `test` run again here. A release must not be the first time these
run against the code being shipped.

Credentials are removed in an `if: always()` step. The runner is ephemeral, but
relying on that is a habit worth not having.

### Configuration

Everything reaches the app at compile time through `--dart-define-from-file`.

`env/dev.json` and `env/local.json` are committed because they hold only the
publishable Supabase key. `env/staging.json` and `env/prod.json` are **not** —
copy the `.example` files on the machine or runner that produces the build.

| Key | Required | Absent means |
| --- | --- | --- |
| `APP_ENV` | yes | Defaults to `development` |
| `SUPABASE_URL` | yes | Startup assertion fails |
| `SUPABASE_PUBLISHABLE_KEY` | yes | Startup assertion fails |
| `RAZORPAY_KEY_ID` | production | Online payment hidden; COD still works end to end |
| `GOOGLE_MAPS_KEY` | no | Embedded maps replaced by a hand-off to the phone's maps app |
| `SENTRY_DSN` | no | Crash reporting off |
| `FIREBASE_*` | no | Push off; updates still arrive over Realtime and the in-app inbox |

Each optional key degrades to something usable rather than to a broken screen.
That is what makes a build without a Maps key or an FCM credential still worth
shipping to a test device.

### Android signing

```
ANDROID_KEYSTORE_BASE64      base64 of the upload keystore
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

`android/app/build.gradle.kts` reads `android/key.properties` for release signing
and falls back to the debug config when it is absent, so a local debug build
works with no keystore. `minSdk 23`, R8 enabled with `proguard-rules.pro`, and a
debug `applicationIdSuffix` so debug and release can coexist on one device.

The Maps key reaches Android through a Gradle property
(`-PgoogleMapsKey=…`) into the manifest placeholder, not through a dart-define —
the manifest is read before Dart starts.

### iOS

The `ios` job is scaffolded and guarded: it runs only when
`IOS_DIST_CERTIFICATE_BASE64` is set, so it does not sit permanently red while
signing is unconfigured.

To enable it you need an Apple Developer account, a distribution certificate, a
provisioning profile, and `ios/ExportOptions.plist` committed with your team id.

iOS Maps is the one setting that cannot travel as a dart-define: the SDK needs its
key before Dart starts. `AppDelegate.swift` calls
`GMSServices.provideAPIKey` from the `GMSApiKey` Info.plist entry, which resolves
`$(GOOGLE_MAPS_KEY)` from `ios/Flutter/Maps.xcconfig` — git-ignored, with a
committed `.example`. The workflow writes it from a secret at build time.

Podfile platform is iOS 15.0, required by the Maps SDK.

### No build flavors

Environments select configuration through `--dart-define-from-file`, not Gradle
product flavors or Xcode schemes. Flavors would need Xcode scheme changes that
cannot be made reliably by editing files, and the dart-define route gives the same
separation with one artefact pipeline.

## Deploy order

For a change that spans layers:

```
1. migrations      the schema must exist before anything calls it
2. Edge Functions  they depend on the schema
3. admin dashboard it depends on both
4. mobile app      last, because a store review takes days
```

Which means schema changes must be backwards compatible for at least one release.
An old app version will be in someone's hand for weeks after a deploy. Adding a
column is safe; removing one that a shipped build reads is not.

## Rollback

| Layer | How |
| --- | --- |
| Migrations | No down migrations. Restore from a Supabase PITR backup, or write a forward migration that reverses the change. |
| Edge Functions | `supabase functions deploy <name>` from the previous commit. |
| Admin | Promote the previous Vercel deployment. Instant. |
| Mobile | Halt the staged rollout in Play Console. A shipped build cannot be recalled. |

The asymmetry is the reason the deploy order runs schema-first and mobile-last.

## Verification after a deploy

```bash
supabase migration list                    # remote matches local
```

Then, against the deployed project:

- a guest can load the menu (this is what the `anon` grant fix was for)
- a customer can add to cart and get a quote
- a test-mode Razorpay payment captures and the order reaches `ORDER_PLACED`
- the webhook shows a `payment.captured` row in `payment_events` with
  `signature_verified = true`
- the kitchen queue shows the order
- a rider can go on duty and receive an assignment
- the admin dashboard loads with a real staff login

The webhook check is the one people skip. A payment that captures by callback and
never by webhook works, looks fine, and quietly accumulates unreconciled rows.
