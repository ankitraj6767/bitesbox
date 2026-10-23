# Testing

## Where the risk is

This is a system that takes money, promises food and dispatches a person on a
motorcycle. The tests are weighted towards the failures that cost something real:
a customer charged twice, an order priced from the client, a rider reading another
rider's customer address, a refund larger than the payment, a delivery marked
complete that never arrived.

So the largest suite by far is SQL against a real Postgres with real API roles.
Unit-testing a Dart function that formats a duration is cheap and worth having;
it is not where the risk lives.

```
supabase/tests/      11 suites · 394 assertion calls in source   ← the security boundary
apps/admin/           6 unit files · 67 tests; deterministic Playwright journey
apps/mobile/test/     14 files · see final run record below
supabase/functions/   Deno checks · lint · fmt · logger/provider contracts
schema                db-lint.sh — fails on error-level findings
```

## Backend: SQL suites

```bash
./supabase/tests/run.sh          # every suite
./supabase/tests/run.sh 040      # just the delivery flow
npm run db:test                  # same thing
```

The 394 SQL assertion calls are counted from the checked-in SQL test files. They
were **not executed for this release** because Docker/Colima was unavailable in
the implementation environment. A read-only linked migration check observed two
local migrations pending on 23 October 2026; no migration was pushed. See
[status.md](status.md) for that observation and its limits.

| Suite | Assertions | Covers |
| --- | --- | --- |
| `010_rbac_rls` | 48 | Role/permission boundaries, cross-customer isolation, branch scoping, the role-assignment rank guard |
| `020_order_state_machine` | 20 | Legal edges, guards, direct-write refusal, terminal states |
| `030_pricing_and_coupons` | 40 | Server pricing, coupon eligibility, quantity limits, serviceability |
| `040_delivery_flow` | 48 | Dispatch → pickup → OTP → delivered, timestamped assignment-scoped location, rider scoping, payout |
| `050_payments_and_idempotency` | 15 | Placement idempotency, webhook dedupe counters, unpaid-order isolation |
| `060_refunds` | 27 | Refundable balance, approval separation, ledger settlement |
| `070_rider_lifecycle` | 64 | Onboarding chain, document review, self-promotion refusal, the staff read surface |
| `080_campaigns_and_reviews` | 34 | Audience resolution, opt-out honouring, review moderation |
| `090_read_surfaces` | 65 | Every client-callable read RPC actually executes, as a role allowed to call it |
| `100_group_orders` | 10 | Invite privacy, membership checks, host authority, server-validated merge and participant-cart clearing |
| `110_staff_mfa_and_location` | 23 | Signed AAL2 checks, customer exclusion, RBAC after MFA, safe defaults, and alert access |

### Why 090 exists

The first eight suites test *behaviour*: that the right person can do the right
thing and nobody else can. They are the valuable ones, and they missed five
functions that threw on every single call.

A plpgsql body is only resolved when it runs, so a query that cannot possibly
execute installs cleanly through `supabase db reset` without a murmur. If no test
ever calls the function, nothing notices until a user does.

`090` is duller than the others by design. It calls every read surface as a role
permitted to call it and asserts only that it executes. Where the shape carries
meaning — `search_suggestions` ordering by popularity,
`branch_ordering_state` answering whether orders are being taken — it checks that
too, because three empty lists are indistinguishable from a broken screen.

It also pins the boundaries it found on the way: `my_session` and
`has_permission` are authenticated-only and a guest is refused, and a manager
cannot read the audit trail.

### Why not pgTAP

pgTAP is available on a local stack but not on the hosted project. These tests must
be runnable against both — a policy that passes locally and fails on production is
the exact failure worth catching — so the harness is 345 lines of plain SQL in
schema `tap` with no extension dependency.

### The harness

`supabase/tests/_harness.sql` provides:

```sql
tap.as_user(uuid)      -- become that user: sets role authenticated + JWT claims
tap.as_anon()          -- become a guest
tap.as_service()       -- become service_role
tap.reset()            -- back to the DB owner

tap.ok(bool, label)
tap.eq(actual, expected, label)
tap.throws(sql, error_code, label)
tap.no_throw(sql, label)
tap.visible_count(table, label) -- rows this role can see

tap.remember(key, value) / tap.recall / tap.recall_uuid / tap.recall_numeric
tap.seed('customer_a')          -- stable ids for every seeded actor
tap.seed_order(3)               -- the nth seeded order, date-independent
tap.suite(name) / tap.note / tap.done
```

