import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/env.dart';

/// Bites Box — one app for customers, delivery partners and the kitchen.
///
/// Configuration arrives at compile time:
///   flutter run --dart-define-from-file=env/dev.json
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertValid();

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

  runApp(const ProviderScope(child: BitesBoxApp()));
}
