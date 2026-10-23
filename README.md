# Bites Box — Restaurant Digital Operating System

Single-brand restaurant commerce platform for **Bites Box**, Bakhtiyarpur, Patna, Bihar, India.

Not a marketplace. One brand, multi-branch ready.

```
┌──────────────────────────────────────┐
│         UNIFIED FLUTTER APP          │
│  Customer · Delivery Partner ·       │
│  Kitchen Staff · Manager             │
└─────────────────┬────────────────────┘
                  │
                  ▼
┌──────────────────────────────────────┐
│        SUPABASE / POSTGRESQL         │
│  Auth · RBAC · RLS · Menu · Pricing  │
│  Cart · Orders · Payments · Refunds  │
│  Delivery · Tracking · Coupons ·     │
│  Notifications · Support · Audit     │
└─────────────────┬────────────────────┘
                  │
                  ▼
┌──────────────────────────────────────┐
│       NEXT.JS ADMIN DASHBOARD        │
│  Owner · Admin · Manager ·           │
│  Operations · Finance · Support ·    │
│  Marketing                           │
└──────────────────────────────────────┘
```

## Repository layout

```
bitesbox/
├── apps/
│   ├── mobile/          Flutter — unified app (customer/delivery/kitchen/manager)
│   └── admin/           Next.js 15 App Router — admin dashboard
├── supabase/
│   ├── migrations/      Version-controlled SQL migrations (56)
│   ├── functions/       Deno Edge Functions (16, secure business logic)
│   ├── seeds/           Ordered development seed data (7 files)
│   ├── tests/           SQL test harness + 11 suites
│   └── config.toml
├── scripts/             psql wrapper, schema lint gate, secret scan
├── packages/
│   └── shared-types/    Cross-platform domain contracts (TS + Dart generators)
└── docs/
    ├── architecture.md
    ├── database.md
    ├── rbac.md
    ├── order-flow.md
    ├── payment-flow.md
    ├── delivery-flow.md
    ├── security.md
    ├── testing.md
    ├── deployment.md
    ├── android-auto-updates.md
    ├── swiggy-comparison.md
    └── status.md
```

## Core architecture principle

> **The apps are interfaces. The backend is the authority.**

The client is never trusted for price, discount, coupon, tax, delivery fee, wallet
balance, loyalty points, payment success, refund status, order status, delivery
status, or permissions. Every sensitive value is computed or verified server-side
inside Postgres functions or Edge Functions.

## Quick start

```bash
# 1. Install root tooling
npm install

# 2. Backend — local Supabase stack (requires Docker)
npm run db:start
npm run db:reset          # all migrations, then supabase/seeds/*.sql in order
npm run db:test           # 11 suites, expect "11 passed, 0 failed"

# 3. Admin dashboard
cd apps/admin && npm run dev                     # http://localhost:3000

# 4. Mobile app
cd apps/mobile && flutter pub get
flutter run --dart-define-from-file=env/local.json    # against the local stack
```

Verify everything in one go:

```bash
npm run verify      # secrets, edge functions, admin, mobile — no database needed
npm run verify:db   # schema lint + SQL suites — needs the local stack up
```

Full setup instructions: [`docs/deployment.md`](docs/deployment.md).
Environment variables: [`.env.example`](.env.example).

## Documentation index

| Doc | Contents |
|---|---|
| [architecture.md](docs/architecture.md) | System topology, boundaries, trust model, branch strategy |
| [database.md](docs/database.md) | Full schema reference, conventions, indexes |
| [rbac.md](docs/rbac.md) | Roles, permissions, enforcement layers |
| [order-flow.md](docs/order-flow.md) | Order state machine, transitions, guards |
| [payment-flow.md](docs/payment-flow.md) | Razorpay lifecycle, idempotency, reconciliation |
| [delivery-flow.md](docs/delivery-flow.md) | Rider assignment, pickup/drop verification, live tracking |
| [security.md](docs/security.md) | RLS, secrets, abuse controls, audit |
| [testing.md](docs/testing.md) | Test strategy, harness, what is and is not covered |
| [deployment.md](docs/deployment.md) | Environments, CI/CD, release process, rollback |
| [android-auto-updates.md](docs/android-auto-updates.md) | Android release manifests and in-app update flow |
| [swiggy-comparison.md](docs/swiggy-comparison.md) | Swiggy feature comparison and scope |
| [status.md](docs/status.md) | What is built, what was broken, known gaps |

## Status

Core customer, kitchen, delivery and admin flows are implemented. Group ordering
is included. Hosted migration state is unverified beyond the read-only observation
recorded in [`docs/status.md`](docs/status.md); SQL verification requires the
local Docker stack. The Swiggy comparison and product boundaries are documented
there as well.

```
Backend   56 migrations · 87 tables · 155 RLS policies · 107 client RPCs
Edge      16 functions
Admin     44 page modules
Mobile    98 Dart files · 37 screens · 3 role shells
Tests     See the verified release record in [`docs/testing.md`](docs/testing.md)
```

[`docs/status.md`](docs/status.md) has the per-area breakdown, the defects this
work found and closed, and the gaps that remain.