Each suite runs inside `begin … rollback`, so the seed is untouched and suites
cannot leak fixtures into one another. The harness raises on the first failed
assertion and psql runs with `ON_ERROR_STOP=1`, so a failure is a non-zero exit.

`tap.remember` uses transaction-scoped GUCs rather than a temp table, so it works
inside the same rolled-back transaction as everything else.

### Impersonation is the whole point

`tap.as_user` sets `role authenticated` **and** `request.jwt.claims`, so
`auth.uid()`, RLS and `app.has_permission` all behave exactly as they do for a real
API call. A test that runs as the table owner proves nothing about RLS.

Three things this taught us, all of which bite:

**`tap.reset()` is the DB owner.** It bypasses RLS and carries no JWT, so
`app.has_permission` returns false. Asserting OWNER-role behaviour needs
`tap.as_user(tap.seed('owner'))`, not `reset()`.

**An UPDATE with no matching policy affects zero rows and does not raise.** So the
self-promotion tests assert the values are unchanged, not that an exception was
thrown. Asserting `throws` there would silently pass forever.

**Codes come from the exception HINT.** `app.fail` puts the stable code in `HINT`
and the customer-safe copy in the message, so `tap.throws(sql, 'REFUND_NOT_ALLOWED')`
matches on the code and does not break when the wording improves.

### Never fixture on a generated value

Three suites broke overnight. Order numbers embed the date they were created —
`BB-BKP01-260820-00003` — and the fixtures matched the whole literal:

```sql
select tap.remember('placed', id::text) from public.orders
  where order_number = 'BB-BKP01-260819-00003';   -- ← fails tomorrow
```

The lookup returned null, `tap.remember` stored null, and the failure surfaced
three statements later as a not-null violation on
`verification_codes.subject` — a column nobody was thinking about. That is the
worst kind of test failure: red for a reason unrelated to the thing being tested,
which is how a team learns to ignore a red build.

`tap.seed_order(n)` resolves on the trailing sequence instead, which is stable:

```sql
select tap.remember('placed', tap.seed_order(3)::text);   -- ORDER_PLACED, COD
```

Suite `040` also now asserts the fixture resolved before using it, so the next
occurrence of this class of problem fails on the line that caused it.

The general rule: fixture on something the seed controls (a hard-coded uuid, a
status, a sequence position), never on something the database generated from
`now()`.

### Fixtures

The suites use the seeded outlet, menu, users and orders. Two exceptions:

**Test-owned coupons.** `TESTFLAT50` and `TESTFREEDEL` exist for the happy path
because the seeded coupons are weekend-only, evening-only or first-order-only —
a suite built on them would fail at 7pm, or on a Saturday. The seeded ones are kept
for the negative assertions, where their restrictions are the point.

**Planted verification codes.** Codes are stored only as a salted hash, so a test
cannot read the real one. `040` inserts a `PICKUP_CODE` row with a known salt —
the same operation that puts a code on a kitchen ticket — and then rewrites the
generated `DELIVERY_OTP` hash, which is the equivalent of the customer reading it
out. The delivery OTP is deliberately *not* planted upfront, so the suite still
proves that pickup is what issues it.

## Admin dashboard

```bash
npm run test --workspace=@bitesbox/admin
```

Vitest with jsdom. The release suite contains **6 files and 67 tests**;
`npm run test --workspace=@bitesbox/admin` passed all 67 on 23 October 2026.

