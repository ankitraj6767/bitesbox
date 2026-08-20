# Build configuration

Every value the app needs at runtime arrives at compile time through
`--dart-define-from-file`, so a build carries its own environment and nothing
sensitive is committed.

```bash
# Against the hosted development project
flutter run --dart-define-from-file=env/dev.json

# Against a local `supabase start` stack
flutter run --dart-define-from-file=env/local.json

# Release builds
flutter build appbundle --release --dart-define-from-file=env/prod.json
flutter build ipa --release --dart-define-from-file=env/prod.json
```

`dev.json` and `local.json` are committed because they contain only the
publishable Supabase key, which is designed to be shipped in a client and is
useless without a valid RLS-passing session. `staging.json` and `prod.json` are
**not** committed — copy the `.example` files and fill them in on the machine or
CI runner that produces the build.

## What each key does

| Key | Required | Effect when absent |
| --- | --- | --- |
| `APP_ENV` | yes | Defaults to `development`; a `production` value adds release assertions |
| `SUPABASE_URL` | yes | Startup assertion fails |
| `SUPABASE_PUBLISHABLE_KEY` | yes | Startup assertion fails |
| `RAZORPAY_KEY_ID` | production | Online payment is hidden; cash on delivery still works end to end |
| `GOOGLE_MAPS_KEY` | no | Embedded maps are replaced by a hand-off to the phone's own maps app |
| `SENTRY_DSN` | no | Crash reporting is off |
| `FIREBASE_*` | no | Push is off; updates still arrive over Realtime and the in-app inbox |

Nothing privileged belongs here. The Supabase service role key, the Razorpay
secret, the FCM server credential and the OTP provider credentials exist only as
Edge Function secrets — see `docs/security.md`.
