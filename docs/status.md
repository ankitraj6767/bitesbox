# Status

Last verified: 20 August 2026, against a clean `supabase db reset`.

## Where it stands

Every layer is implemented and verified end to end. Nothing ships as a stub: there
are no TODO markers, no "coming soon" screens, no mock payment path and no
simulated tracking. Where a feature depends on a credential that is not configured
— Maps, FCM, Razorpay — it degrades to something usable and says so, rather than
showing a broken screen.

```
Backend      35 migrations · 85 tables · 158 RLS policies · 95 client RPCs
Edge         13 functions, all type-checked
Admin        29 pages
Mobile       83 Dart files · 31 screens · 3 role shells
Tests        330 SQL assertions · 63 admin · 113 Flutter
CI           5 jobs on every push, 3 deploy workflows
Docs         10 documents
```

## Verification

All green as of the date above:

```
supabase db reset                           35 migrations, exit 0
./supabase/tests/run.sh                     9 passed, 0 failed
npm run db:lint                             no error-level findings
npm run test --workspace=@bitesbox/admin    4 files, 63 tests
npm run lint --workspace=@bitesbox/admin    exit 0
npm run typecheck --workspace=@bitesbox/admin  exit 0
npm run build --workspace=@bitesbox/admin   exit 0
npm run fn:check                            13 functions
npm run fn:lint                             deno lint + fmt --check
cd apps/mobile && flutter analyze           No issues found!
cd apps/mobile && flutter test              113 passed
./scripts/check-secrets.sh                  no committed credentials
```

## By area

| Area | State | Notes |
| --- | --- | --- |
| Auth & RBAC | Done | 10 roles, 70 permissions, branch-scoped |
| Menu & catalog | Done | Categories, variants, modifiers, availability windows |
| Cart & pricing | Done | Server-computed; the client never prices |
| Coupons & promotions | Done | Eligibility, day/time windows, first-order, usage caps |
| Serviceability | Done | Zone polygons, per-zone fee and minimum |
| Order state machine | Done | 51 transitions, single writer, full history |
| Kitchen | Done | Queue, accept/reject, prep timing, availability pause |
| Payments | Done | Razorpay order → signature → webhook, idempotent capture |
| COD | Done | Collection, discrepancy, rider cash balance, settlement |
| Refunds | Done | Policy-driven approval, wallet fallback, gateway + webhook |
| Wallet & loyalty | Done | Append-only ledgers, balances always derived |
| Dispatch | Done | Ranked candidates, capacity, reassignment, offer expiry |
| Delivery | Done | Pickup code, delivery OTP, proof photo, failure path |
| Rider onboarding | Done | Document upload, staff review, activation, partner code |
| Live tracking | Done | One mutable row + throttled trail, maps with fallback |
| Rider earnings | Done | Append-only ledger, peak/distance payout, adjustments |
| Notifications | Done | Templates, channel prefs, push, in-app inbox, campaigns |
| Support & reviews | Done | Tickets, order help, audited moderation |
| CMS | Done | Banners, sections, FAQs, documents |
| Admin dashboard | Done | 29 pages across 7 staff roles |
| Analytics & reports | Done | Sales, items, riders, funnels, CSV export |
| Audit | Done | Append-only, actor + diff + IP on every sensitive action |
| Scheduled jobs | Done | 15 jobs across 3 pg_cron cadences |
| CI/CD | Done | 5 CI jobs, gated deploys for Supabase, admin, mobile |
| Documentation | Done | 10 documents |

## What was wrong when this work started

Recorded because it is the honest picture, and because each one is now covered by a
test.

### The Flutter app did not compile

`flutter analyze` reported **107 errors**. The app was not buildable. Causes:

- `Feedback` in `lib/shared/feedback.dart` collided with Flutter's own `Feedback`
  from `material.dart`. Renamed to `AppFeedback` across 29 files.
- `CheckoutQuote.isPickup` was referenced and did not exist.
- `kitchen_providers.dart` had a `show` clause omitting a symbol it used.
- `product_sheet.dart` called protected `setState` from sibling widgets.
- `main.dart` used the removed `anonKey:` parameter.
- 18 deprecated `RadioListTile` usages.

`flutter analyze` is now a CI gate, and it treats infos as findings.

### Two privilege escalations

**A rider could promote themselves.** `delivery_partners_self_update` let a rider
update their own row. Verified by probe: they could set
`onboarding_status = 'VERIFIED'`, zero their `cash_in_hand`, set
`rating_average = 5` and `total_deliveries = 9999`, and raise
`max_concurrent_orders`. The policy is dropped; `update_my_rider_profile()` now
accepts only the fields a rider owns.

