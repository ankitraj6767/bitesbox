import 'dart:convert';

import 'package:bitesbox/core/network/api_client.dart';
import 'package:bitesbox/features/customer/data/order_repository.dart';
import 'package:bitesbox/features/customer/data/payment_repository.dart';
import 'package:bitesbox/features/delivery/data/delivery_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'customer creates an order and follows its server-confirmed status',
    () async {
      final requests = <http.Request>[];
      final testClient = _testClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/functions/v1/create-order')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['idempotency_key'], 'customer-flow-1');
          expect(body['payment_mode'], 'COD');
          return _response(request, {
            'order': {
              'order_id': 'order-1',
              'order_number': 'BB-BKP-001',
              'status': 'ORDER_PLACED',
              'payment_mode': 'COD',
              'payable_amount': 640,
              'requires_payment': false,
              'payment_status': 'PENDING',
              'grand_total': 640,
              'currency_code': 'INR',
            },
          });
        }
        if (request.url.path.endsWith('/rest/v1/rpc/order_detail')) {
          expect(jsonDecode(request.body), {'p_order_id': 'order-1'});
          return _response(request, {
            'id': 'order-1',
            'order_number': 'BB-BKP-001',
            'status': 'ORDER_PLACED',
            'is_active': true,
            'fulfilment_type': 'DELIVERY',
            'totals': {'grand_total': 640, 'payable_amount': 640},
            'items': [],
            'timeline': [
              {
                'to_status': 'ORDER_PLACED',
                'created_at': '2026-10-23T10:00:00Z',
              },
            ],
          });
        }
        throw StateError(
          'Unexpected customer flow request ${request.url.path}',
        );
      });
      addTearDown(testClient.dispose);
      final api = testClient.api;

      final placed = await PaymentRepository(api).createOrder(
        idempotencyKey: 'customer-flow-1',
        paymentMode: 'COD',
        cartId: 'cart-1',
      );
      final order = await OrderRepository(api).detail(placed.orderId);

      expect(placed.orderNumber, 'BB-BKP-001');
      expect(order.status, 'ORDER_PLACED');
      expect(order.isTrackable, isTrue);
      expect(order.timeline.single.toStatus, 'ORDER_PLACED');
      expect(requests.map((request) => request.url.path), [
        '/functions/v1/create-order',
        '/rest/v1/rpc/order_detail',
      ]);
    },
  );

  test(
    'rider accepts, verifies pickup, and completes without GPS permissions',
    () async {
      final requests = <http.Request>[];
      final testClient = _testClient((request) async {
        requests.add(request);
        final response = switch (request.url.path) {
          '/rest/v1/rpc/respond_to_assignment' => {'accepted': true},
          '/rest/v1/rpc/rider_arrived_at_store' => {'status': 'AT_STORE'},
          '/rest/v1/rpc/verify_pickup' => {
            'assignment_id': 'assignment-1',
            'order_id': 'order-1',
            'verified': true,
            'cod_amount': 640,
            'destination': {'address': 'Bakhtiyarpur'},
          },
          '/rest/v1/rpc/complete_delivery' => {'status': 'COMPLETED'},
          _ => throw StateError(
            'Unexpected rider flow request ${request.url.path}',
          ),
        };
        return _response(request, response);
      });
      addTearDown(testClient.dispose);
      final api = testClient.api;

      final repository = DeliveryRepository(api);
      await repository.respondToOffer(
        assignmentId: 'assignment-1',
        accept: true,
      );
      await repository.arrivedAtStore('assignment-1');
      final pickup = await repository.verifyPickup(
        assignmentId: 'assignment-1',
        code: ' 123456 ',
      );
      await repository.completeDelivery(
        assignmentId: 'assignment-1',
        otp: '654321',
        cashCollected: 640,
      );

      expect(pickup.verified, isTrue);
      expect(pickup.codAmount, 640);
      expect(requests.map((request) => request.url.path), [
        '/rest/v1/rpc/respond_to_assignment',
        '/rest/v1/rpc/rider_arrived_at_store',
        '/rest/v1/rpc/verify_pickup',
        '/rest/v1/rpc/complete_delivery',
      ]);
      expect(jsonDecode(requests[2].body), {
        'p_assignment_id': 'assignment-1',
        'p_code': '123456',
      });
      expect(jsonDecode(requests[3].body), {
        'p_assignment_id': 'assignment-1',
        'p_manager_override': false,
        'p_otp': '654321',
        'p_cash_collected': 640,
      });
    },
  );
}

_TestClient _testClient(Future<http.Response> Function(http.Request) handler) {
  final transport = MockClient(handler);
  final client = SupabaseClient(
    'https://example.test',
    'sb_publishable_ci_test',
    httpClient: transport,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return _TestClient(ApiClient(client), client, transport);
}

class _TestClient {
  _TestClient(this.api, this.client, this.transport);

  final ApiClient api;
  final SupabaseClient client;
  final MockClient transport;

  Future<void> dispose() async {
    await client.dispose();
    transport.close();
  }
}

http.Response _response(http.Request request, Object value) => http.Response(
  jsonEncode(value),
  200,
  request: request,
  headers: {'content-type': 'application/json'},
);
