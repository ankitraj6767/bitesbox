import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app/app.dart';
import 'core/config/env.dart';
import 'core/telemetry/scrub.dart';

/// Bites Box — one app for customers, delivery partners and the kitchen.
///
/// Configuration arrives at compile time:
///   flutter run --dart-define-from-file=env/dev.json
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertValid();

  // DateFormat needs locale symbols loaded separately from Flutter's widget
  // localization delegates. These locales are selected by customer profiles.
  await initializeDateFormatting('en_IN');
  await initializeDateFormatting('hi_IN');

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    // Kitchen tablets are used in landscape.
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  await Supabase.initialize(
    url: Env.supabaseUrl,
    // Publishable, not secret: it only ever gets past RLS with a valid session.
    publishableKey: Env.supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(
      // Sessions survive a restart, so a rider mid-shift is never signed out.
      autoRefreshToken: true,
    ),
    realtimeClientOptions: const RealtimeClientOptions(
      // Enough for live order tracking without hammering a mobile connection.
      eventsPerSecond: 10,
    ),
    postgrestOptions: const PostgrestClientOptions(schema: 'public'),
    debug: Env.isDevelopment,
  );

  Future<void> runApplication() async {
    runApp(const ProviderScope(child: BitesBoxApp()));
  }

  var release = 'bitesbox/unknown';
  try {
    final package = await PackageInfo.fromPlatform();
    release = 'bitesbox/${package.version}+${package.buildNumber}';
  } catch (_) {
    // Package metadata is diagnostic context only.
  }

  try {
    await SentryFlutter.init(
      (options) {
        options.dsn = Env.sentryDsn;
        options.environment = Env.appEnv;
        options.release = release;
        options.sendDefaultPii = false;
        options.tracesSampleRate = 0;
        options.beforeSend = (event, _) => scrubSentryEvent(event);
      },
      appRunner: runApplication,
    );
  } catch (_) {
    // Telemetry initialization is best-effort and cannot block ordering.
    await runApplication();
  }
}
