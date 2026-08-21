# Android auto-updates

Bites Box now follows the LedgerPro release pattern:

1. A push to `main` that changes `apps/mobile/**` triggers
   `.github/workflows/android-auto-release.yml`.
2. CI runs Flutter analysis and tests.
3. The workflow creates a monotonic version from the GitHub Actions run number.
4. It builds arm64, armeabi-v7a and x86_64 split APKs.
5. It uploads the APKs and a SHA-256 verified `update-manifest.json` to the
   public `app-releases` Supabase Storage bucket.
6. Installed apps check that manifest on launch and offer the matching ABI APK.
7. Android opens the normal system installer; the app never silently installs
   software outside Android’s security controls.

## One-time GitHub setup

Add these repository secrets under **Settings → Secrets and variables → Actions**:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `SUPABASE_SERVICE_ROLE_KEY`

The keystore must be the same signing key used for the first build installed by
customers. If the installed APK was signed with a different key, Android will
reject the update; distribute one correctly signed baseline APK once, then all
later releases can update in place.

The Supabase `app-releases` bucket is public-read but write-only from CI using
the service role. The service role is never included in the APK. Split APKs are
used because the Supabase Free plan limits individual Storage objects to 50 MB.

For an Android device, the app requests permission to install unknown apps when
the first update is started. The customer approves that Android system setting
once; later updates use the same installer flow.
