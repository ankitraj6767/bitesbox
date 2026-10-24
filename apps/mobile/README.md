# Bites Box mobile app

The Flutter app serves customers, delivery partners, and kitchen staff in one
application. The database remains authoritative for pricing, permissions, order
transitions, delivery completion, and payment state.

Current app version: **1.2.10 (build 42)**.

## Requirements

- Flutter 3.35.x and Dart 3.9.x
- Android Studio/Xcode for simulator or device runs
- Node/npm only when using the repository's root scripts
- A reachable Supabase project with the repository migrations and seed data

## Configure and run

From the repository root:

```bash
npm install
cd apps/mobile
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

For local Supabase, start and seed the stack from the repository root with
`npm run db:start` and `npm run db:reset`, then run:

```bash
cd apps/mobile
flutter run --dart-define-from-file=env/local.json
```

The selected environment file must point to a Supabase URL reachable from the
target device. Android emulators and physical devices cannot reach a developer
machine's `localhost` in the same way as the host process; use the emulator host
gateway or the machine's reachable LAN address in a local-only environment file.

`env/dev.json` and `env/local.json` are development conveniences. Production and
staging settings belong in ignored local files or CI secrets; copy the matching
`.example` file and never commit private provider credentials. `SENTRY_DSN` is
optional and enables crash reporting. The Supabase publishable key is expected in
the app; service-role, Razorpay secret, notification provider, and OTP secrets are
server-only. See [environment variables](env/README.md) and
[security notes](../../docs/security.md).

## Role flows

- **Customer:** phone OTP sign-in, menu discovery, cart and server-priced checkout,
  COD or Razorpay payment, order tracking, support, and profile preferences.
- **Delivery partner:** phone sign-in, onboarding review, duty state, accepted
  assignments, pickup code, customer delivery OTP, COD collection, and optional
  delivery-scoped location sharing. GPS is requested only after an active
  assignment is accepted and the rider enables sharing. Denying GPS never blocks
  pickup, delivery, cash collection, or failure reporting.
- **Kitchen:** staff sign-in, kitchen queue, accepting/rejecting orders, preparation
  state, availability controls, and issuing a rider-bound pickup code for a ready
  delivery. Staff can copy the code or open a prefilled SMS to the assigned rider;
  they confirm sending it in the messaging app. Reissuing invalidates the previous
  code. Privileged back-office administration and
  staff MFA are handled by the Next.js admin application.

Location sharing runs only for the server-confirmed current assignment. Android
shows a foreground-service notice (Android 13+ may place it only in Task Manager
when notification permission is denied); iOS shows its location indicator.
The app does not request Android “Always” access or iOS Always authorization.
Android holds a partial wake lock only while this explicit delivery-sharing
session is active, because otherwise the OS may batch fixes until the phone wakes.
The location stream normally samples every 15 seconds or after 25 metres; if no
server-accepted fix arrives for 30 seconds, a watchdog requests a new OS fix at
most once every 20 seconds. It never queues or replays a prior fix. These settings
favor timely delivery updates over battery life during an active delivery; the
persistent notice and Stop sharing action make that state visible and controllable.
When sharing cannot continue, the rider and customer see an unavailable or stale
state with the last capture time. Stale points are never drawn as live. See the device validation plan in
[testing.md](../../docs/testing.md).

If embedded map configuration is unavailable, navigation hands off to the phone's
maps app or a web map link. Live customer tracking is separate from turn-by-turn
navigation and never treats a stale point as live.

## Run checks

From the repository root:

```bash
npm run mobile:analyze
npm run mobile:test
```

The tests include profile consent hydration/save behavior, location timestamp
policy, telemetry scrubbing, deterministic customer order tracking, and a rider
pickup/completion flow that succeeds without GPS permission. They use fakes and do
not charge a payment method or contact a real customer. SQL/RLS integration tests
need the local Supabase Docker stack; see [testing.md](../../docs/testing.md).

## Build

```bash
cd apps/mobile
flutter build appbundle --release --dart-define-from-file=env/prod.json
flutter build ipa --release --dart-define-from-file=env/prod.json
```

Release builds also require the appropriate signing setup. No signed iOS release
or store upload is implied by a successful local Flutter test. CI builds a debug
Android APK to validate the Android toolchain; release and device checks are
separate.

## Troubleshooting

- **Startup reports missing Supabase configuration:** select a valid environment
  file and check `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`.
- **Local stack is unreachable:** confirm `supabase status`, use a device-reachable
  URL, and keep the phone/emulator on the same network as the development host.
- **No push notifications:** verify Firebase configuration for the selected
  environment. Order status remains available through Realtime and the in-app
  inbox.
- **Rider location is stale:** check Location Services, in-app location permission,
  Android notification permission, network access, battery restrictions, and the
  persistent tracking notice. Reopen the app after changing OS permissions; a new
  OS-captured fix is required before the customer marker becomes live again. Android
  location updates use a foreground-service wake lock only while the rider has
  enabled sharing for an active assignment; battery saver and OEM background limits
  can still interrupt tracking, so confirm a fresh capture timestamp on both apps.
- **Delivery actions are unavailable:** GPS permission is not required for pickup
  or completion. Check assignment state, verification code/OTP, and the server
  error shown by the app.
- **Share pickup code is missing:** the order must be a ready delivery with an
  accepted or at-store rider assignment. The signed-in kitchen account also needs
  `kitchen.operate` for that outlet, and migration
  `20261023151817_kitchen_pickup_handoff_code.sql` must be applied to the backend.
- **Crash reporting is absent:** verify the environment's Sentry DSN and release
  configuration. A missing DSN is supported and does not block ordering.
