import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/session.dart';
import '../core/notifications/push_gateway.dart';
import '../core/providers/core_providers.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/brand_tokens.dart';

/// The application root.
///
/// Branding comes from the database, so the theme is rebuilt when `app_config`
/// resolves — rebranding is an operations change, not an app release. Kitchen and
/// rider users get the denser, larger-target operations theme.
class BitesBoxApp extends ConsumerWidget {
  const BitesBoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final tokens = ref.watch(brandTokensProvider);
    final session = ref.watch(currentSessionProvider);

    final useOperationsTheme = session.isRider || session.prefersKitchenShell;

    return BrandTheme(
      tokens: tokens,
      child: MaterialApp.router(
        title: tokens.name,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: useOperationsTheme
            ? AppTheme.operations(tokens)
            : AppTheme.customer(tokens),
        builder: (context, child) {
          // Respect the reader's font-size preference, but cap the extremes so a
          // kitchen ticket or a bill never breaks its layout.
          final scale = MediaQuery.textScalerOf(context).clamp(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.35,
          );

          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scale),
            // Inside the router so a tapped notification can navigate, and above
            // every screen so the in-app banner has a Scaffold to attach to.
            child: PushGateway(child: child ?? const SizedBox.shrink()),
          );
        },
      ),
    );
  }
}

/// Convenience extension used across the app for role-aware UI.
extension SessionContext on AppSession {
  bool get usesOperationsShell => isRider || prefersKitchenShell;
}