| File | Tests | Covers |
| --- | --- | --- |
| `src/lib/utils.test.ts` | 26 | `money`, `compactNumber`, `percent`, `dateOnly`, `elapsed`, `humanise`, `initials`, `storageUrl`, `csvEscape`, `toCsv` |
| `src/lib/errors.test.ts` | 10 | `normaliseError`, `errorMessage` — code extraction from PostgREST and Edge shapes, customer-safe copy |
| `src/lib/navigation.test.ts` | 13 | `visibleNavigation` permission filtering, `NAV_GROUPS` integrity |
| `src/components/ui/badge.test.tsx` | 14 | `orderStatusTone` / `paymentStatusTone` / `refundStatusTone` mapping, `OrderStatusBadge`, `Badge`, `FoodTypeMark` |
| `src/lib/mfa-policy.test.ts` | 3 | Back-office AAL2 routing, customer exemption, safe next path |
| `src/lib/telemetry/scrub.test.ts` | 1 | PII, credentials, request content, and image redaction |

`toCsv` and `csvEscape` are tested because CSV export is where a comma in a
customer's address quietly corrupts a finance report.

`src/test/setup.ts` adds jest-dom, cleanup between tests, a
`NEXT_PUBLIC_SUPABASE_URL` stub, and `matchMedia` / `ResizeObserver` polyfills that
jsdom lacks.

The dashboard's real logic is server actions calling RPCs, and the RPC behaviour is
already proven by the SQL suites against a real database. Mocking Supabase to
re-assert it in TypeScript would test the mock. So the unit tests here cover the
pure functions and presentational mapping, and `npm run build` covers the rest by
type-checking every page against the generated database types.

The Playwright browser suite runs separately with
`npm run e2e --workspace=@bitesbox/admin`. It starts a local deterministic Supabase
Auth/REST fake and covers valid and invalid staff login, refund approval, missing
refund permission, and the AAL1 challenge gate. It uses no hosted account and does
not call the Razorpay gateway.

### Lint

`next lint` is deprecated and prompts interactively when it finds no config, which
hangs CI. `apps/admin/eslint.config.mjs` bridges `next/core-web-vitals` and
`next/typescript` through `FlatCompat`, and the script is plain `eslint .`.

Switching to it surfaced nine previously-invisible unused imports across seven
pages, all now removed.

## Flutter

```bash
cd apps/mobile && flutter test
```

The release branch has 14 test files. `flutter test --reporter compact` passed
**139 tests** on 23 October 2026.

| File | Covers |
| --- | --- |
| `test/core/session_test.dart` | `AppRole`, `AppSession.guest`, `AppSession.fromJson`, shell selection per role, `needsProfileSetup`, `UserProfile` |
| `test/core/app_error_test.dart` | `AppError.from`, error classification, `ErrorCodes` |
| `test/shared/format_test.dart` | `money`, `elapsed`, `duration`, `distance`, `humanise`, `relative`, `until`, `maskPhone`, `smartDateTime` |
| `test/features/delivery_models_test.dart` | `DutyState`, `RiderProfile`, `DeliveryAssignment`, `RiderDashboard`, `RiderEarnings`, `PickupResult`, `DeliveryHistoryEntry`, plus onboarding: `RiderDocumentType`, `RiderDocumentStatus`, `RiderDocument`, `RiderOnboarding` |
| `test/features/rider_widgets_test.dart` | `RiderPrimaryButton`, `DutyStatePill`, `RiderStat`, `RiderWaypoint`, `LiveMap` fallback |
| `test/core/api_client_test.dart` | Supabase filters, sort order, limits, localized policy documents and FAQs |
| `test/core/update_test.dart` | Version comparison and compatible release artifact selection |
| `test/features/account_notifications_test.dart` | Notification ownership, persisted read state and channel isolation |
| `test/features/group_order_models_test.dart` | Group snapshots, member contributions, configured dishes and malformed optional fields |
| `test/features/account_profile_repository_test.dart` | Profile updates send only explicitly changed notification channels |
| `test/features/profile_screen_test.dart` | Preference hydration, isolated marketing consent, channel save, reload, loading, and recovery after errors |
| `test/features/delivery/location_fix_policy_test.dart` | OS capture timestamp freshness, ordering, throttling, and no stale replay |
| `test/core/telemetry_scrub_test.dart` | Mobile Sentry event redaction and safe route context |
| `test/integration/order_and_rider_flow_test.dart` | Deterministic Supabase-client contract for order placement/status and rider pickup/completion without GPS |

`shell selection` is the one worth calling out: it asserts which shell each role
lands in, so a customer cannot be routed into the kitchen UI by a role-mapping
change. The backend would refuse the calls anyway, but a customer seeing a kitchen
screen is still a bug.