**The rider role held branch-wide delivery permissions.** `DELIVERY_PARTNER`
carried `delivery.view`, `delivery.pickup` and `delivery.complete`, all
branch-scoped — so any rider could list the whole roster, read every other rider's
assignment including customer name, phone and address, and complete another
rider's delivery. The role now holds zero permissions; authority comes from
`app.is_assigned_rider`.

Both are regression-tested in suites `040` and `070`.

### Guests could not read the menu

`app.has_permission` was granted to `authenticated` only, but the catalog RLS
policies call it:

```sql
using (deleted_at is null and (is_active or app.has_permission('menu.view')))
```

RLS expressions run with the caller's privileges and the planner may take either
side of the `OR` first, so an anonymous `select` from `products` returned
`permission denied for function has_permission`. The `security definer` read
functions masked it, which is why the app worked — but any direct table read or
Realtime subscription by a guest failed, and a web storefront would have hit it
immediately.

### Storage buckets did not exist on the hosted project

They were declared only in `config.toml`, which `supabase start` reads and
`supabase db push` does not. So on every hosted project the buckets were absent and
every upload the RLS policies were written for would have failed with "Bucket not
found". All eight are now created in SQL.

### An unguarded privileged read

`public.available_riders` was granted to `authenticated`, is `security definer`,
and carried no permission check in its body. Any signed-in customer could call the
RPC and get the roster with names, phone numbers, duty state and live proximity.
The Edge Function guarded it; the RPC did not.

### Dead configuration

Three pieces of config existed and nothing read them: `delivery_payout_config`
peak-hour bonus, the rider distance-to-store at assignment, and
`rider.required_documents`. Now wired through `app.tg_assignment_payout` and
`app.required_rider_documents()`.

### Five functions threw on every call

Found during final verification, by `supabase db lint` and then by a smoke suite
written because of what the lint found. All five installed cleanly through
`supabase db reset` — a plpgsql body is only resolved when it runs, so a query that
cannot possibly execute is not a syntax error.

Two were bad SQL:

| Function | Error | Blast radius |
| --- | --- | --- |
| `search_suggestions` | 42803 — `p.order_count` must appear in the GROUP BY | The customer search screen. Broken for every user, including guests. |
| `svc_audit` | 42804 — `actor_kind` is an enum, the expression was text | Every service-role audit entry. The trail for Edge Function writes was unreachable. |

Three were the same structural mistake: a `public` function that was
invoker-rights but referenced the `app` schema. `authenticated` and `anon` hold
EXECUTE on many `app` helpers — migration 0028 granted the RLS ones deliberately —
but neither has USAGE on the schema, and USAGE is what you need to *name*
something in it. A `security definer` body runs as the owner and has it; an
invoker-rights body does not.

| Function | Broken for | What it does |
| --- | --- | --- |
| `branch_ordering_state` | guests and customers | "Is the restaurant open?" — gates the whole ordering flow |
| `has_permission` | every signed-in user | The client-facing permission check |
| `manage_user_role` | even the owner | All role management |

Every other read surface in the schema was already `security definer`; these three
were the exceptions. They now match.

Making `manage_user_role` a definer needed care, because its original comment said
it ran as the caller so the privilege-escalation guard could compare ranks. The
guard is real but it is `app.tg_guard_role_assignment`, a `security definer`
*trigger*: it fires on the write regardless of the caller's rights and reads
`auth.uid()`. Suite `010` now asserts that an owner still cannot mint another owner
(`PRIVILEGE_ESCALATION_BLOCKED`) rather than leaving it to be assumed.

Granting `usage on schema app` would have been the one-line fix and was rejected.
54 individual EXECUTE grants on `app` exist — including `app.run_job`,
`app.dispatch_campaign` and every `app.job_*` — and schema USAGE is the only thing
making them unreachable. Granting it would have turned a tidiness problem into a
live escalation letting any signed-in user run the job scheduler.

Two things changed so this class of bug fails loudly next time:

- `scripts/db-lint.sh` wraps `supabase db lint`, which always exits 0, and fails on
  error-level findings. It is now the CI gate.
- Suite `090_read_surfaces` calls every client-callable read RPC as a role allowed
  to call it. 65 assertions that mostly just prove the code runs.

### Smaller ones

