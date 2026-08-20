import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../customer/providers/customer_providers.dart'
    show activeBranchIdProvider, menuCatalogProvider;
import '../data/kitchen_models.dart';
import '../data/kitchen_repository.dart';

final kitchenRepositoryProvider = Provider<KitchenRepository>(
  (ref) => KitchenRepository(ref.watch(apiClientProvider)),
);

/// The live kitchen queue.
///
/// Realtime drives refreshes; a slow ticker is kept as a safety net so a dropped
/// socket can never leave a busy kitchen looking at a stale board.
class KitchenQueueController extends AsyncNotifier<KitchenQueue> {
  StreamSubscription<void>? _subscription;
  Timer? _fallbackTimer;
  Set<String> _knownNewOrders = const {};
  bool _primed = false;

  static const _fallbackInterval = Duration(seconds: 45);

  @override
  Future<KitchenQueue> build() async {
    ref.onDispose(() {
      _subscription?.cancel();
      _fallbackTimer?.cancel();
    });

    final branchId = ref.watch(activeBranchIdProvider);
    final queue = await ref.watch(kitchenRepositoryProvider).queue(branchId: branchId);

    if (branchId != null) {
      _subscription ??= ref
          .read(kitchenRepositoryProvider)
          .watchQueue(branchId)
          .listen((_) => ref.invalidateSelf());
    }

    _fallbackTimer ??= Timer.periodic(_fallbackInterval, (_) => refresh());

    _alertOnNewOrders(queue);
    return queue;
  }

  /// An unmissable alert matters more than elegance on a noisy kitchen line: the
  /// tablet vibrates and plays the system alert whenever a genuinely new ticket
  /// appears (not on the first load, and not for tickets already seen).
  void _alertOnNewOrders(KitchenQueue queue) {
    final current = queue.newOrderIds;

    if (!_primed) {
      _primed = true;
      _knownNewOrders = current;
      return;
    }

    final arrivals = current.difference(_knownNewOrders);
    _knownNewOrders = current;

    if (arrivals.isNotEmpty) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    }
  }

  Future<void> refresh() async {
    final branchId = ref.read(activeBranchIdProvider);
    state = const AsyncValue<KitchenQueue>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(kitchenRepositoryProvider).queue(branchId: branchId),
    );

    final queue = state.valueOrNull;
    if (queue != null) _alertOnNewOrders(queue);
  }

  Future<void> accept({required String orderId, int? prepMinutes}) async {
    await ref.read(kitchenRepositoryProvider).accept(orderId: orderId, prepMinutes: prepMinutes);
    await refresh();
  }

  Future<void> reject({
    required String orderId,
    required String reason,
    String? note,
  }) async {
    await ref
        .read(kitchenRepositoryProvider)
        .reject(orderId: orderId, reason: reason, note: note);
    await refresh();
  }

  Future<void> startPreparing(String orderId) async {
    await ref.read(kitchenRepositoryProvider).startPreparing(orderId);
    await refresh();
  }

  Future<void> markReady(String orderId) async {
    await ref.read(kitchenRepositoryProvider).markReady(orderId);
    await refresh();
  }
}

final kitchenQueueProvider =
    AsyncNotifierProvider<KitchenQueueController, KitchenQueue>(
  KitchenQueueController.new,
);

final kitchenCountsProvider = Provider<KitchenCounts>((ref) {
  return ref.watch(kitchenQueueProvider).valueOrNull?.counts ?? const KitchenCounts();
});

/// The kitchen stage currently on screen.
final kitchenStageProvider = StateProvider<KitchenStage>((ref) => KitchenStage.newOrders);

/// Availability toggles for the current branch.
class AvailabilityController extends AsyncNotifier<KitchenAvailability> {
  @override
  Future<KitchenAvailability> build() async {
    final branchId = ref.watch(activeBranchIdProvider);
    return ref.watch(kitchenRepositoryProvider).availability(branchId: branchId);
  }

  Future<void> refresh() async {
    final branchId = ref.read(activeBranchIdProvider);
    state = const AsyncValue<KitchenAvailability>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(kitchenRepositoryProvider).availability(branchId: branchId),
    );
  }

  /// Marks a dish out of stock, optionally auto-restoring it after [minutes].
  Future<void> setState({
    required String productId,
    required String availabilityState,
    int? minutes,
    String? reason,
  }) async {
    await ref.read(kitchenRepositoryProvider).setProductAvailability(
          productId: productId,
          state: availabilityState,
          branchId: ref.read(activeBranchIdProvider),
          minutes: minutes,
          reason: reason,
        );

    await refresh();
    // The customer-facing menu is now different.
    ref.invalidate(menuCatalogProvider);
  }

  Future<int> setBulkState({
    required List<String> productIds,
    required String availabilityState,
    int? minutes,
    String? reason,
  }) async {
    final changed = await ref.read(kitchenRepositoryProvider).setProductsAvailability(
          productIds: productIds,
          state: availabilityState,
          branchId: ref.read(activeBranchIdProvider),
          minutes: minutes,
          reason: reason,
        );

    await refresh();
    ref.invalidate(menuCatalogProvider);
    return changed;
  }
}

final kitchenAvailabilityProvider =
    AsyncNotifierProvider<AvailabilityController, KitchenAvailability>(
  AvailabilityController.new,
);

/// Filter text on the availability screen.
final availabilityFilterProvider = StateProvider<String>((ref) => '');

/// Opens, pauses or closes the outlet. Kept separate from the queue so a failed
/// status change never disturbs the live board.
class BranchStatusController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> setStatus({
    required String status,
    String? reason,
    String? note,
    int? resumeAfterMinutes,
  }) async {
    state = true;
    try {
      await ref.read(kitchenRepositoryProvider).setBranchStatus(
            status: status,
            reason: reason,
            note: note,
            branchId: ref.read(activeBranchIdProvider),
            resumeAfterMinutes: resumeAfterMinutes,
          );

      ref.invalidate(appConfigProvider);
      await ref.read(kitchenQueueProvider.notifier).refresh();
    } finally {
      state = false;
    }
  }
}

final branchStatusControllerProvider =
    NotifierProvider<BranchStatusController, bool>(BranchStatusController.new);