Two onboarding assertions are there for specific mistakes that are easy to make:

**Expiry beats an approved review.** `RiderDocument.effectiveStatus` returns
`expired` for a document that was approved last year and has since lapsed. A
lapsed licence is not a valid one whatever the reviewer said at the time.

**Submitted is not approved.** `approvedRequiredCount` counts only `APPROVED`, so
the progress bar cannot run ahead of the reviewer and tell a rider they are ready
when nobody has looked yet.

There is also a fallback test for an unknown document type: the server enum can
gain a value before the app ships, so `RiderDocumentType.labelFor('VOTER_ID')`
returns "Voter Id" rather than crashing or showing a raw enum string.

Two gotchas worth knowing before adding more:

**`find.bySemanticsLabel` does not match a merged label.** When
`Semantics(label: …)` merges with descendant text, the finder fails even though a
screen reader announces the label correctly. Assert
`tester.widget<Semantics>(…).properties.label` instead.

**Duration assertions must tolerate truncation.** 24 minutes formats as "23 min"
when the underlying value is 23.6. Assert the range or the formatter's contract,
not a literal.

`LiveMap` is covered by its fallback path: with no Maps key it renders a readable
panel with an "Open in maps" hand-off, and the test asserts that rather than trying
to instantiate a platform view in a headless test.

### The app did not compile

Worth recording, because it is what these tests exist to prevent recurring.
`flutter analyze` reported **107 errors** at the start of this work — the app was
not buildable. Root causes:

- `Feedback` in `lib/shared/feedback.dart` collided with Flutter's own `Feedback`
  from `material.dart`. Renamed repo-wide to `AppFeedback` across 29 files.
- `CheckoutQuote.isPickup` was referenced and did not exist.
- `kitchen_providers.dart` imported `customer_providers` with a `show` clause that
  omitted a symbol it used.
- `product_sheet.dart` called protected `setState` from sibling widgets.
- `main.dart` used the removed `anonKey:` parameter.
- 18 deprecated `RadioListTile` `groupValue`/`onChanged` usages.

`flutter analyze` is now in CI and treats infos as findings, so it is a stricter
gate than "it compiles".

## Edge Functions

```bash
npm run fn:check     # deno check on every index.ts
npm run fn:lint      # deno lint && deno fmt --check
```

## Schema lint

```bash
npm run db:lint      # scripts/db-lint.sh
```

`supabase db lint` prints its findings and exits 0 whatever their severity. That is
reasonable for the stylistic majority, and it is how two functions that threw on
every call scrolled past unnoticed.

`scripts/db-lint.sh` wraps it and fails on **error**-level findings only. Warnings
stay informational, because the legitimate ones here — `require_permission` is
STABLE but calls a VOLATILE raise, unused loop variables in the code generators —
would otherwise get the whole check disabled within a week.

This is the only tool in the chain that looks inside a function body before a user
does.

All 16 functions type-check (`supabase/functions/` has 17 directories; `_shared`
holds no entry point). `supabase/functions/deno.json` sets
`fmt.indentWidth: 4` to match the actual style and excludes the generated
`_shared/database.types.ts`.

The standard RPC façades stay covered by SQL authorization tests. Deno tests cover
the new logger scrubber/failure behavior and deterministic Razorpay helper
contracts: valid/invalid signatures, exact paise and currency, bounded safe GET
retry, and no automatic replay of ambiguous money-moving POST requests. SQL tests
cover database idempotency, duplicate webhook counting, and out-of-order refund
settlement. These are local fakes and cryptographic fixtures; CI never performs a
real charge or refund.

## Full sweep

```bash
npm run verify        # secrets, functions, admin, mobile
npm run verify:db     # schema lint + SQL suites
```

`verify` runs: `check-secrets` → `fn:check` → `fn:lint` → `admin:lint` →
`admin:typecheck` → `admin:test` → `admin:build` → `mobile:analyze` →
`mobile:test`. It needs no database. `verify:db` needs the local stack up. CI also
runs the Deno logger/provider contract tests and the separate Playwright journey.

