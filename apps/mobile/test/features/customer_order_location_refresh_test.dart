import 'package:bitesbox/features/customer/data/order_models.dart';
import 'package:bitesbox/features/customer/data/order_repository.dart';
import 'package:bitesbox/features/customer/providers/customer_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only an active assigned delivery refreshes rider location', () {
    expect(
      _order(status: 'OUT_FOR_DELIVERY').shouldRefreshDeliveryLocation,
      isTrue,
    );
    expect(
      _order(status: 'RIDER_ASSIGNED').shouldRefreshDeliveryLocation,
      isTrue,
    );
    expect(_order(status: 'DELIVERED').shouldRefreshDeliveryLocation, isFalse);
    expect(
      _order(
        status: 'OUT_FOR_DELIVERY',
        fulfilmentType: 'PICKUP',
      ).shouldRefreshDeliveryLocation,
      isFalse,
    );
    expect(
      _order(
        status: 'OUT_FOR_DELIVERY',
        includeRider: false,
      ).shouldRefreshDeliveryLocation,
      isFalse,
    );
  });

  testWidgets('customer refreshes an assigned delivery if Realtime is quiet', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final repository = _FakeOrderRepository(_order(status: 'OUT_FOR_DELIVERY'));
    final container = ProviderContainer(
      overrides: [orderRepositoryProvider.overrideWithValue(repository)],
    );
    container.listen(orderDetailProvider('order-1'), (_, _) {});
    addTearDown(container.dispose);

    await tester.pump();
    expect(repository.detailCalls, 1);

    await tester.pump(const Duration(seconds: 20));
    await tester.pump();

    expect(repository.detailCalls, 2);
    container.dispose();
  });

  testWidgets('location refresh pauses in background and resumes on return', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final repository = _FakeOrderRepository(_order(status: 'OUT_FOR_DELIVERY'));
    final container = ProviderContainer(
      overrides: [orderRepositoryProvider.overrideWithValue(repository)],
    );
    container.listen(orderDetailProvider('order-1'), (_, _) {});
    addTearDown(container.dispose);

    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 40));
    expect(repository.detailCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    expect(repository.detailCalls, greaterThanOrEqualTo(2));
    container.dispose();
  });

  testWidgets('terminal orders do not keep polling for rider location', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final repository = _FakeOrderRepository(_order(status: 'DELIVERED'));
    final container = ProviderContainer(
      overrides: [orderRepositoryProvider.overrideWithValue(repository)],
    );
    container.listen(orderDetailProvider('order-1'), (_, _) {});
    addTearDown(container.dispose);

    await tester.pump();
    await tester.pump(const Duration(seconds: 40));
    await tester.pump();

    expect(repository.detailCalls, 1);
    container.dispose();
  });
}

OrderDetail _order({
  required String status,
  String fulfilmentType = 'DELIVERY',
  bool includeRider = true,
}) => OrderDetail.fromJson({
  'id': 'order-1',
  'order_number': 'BB-BKP-001',
  'status': status,
  'is_active': status != 'DELIVERED',
  'fulfilment_type': fulfilmentType,
  'totals': <String, dynamic>{},
  'items': <dynamic>[],
  'timeline': <dynamic>[],
  if (includeRider) 'rider': {'name': 'Rider'},
});

class _FakeOrderRepository implements OrderRepository {
  _FakeOrderRepository(this.order);

  final OrderDetail order;
  var detailCalls = 0;

  @override
  Future<OrderDetail> detail(String orderId) async {
    detailCalls++;
    return order;
  }

  @override
  Stream<void> watchOrder(String orderId) => const Stream<void>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
