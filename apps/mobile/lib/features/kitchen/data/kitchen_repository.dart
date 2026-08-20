import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import 'kitchen_models.dart';

/// The kitchen tablet's operations.
///
/// Each action is a permission-checked RPC that routes through
/// `app.transition_order`, so an illegal jump (say, ready before accepted) is
/// rejected by the state machine rather than prevented only by a hidden button.
class KitchenRepository {
  const KitchenRepository(this._api);

  final ApiClient _api;

  Future<KitchenQueue> queue({String? branchId}) async {
    final result = await _api.rpc<dynamic>(
      'kitchen_queue',
      params: {if (branchId != null) 'p_branch_id': branchId},
      dedupeKey: 'kitchen_queue:$branchId',
    );

    return KitchenQueue.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<KitchenAvailability> availability({String? branchId}) async {
    final result = await _api.rpc<dynamic>(
      'kitchen_availability',
      params: {if (branchId != null) 'p_branch_id': branchId},
      dedupeKey: 'kitchen_availability:$branchId',
    );

    return KitchenAvailability.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// Accepting may revise the prep estimate, which moves the customer's promise
  /// time. Leaving [prepMinutes] null keeps the server's estimate.
  Future<void> accept({required String orderId, int? prepMinutes}) async {
    await _api.rpc<dynamic>(
      'accept_order',
      params: {
        'p_order_id': orderId,
        if (prepMinutes != null) 'p_prep_minutes': prepMinutes,
      },
      dedupeKey: 'accept_order:$orderId',
    );
  }

  Future<void> reject({
    required String orderId,
    String reason = 'KITCHEN_OVERLOADED',
    String? note,
  }) async {
    await _api.rpc<dynamic>(
      'reject_order',
      params: {
        'p_order_id': orderId,
        'p_reason': reason,
        if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
      },
      dedupeKey: 'reject_order:$orderId',
    );
  }

  Future<void> startPreparing(String orderId) async {
    await _api.rpc<dynamic>(
      'start_preparing',
      params: {'p_order_id': orderId},
      dedupeKey: 'start_preparing:$orderId',
    );
  }

  Future<void> markReady(String orderId) async {
    await _api.rpc<dynamic>(
      'mark_order_ready',
      params: {'p_order_id': orderId},
      dedupeKey: 'mark_ready:$orderId',
    );
  }

  /// Marks one dish out of stock or back on. [minutes] auto-restores it later,
  /// which is what the kitchen actually wants during a lunch rush.
  Future<void> setProductAvailability({
    required String productId,
    required String state,
    String? branchId,
    int? minutes,
    String? reason,
    int? remainingQuantity,
  }) async {
    await _api.rpc<dynamic>('set_product_availability', params: {
      'p_product_id': productId,
      'p_state': state,
      if (branchId != null) 'p_branch_id': branchId,
      if (minutes != null) 'p_minutes': minutes,
      if (reason != null && reason.trim().isNotEmpty) 'p_reason': reason.trim(),
      if (remainingQuantity != null) 'p_remaining_quantity': remainingQuantity,
    });
  }

  /// Bulk toggle, used to clear a whole category at closing time.
  Future<int> setProductsAvailability({
    required List<String> productIds,
    required String state,
    String? branchId,
    int? minutes,
    String? reason,
  }) async {
    final result = await _api.rpc<dynamic>('set_products_availability', params: {
      'p_product_ids': productIds,
      'p_state': state,
      if (branchId != null) 'p_branch_id': branchId,
      if (minutes != null) 'p_minutes': minutes,
      if (reason != null && reason.trim().isNotEmpty) 'p_reason': reason.trim(),
    });

    return result is num ? result.toInt() : 0;
  }

  /// Pauses or resumes the whole outlet. [resumeAfterMinutes] schedules the
  /// reopen so nobody forgets to switch the kitchen back on.
  Future<void> setBranchStatus({
    required String status,
    String? reason,
    String? note,
    String? branchId,
    int? resumeAfterMinutes,
  }) async {
    await _api.rpc<dynamic>('set_branch_status', params: {
      'p_status': status,
      if (reason != null) 'p_reason': reason,
      if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
      if (branchId != null) 'p_branch_id': branchId,
      if (resumeAfterMinutes != null) 'p_resume_after_minutes': resumeAfterMinutes,
    });
  }

  /// Signals any order change at this branch. The queue is then re-read in full,
  /// which keeps ordering, timers and counts consistent across every tablet.
  Stream<void> watchQueue(String branchId) {
    final controller = StreamController<void>.broadcast();

    final channel = _api.raw.channel('kitchen:$branchId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'branch_id',
          value: branchId,
        ),
        callback: (_) => controller.add(null),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'delivery_assignments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'branch_id',
          value: branchId,
        ),
        callback: (_) => controller.add(null),
      );

    channel.subscribe();

    controller.onCancel = () async {
      await _api.raw.removeChannel(channel);
    };

    return controller.stream;
  }

  /// Why the kitchen declines an order, mapped to `public.cancellation_reason`.
  static const rejectionReasons = <String, String>{
    'ITEM_UNAVAILABLE': 'An item is out of stock',
    'KITCHEN_OVERLOADED': 'Kitchen is too busy',
    'RESTAURANT_CLOSED': 'We are closing',
    'DUPLICATE_ORDER': 'Duplicate order',
    'OTHER': 'Another reason',
  };

  /// Why the outlet is paused, mapped to `public.branch_closure_reason`.
  static const closureReasons = <String, String>{
    'TOO_BUSY': 'Too busy right now',
    'KITCHEN_ISSUE': 'Kitchen problem',
    'TECHNICAL_ISSUE': 'Technical problem',
    'WEATHER': 'Bad weather',
    'HOLIDAY': 'Holiday',
    'SCHEDULED_CLOSED': 'Outside opening hours',
    'OTHER': 'Another reason',
  };
}
