import 'package:flutter_test/flutter_test.dart';
import 'package:bitesbox/features/kitchen/data/kitchen_models.dart';

void main() {
  group('KitchenOrder.stage', () {
    test('keeps an assigned, unfinished order in Preparing', () {
      final order = KitchenOrder.fromJson({
        'id': 'order-1',
        'order_number': 'BB-001',
        'status': 'RIDER_ARRIVED_STORE',
        'preparing_at': '2026-10-23T10:00:00Z',
        'ready_at': null,
      });

      expect(order.stage, KitchenStage.preparing);
    });

    test('keeps a ready order in Ready after rider assignment', () {
      final order = KitchenOrder.fromJson({
        'id': 'order-2',
        'order_number': 'BB-002',
        'status': 'RIDER_ARRIVED_STORE',
        'ready_at': '2026-10-23T10:05:00Z',
      });

      expect(order.stage, KitchenStage.ready);
    });
  });
}
