/// Compile-time configuration.
///
/// Values arrive through `--dart-define-from-file`, so a build carries its own
/// environment and nothing sensitive is committed. Only the publishable Supabase
/// key and restricted client map keys ever reach the app; the service role key
/// and Razorpay secret live exclusively in Edge Functions.
///
///   flutter run --dart-define-from-file=env/dev.json
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
  );

  /// `development` | `staging` | `production`
  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  /// Publishable Razorpay key id, handed to the checkout SDK.
  static const String razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID');

  /// Platform-restricted Maps key for rendering maps and deep links.
  static const String googleMapsKey = String.fromEnvironment('GOOGLE_MAPS_KEY');

  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  // ── Firebase Cloud Messaging ──
  // Supplied as plain values rather than a committed google-services.json, so a
  // fork of this repository carries no project identity. All four are public
  // client identifiers; the FCM server key stays in the Edge Function secrets.
  static const String firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String firebaseSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String firebaseStorageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  static bool get isDevelopment => appEnv == 'development';
  static bool get isProduction => appEnv == 'production';

  /// Push is wired up only when the whole client identity is present. Without it
  /// the app still receives every update over Realtime and the in-app inbox.
  static bool get pushEnabled =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;

  /// Razorpay is only wired up when a publishable key is supplied. Without it the
  /// app still works end to end using cash on delivery, which is what a local
  /// developer usually wants.
  static bool get onlinePaymentsEnabled => razorpayKeyId.isNotEmpty;

  static bool get mapsEnabled => googleMapsKey.isNotEmpty;

  /// Fails fast on a misconfigured release build rather than at first request.
  static void assertValid() {
    assert(supabaseUrl.isNotEmpty, 'SUPABASE_URL is required');
    assert(supabasePublishableKey.isNotEmpty, 'SUPABASE_PUBLISHABLE_KEY is required');

    if (isProduction) {
      assert(
        !supabaseUrl.contains('127.0.0.1') && !supabaseUrl.contains('localhost'),
        'A production build must not point at a local Supabase stack',
      );
      assert(razorpayKeyId.isNotEmpty, 'RAZORPAY_KEY_ID is required in production');
    }
  }
}
