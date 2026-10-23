# Android auto-updates

Bites Box publishes direct-distributed Android updates automatically when mobile
app source changes reach `main`. A manual workflow dispatch remains available
for an intentional republish.

1. A push to `main` that changes `apps/mobile/**` starts
   `.github/workflows/android-auto-release.yml`; it can also be dispatched
   manually from `main` with release notes.
2. CI runs Flutter analysis and tests.
3. The workflow takes the release name from `apps/mobile/pubspec.yaml` and
   creates a monotonically increasing Android build number by adding the
   GitHub Actions run number to the pubspec build number. For example,
   `1.2.3+10` on workflow run `7` builds as `1.2.3+17`. A version bump is
   therefore reflected in the installed app, and every later APK has a higher
   Android version code than the baseline build.
4. It builds arm64, armeabi-v7a and x86_64 split APKs.
5. It uploads the APKs and a SHA-256 verified `update-manifest.json` to the
   public `app-releases` Supabase Storage bucket.
6. Installed apps check that manifest on launch and offer the matching ABI APK.
7. Android opens the normal system installer; the app never silently installs
   software outside Android’s security controls.

Before uploading, the publisher checks the current manifest and rejects a
version rollback or an Android build number that is not newer than the published
one. This prevents a delayed or retried workflow from replacing a newer update.

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

For a normal mobile release, update the `version:` value in
`apps/mobile/pubspec.yaml` when the product version changes, then push the app
change to `main`. GitHub Actions builds and publishes the update; no local APK
build or manual dispatch is needed. The run number keeps Android build numbers
increasing even when a product change does not require a version-name bump.

The app checks the published manifest on launch and displays an update prompt.
The workflow does not silently install APKs: users must tap **Update now** and
confirm Android's system installer. The automatic step is the build and
publication of the update.

The Supabase `app-releases` bucket is public-read but write-only from CI using
the service role. The service role is never included in the APK. Split APKs are
used because the Supabase Free plan limits individual Storage objects to 50 MB.

For an Android device, the app requests permission to install unknown apps when
the first update is started. The customer approves that Android system setting
once; later updates use the same installer flow.
