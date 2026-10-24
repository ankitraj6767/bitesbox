import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/core_providers.dart';
import 'cart_controller.dart';
import 'customer_providers.dart';

/// Re-read customer-facing data after an operator changes live settings.
/// Realtime payloads are invalidation signals only; RPCs and RLS remain the
/// source of truth for all values shown in the app.
final customerSettingsRealtimeProvider = Provider<void>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(currentSessionProvider);
  Timer? pendingRefresh;

  void refresh() {
    pendingRefresh?.cancel();
    pendingRefresh = null;
    ref.invalidate(appConfigProvider);
    ref.invalidate(outletsProvider);
    ref.invalidate(activeBranchIdProvider);
    ref.invalidate(homeFeedProvider);
    ref.invalidate(tastePassportProvider);
    ref.invalidate(menuCatalogProvider);
    ref.invalidate(productDetailProvider);
    ref.invalidate(searchSuggestionsProvider);
    ref.invalidate(searchResultsProvider);
    ref.invalidate(favoritesProvider);
    ref.invalidate(availableCouponsProvider);
    ref.invalidate(cartProvider);
  }

  void onDatabaseChange(PostgresChangePayload _) {
    pendingRefresh?.cancel();
    pendingRefresh = Timer(const Duration(milliseconds: 250), refresh);
  }

  final channel = client.channel('customer-settings-sync')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'branches',
      callback: onDatabaseChange,
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'branch_hours',
      callback: onDatabaseChange,
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'branch_holidays',
      callback: onDatabaseChange,
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'settings',
      callback: onDatabaseChange,
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'feature_flags',
      callback: onDatabaseChange,
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'delivery_zones',
      callback: onDatabaseChange,
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'tax_categories',
      callback: onDatabaseChange,
    );
  if (session.isCustomer && session.userId != null) {
    channel
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'customer_favorites',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: session.userId!,
        ),
        callback: onDatabaseChange,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'customer_taste_profiles',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: session.userId!,
        ),
        callback: onDatabaseChange,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: session.userId!,
        ),
        callback: onDatabaseChange,
      );
  }
  channel.subscribe();

  final lifecycle = AppLifecycleListener(onResume: refresh);
  ref.onDispose(() {
    pendingRefresh?.cancel();
    lifecycle.dispose();
    unawaited(client.removeChannel(channel));
  });
});