- `app.tg_review_aggregates` set `rating_average = NULL` when the last published
  review of a rider was hidden, violating the NOT NULL constraint — so moderating
  that review failed outright.
- Kitchen availability: "Until I switch it back on" silently did nothing, because
  the sentinel was `null` and the caller read `null` as a dismissed sheet.
- The first real support ticket collided with a seeded `ticket_number` because the
  sequence was never advanced past the seed.
- Review moderation wrote to the table directly, recording neither who hid a review
  nor why.
- Campaign "Send now" queued rows but nothing flushed them.
- `next lint` is deprecated and prompts interactively with no config, which would
  hang CI. Replacing it with a flat ESLint config surfaced nine unused imports
  across seven pages.
- Three test suites hard-coded date-stamped order numbers and broke the day after
  they were written.
- Seeded rider document paths embedded the bucket name instead of the owner's user
  id, so they were unreadable by the rider who owned them and would have been
  refused on submission.

## Known gaps

Stated plainly rather than left to be discovered.

**No end-to-end browser tests.** Nothing drives the admin dashboard through a real
login in a real browser.

**No Flutter integration tests.** No `integration_test/` running against a live
backend on a device.

**No Razorpay contract tests.** The integration is verified manually in test mode.
This is the weakest link in the test matrix; the webhook event log is what makes an
incident reconstructible.

**No load testing.** Index choices are reasoned about — partial indexes on the hot
reconciliation and dispatch queries — but not measured under load.

**No penetration test.** The security claims in [security.md](security.md) are what
the SQL suites prove against a real database with real API roles, not a third-party
assessment.

**iOS release is scaffolded, not proven.** The workflow job exists and is guarded
so it does not sit red, but it has never run: it needs an Apple Developer account,
a distribution certificate, a provisioning profile, and
`ios/ExportOptions.plist`.

**Migrations are not yet pushed to the hosted project.** Everything here is
verified against a local stack. `supabase db push` to
`kqsbzafxntsksalchlgc` has not been run — it needs the database password and it is
irreversible, so it is a deliberate decision rather than something to do quietly.
See [deployment.md](deployment.md#pushing-to-a-hosted-project).

**Multi-branch is modelled, not exercised.** Every table carries `branch_id`, every
permission check is branch-scoped, and `accessible_branch_ids()` exists — but the
seed has one outlet, so the multi-branch paths are proven by construction rather
than by use.

## Decisions worth knowing

Recorded so the next person does not undo them by accident.

**A rider holds zero permissions.** Authority is being the assigned partner, not
holding a role capability. Closes three leaks at once.

**`app.is_assigned_rider` includes COMPLETED and FAILED.** `complete_delivery`
sets the assignment terminal *before* transitioning the order, so a narrower
predicate would stop recognising the rider mid-call. Verified that no
`rider_allowed` edge starts from a terminal status.

**Payout is a trigger, not logic inside `assign_rider`.** Every future writer of an
assignment row gets it.

**Campaign copy is inserted directly into `notifications`.** Templates cannot carry
per-campaign copy; the function itself honours channel preferences and
`marketing_opt_in`.

**The SQL harness is our own, not pgTAP.** pgTAP is available locally but not on
the hosted project, and these tests must run against both.

**Proof-of-delivery photo is optional.** A dead camera must not block a genuine
delivery, and the OTP is already the proof that matters.

**Maps draw a straight dashed line, not a Directions route.** A route call per GPS
fix would cost money for a decoration riders do not navigate by — they use the
hand-off to Google Maps for that.

**Marker positions are not interpolated.** A smoothly gliding marker that is a
guess is worse than a stepping one that is true.

**`dart format` is not a CI gate.** It targets 80 columns; this codebase is laid
out wider and widget trees read better with the existing breaks. `flutter analyze`
is the real gate.

**No Gradle or Xcode flavors.** Environments select configuration through
`--dart-define-from-file`. Flavors would need Xcode scheme changes that cannot be
made reliably by editing files.

## Next, if the work continues

In the order that would add the most:

1. Push migrations to the hosted project and run the post-deploy checklist in
   [deployment.md](deployment.md#verification-after-a-deploy).
2. Razorpay test-mode run-through, end to end, with the webhook confirmed in
   `payment_events`.
3. A Playwright suite covering the three admin flows where a mistake costs money:
   refund approval, order override, campaign launch.
4. Automatic dispatch. The scoring function already exists and is shared with
   manual assignment, so this is wiring, not design.
5. A second branch in the seed, to exercise the multi-branch paths that are
   currently proven only by construction.
