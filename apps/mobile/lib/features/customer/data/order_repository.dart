import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/json.dart';
import 'order_models.dart';

/// Order reads, cancellation, reviews and support hand-offs.
class OrderRepository {
  const OrderRepository(this._api);

  final ApiClient _api;

  /// `scope`: ALL | CURRENT | PAST
  Future<OrderList> myOrders({
    String scope = 'ALL',
    int limit = 20,
    int offset = 0,
  }) async {
    final result = await _api.rpc<dynamic>(
      'my_orders',
      params: {'p_scope': scope, 'p_limit': limit, 'p_offset': offset},
    );

    return OrderList.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<OrderDetail> detail(String orderId) async {
    final result = await _api.rpc<dynamic>(
      'order_detail',
      params: {'p_order_id': orderId},
      dedupeKey: 'order_detail:$orderId',
    );

    return OrderDetail.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// What cancelling would cost and refund, decided by the server's policy table.
  Future<CancellationOptions> cancellationOptions(String orderId) async {
    final result = await _api.rpc<dynamic>(
      'cancellation_options',
      params: {'p_order_id': orderId},
    );

    return CancellationOptions.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<void> cancel({
    required String orderId,
    String reason = 'CUSTOMER_CHANGED_MIND',
    String? note,
  }) async {
    await _api.rpc<dynamic>(
      'cancel_order',
      params: {
        'p_order_id': orderId,
        'p_reason': reason,
        if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
      },
      dedupeKey: 'cancel_order:$orderId',
    );
  }

  Future<void> submitReview({
    required String orderId,
    required int foodRating,
    required int overallRating,
    int? deliveryRating,
    String? comment,
    List<String> tags = const [],
  }) async {
    await _api.rpc<dynamic>(
      'submit_review',
      params: {
        'p_order_id': orderId,
        'p_food_rating': foodRating,
        'p_overall_rating': overallRating,
        'p_tags': tags,
        if (deliveryRating != null) 'p_delivery_rating': deliveryRating,
        if (comment != null && comment.trim().isNotEmpty) 'p_comment': comment.trim(),
      },
      dedupeKey: 'submit_review:$orderId',
    );
  }

  /// Raises a ticket against an order and lets support decide on any refund.
  /// The app never proposes an amount — that is a back-office decision.
  Future<String> requestHelp({
    required String orderId,
    required String category,
    required String description,
    List<String> itemIds = const [],
  }) async {
    final result = await _api.rpc<dynamic>(
      'request_order_help',
      params: {
        'p_order_id': orderId,
        'p_category': category,
        'p_description': description.trim(),
        if (itemIds.isNotEmpty) 'p_item_ids': itemIds,
      },
      dedupeKey: 'request_help:$orderId:$category',
    );

    return asString(asMap(result)['ticket_id']);
  }

  /// Live order updates.
  ///
  /// Realtime carries the *signal*; the payload is deliberately ignored and the
  /// caller re-reads `order_detail`, so the customer can never be shown a status
  /// that RLS would not have allowed them to fetch.
  Stream<void> watchOrder(String orderId) {
    final controller = StreamController<void>.broadcast();

    final channel = _api.raw.channel('order:$orderId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: orderId,
        ),
        callback: (_) => controller.add(null),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'order_status_history',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'order_id',
          value: orderId,
        ),
        callback: (_) => controller.add(null),
      )
      // The rider's position updates far more often than the order row.
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'delivery_partner_locations',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'order_id',
          value: orderId,
        ),
        callback: (_) => controller.add(null),
      );

    channel.subscribe();

    controller.onCancel = () async {
      await _api.raw.removeChannel(channel);
    };

    return controller.stream;
  }
}