On 23 October 2026, `npm run verify` passed end to end with placeholder Supabase
configuration. A separate `deno test --allow-env _shared/logger_test.ts
_shared/razorpay_test.ts` passed 4 tests across 5 steps, and
`npm run e2e --workspace=@bitesbox/admin` passed all 5 browser tests. The attempted
`npm run db:test` could not install its harness because the local Supabase stack
was not running; Docker/Colima was unavailable. No SQL suite or generated database
type comparison is reported as locally verified.

## CI

`.github/workflows/ci.yml`, five parallel jobs on every push to `main`, every PR,
and on demand:

| Job | Does |
| --- | --- |
| **Database** | `supabase start` → `db reset` → `db-lint.sh` → SQL suites → assert the committed types match the schema |
| **Edge Functions** | `deno check` each entry, `deno lint`, `deno fmt --check`, logger and Razorpay contract tests |
| **Admin dashboard** | `npm ci` → lint → typecheck → vitest → Playwright staff/refund journey → `next build` |
| **Mobile app** | `flutter pub get` → `analyze` → `test` → debug APK build |
| **Secret scan** | `scripts/check-secrets.sh` |

Two details that matter:

The Database job runs `supabase db reset` against an **empty** database, so a
migration that only works against an already-migrated one fails there rather than
on a production deploy. It then diffs freshly generated types against the committed
`database.types.ts` and fails if they drift — otherwise the admin app compiles
against a contract the database no longer offers.

The Mobile job builds a debug APK. Unit tests cannot see a broken manifest,
a Gradle misconfiguration or a missing signing block; the build can.

`dart format --set-exit-if-changed` is deliberately **not** enforced. It targets 80
columns and this codebase is laid out wider; widget trees read better with the
existing breaks than with reflowed ones. `deno fmt --check` *is* enforced, because
`deno.json` was aligned to the real style first.

## Not covered

Stated plainly rather than implied:

- **No physical-device tracking verification in CI.** Permission revocation,
  lock-screen/background collection, battery saver, notification behavior, and
  app termination/restart need Android and iOS devices. Follow the plan below.
- **No live backend mobile integration test.** The customer and rider flow tests
  use an HTTP fake with the Supabase client's real transport contract; they do not
  prove hosted credentials, RLS, or device behavior.
- **No load testing.** Index choices are reasoned about (partial indexes on the hot
  reconciliation and dispatch queries) but not measured under load.
- **No live Razorpay test-mode call in CI.** Provider helper contracts run against
  a deterministic fake HTTP transport and never move money.
- **No penetration test.** The security claims in [security.md](security.md) are
  what the SQL suites prove, not a third-party assessment.

## Device validation plan (manual, before a store release)

Use test accounts, test orders, and a development/staging backend. Never use a
real customer's delivery. Record OS version, device model, app build, permission
choice, and whether the customer saw an accurately stale state.

**Android (supported target devices):** accept an assignment; start sharing while
the app is visible; confirm the persistent notification and a recent customer
point; switch to navigation, background the app, and lock the screen; verify fresh
capture times continue. Then disable location services, revoke permission in
Settings, deny notifications on Android 13+ and verify the foreground service is
still listed in Task Manager (its notice may be absent from the notification
drawer), enable battery saver/Doze, lose and
restore network, reassign the delivery, complete/cancel it, sign out, and force
stop/relaunch. Confirm location stops or becomes stale, no old fix is replayed,
the stop marker is reconciled after resume, and pickup/completion remain usable
without GPS. Do not grant “Allow all the time”; the implementation is designed
for a foreground-started location service and visible notification.

**iOS (supported iPhone versions):** accept an assignment and consent while the
app is foregrounded; verify the system location indicator; switch to Apple/Google
Maps, background and lock the phone, then confirm capture times continue while
the OS permits When In Use background updates. Test While Using permission denied
or revoked, Precise Location off, Location Services off, Low Power Mode, network
loss/recovery, process termination/restart, reassignment, completion, cancellation,
and sign-out. Confirm unavailable/stale states are clear and delivery actions
remain available. If the OS stops updates under When In Use authorization, do not
upgrade to Always by default; surface the stale state and review current App
Store/Core Location policy before any authorization change.

No Android/iOS device validation was performed for this release in CI or the
implementation environment.
