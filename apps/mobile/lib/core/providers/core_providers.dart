import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_repository.dart';
import '../auth/session.dart';
import '../config/env.dart';
import '../errors/app_error.dart';
import '../network/api_client.dart';
import '../theme/brand_tokens.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

/// Emits on sign-in, sign-out and token refresh.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// ── Session ────────────────────────────────────────────────────────────────
/// The single source of truth for "who is using the app".
///
/// Reloaded whenever Supabase reports an auth change, so signing in or out
/// re-resolves the shell without any manual plumbing.
class SessionController extends AsyncNotifier<AppSession> {
  @override
  Future<AppSession> build() async {
    // Rebuild on every auth transition.
    ref.watch(authStateChangesProvider);

    final repository = ref.watch(authRepositoryProvider);
    if (!repository.isSignedIn) return const AppSession.guest();

    return repository.loadSession();
  }

  /// Re-reads permissions and profile. Call after anything that could change
  /// them — profile setup, a role grant, or returning from the background.
  Future<void> refresh() async {
    state = const AsyncValue<AppSession>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).loadSession());
  }

  Future<void> signOut({String? deviceToken}) async {
    await ref.read(authRepositoryProvider).signOut(deviceToken: deviceToken);
    state = const AsyncValue.data(AppSession.guest());
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, AppSession>(
  SessionController.new,
);

/// Convenience read that treats "still loading" as "guest", so widgets can build
/// without null checks. Screens that must wait use [sessionProvider] directly.
final currentSessionProvider = Provider<AppSession>((ref) {
  return ref.watch(sessionProvider).maybeWhen(
        data: (session) => session,
        orElse: () => const AppSession.guest(),
      );
});

// ── Platform configuration (branding, flags, hours) ────────────────────────
/// Result of `public.app_config()`.
class AppConfig {
  const AppConfig({
    required this.brand,
    required this.settings,
    required this.featureFlags,
    required this.branch,
    required this.orderingState,
  });

  const AppConfig.fallback()
      : brand = const BrandTokens(),
        settings = const {},
        featureFlags = const {},
        branch = const {},
        orderingState = const {};

  final BrandTokens brand;
  final Map<String, dynamic> settings;
  final Map<String, bool> featureFlags;
  final Map<String, dynamic> branch;
  final Map<String, dynamic> orderingState;

  bool flag(String key, {bool fallback = false}) => featureFlags[key] ?? fallback;

  String? get branchId => branch['id'] as String?;
  String get branchName => (branch['name'] as String?) ?? 'Bites Box';
  String? get supportPhone =>
      (settings['contact.phone'] as String?) ?? (branch['phone'] as String?);
  String? get whatsappPhone => settings['contact.whatsapp'] as String?;

  bool get acceptingOrders => orderingState['accepting_orders'] == true;
  String? get closedReasonCode => orderingState['reason_code'] as String?;
  String? get closedNote => orderingState['status_note'] as String?;
  int get prepMinutes => (orderingState['prep_minutes'] as num?)?.toInt() ?? 20;

  /// Copy shown on the home banner when ordering is unavailable.
  String get closedMessage {
    final note = closedNote;
    if (note != null && note.trim().isNotEmpty) return note;

    return switch (closedReasonCode) {
      'MAINTENANCE_MODE' =>
        (settings['maintenance.message'] as String?) ??
            'We are making Bites Box better. Please check back shortly.',
      'OUTSIDE_TRADING_HOURS' =>
        'Our kitchen is closed right now. You can still schedule an order for later.',
      'TOO_BUSY' => 'Our kitchen is at full capacity. Please try again in a few minutes.',
      'ORDERING_PAUSED' => 'We have paused new orders for a few minutes.',
      _ => 'We are not accepting orders right now.',
    };
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final settings = json['settings'] is Map
        ? Map<String, dynamic>.from(json['settings'] as Map)
        : <String, dynamic>{};

    final flagsRaw = json['feature_flags'] is Map
        ? Map<String, dynamic>.from(json['feature_flags'] as Map)
        : <String, dynamic>{};

    return AppConfig(
      brand: BrandTokens.fromSettings(settings),
      settings: settings,
      featureFlags: {
        for (final entry in flagsRaw.entries) entry.key: entry.value == true,
      },
      branch: json['branch'] is Map
          ? Map<String, dynamic>.from(json['branch'] as Map)
          : const {},
      orderingState: json['ordering_state'] is Map
          ? Map<String, dynamic>.from(json['ordering_state'] as Map)
          : const {},
    );
  }
}

/// Branding, public settings, feature flags and store state.
///
/// Kept alive because the whole app reads it, and refreshed on demand rather
/// than polled — the store-state banner also listens to realtime branch changes.
final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  final api = ref.watch(apiClientProvider);

  try {
    final result = await api.rpc<dynamic>('app_config');
    if (result is Map) {
      return AppConfig.fromJson(Map<String, dynamic>.from(result));
    }
    return const AppConfig.fallback();
  } on AppError catch (error) {
    // Never block the app on a config failure: ship compiled-in defaults and
    // let the customer browse a cached menu.
    if (kDebugMode) {
      debugPrint('app_config failed (${error.code}): ${error.message}');
    }
    return const AppConfig.fallback();
  }
});

/// Brand tokens with a safe fallback while config loads.
final brandTokensProvider = Provider<BrandTokens>((ref) {
  return ref.watch(appConfigProvider).maybeWhen(
        data: (config) => config.brand,
        orElse: () => const BrandTokens(),
      );
});

final environmentProvider = Provider<String>((ref) => Env.appEnv);
