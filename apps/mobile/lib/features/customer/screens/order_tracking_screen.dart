import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/launcher.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/live_map.dart';
import '../../../shared/widgets/states.dart';
import '../data/order_models.dart';
import '../providers/cart_controller.dart';
import '../providers/checkout_controller.dart';
import '../providers/customer_providers.dart';
import '../widgets/bill_summary.dart';
import '../widgets/order_progress.dart';
import 'cancel_order_sheet.dart';
import 'review_sheet.dart';
import 'support_screens.dart';

/// Live order tracking and the full order record.
///
/// Updates arrive over realtime as a signal only; the order is then re-read
/// through `order_detail`, so what is displayed is always something RLS agreed to
/// show this customer.
class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final detail = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.valueOrNull?.orderNumber ?? 'Your order'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(orderDetailProvider(orderId)),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: AsyncValueView<OrderDetail>(
        value: detail,
        onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        data: (order) => RefreshIndicator(
          color: brand.primary,
          onRefresh: () async {
            ref.invalidate(orderDetailProvider(orderId));
            await ref.read(orderDetailProvider(orderId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _StatusHeader(order: order),
              if (order.awaitingPayment) ...[
                const SizedBox(height: 14),
                _PaymentPending(order: order),
              ],
              if (order.isTrackable) ...[
                const SizedBox(height: 20),
                OrderProgressBar(order: order),
              ],
              if (order.shouldShowDeliveryOtp) ...[
                const SizedBox(height: 16),
                const _DeliveryOtpCard(),
              ],
              if (order.rider != null) ...[
                const SizedBox(height: 14),
                // The map appears only once there is a fresh fix to draw, so the
                // customer never stares at an empty map before pickup.
                if (order.rider!.liveLocation?.isFresh ?? false) ...[
                  _RiderMap(rider: order.rider!, order: order),
                  const SizedBox(height: 12),
                ],
                _RiderCard(rider: order.rider!, order: order),
              ],
              const SizedBox(height: 16),
              _ItemsCard(order: order),
              const SizedBox(height: 14),
              if (order.isPickup)
                _PickupCard(order: order)
              else
                _AddressCard(order: order),
              const SizedBox(height: 14),
              _PaymentCard(order: order),
              if (order.refunds.isNotEmpty) ...[
                const SizedBox(height: 14),
                _RefundsCard(order: order),
              ],
              const SizedBox(height: 14),
              BillSummary(
                totals: order.totals.asCheckoutTotals(),
                couponCode: order.totals.couponCode,
                isDelivery: !order.isPickup,
                showTaxBreakdown: true,
              ),
              const SizedBox(height: 14),
              _TimelineCard(order: order),
              const SizedBox(height: 18),
              _Actions(order: order),
            ],
          ),
        ),
      ),
    );
  }

}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final view = order.statusView;

    final colour = view.isFailure
        ? brand.error
        : (order.isActive ? brand.secondary : brand.success);

    final eta = order.etaMinutes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: colour.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  view.label,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: colour,
                  ),
                ),
              ),
              if (order.isTrackable && eta != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      eta == 0 ? 'Any moment' : '$eta min',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colour,
                      ),
                    ),
                    Text(
                      order.isPickup ? 'until ready' : 'until arrival',
                      style: TextStyle(fontSize: 11.5, color: brand.inkMuted),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            view.description,
            style: TextStyle(fontSize: 14, height: 1.45, color: brand.inkMuted),
          ),
          if (order.timing.isDelayed && order.isActive) ...[
            const SizedBox(height: 10),
            AppNotice(
              tone: NoticeTone.caution,
              message: 'This order is running a little late. We are sorry about the wait.',
            ),
          ],
          if (order.isScheduled && order.scheduledFor != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.event_rounded, size: 15, color: brand.inkMuted),
                const SizedBox(width: 6),
                Text(
                  'Scheduled for ${Fmt.dayTime(order.scheduledFor)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: brand.ink,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentPending extends ConsumerWidget {
  const _PaymentPending({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final checkout = ref.watch(checkoutControllerProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brand.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment not completed',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: brand.warning,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Our kitchen has not received this order yet. Pay '
            '${Fmt.moneySmart(order.totals.payableAmount)} to confirm it. '
            'You will not be charged twice.',
            style: TextStyle(fontSize: 13.5, height: 1.45, color: brand.inkMuted),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: checkout.isBusy ? null : () => _pay(context, ref),
            style: FilledButton.styleFrom(backgroundColor: brand.warning),
            child: Text(
              checkout.isBusy
                  ? checkout.busyLabel
                  : 'Pay ${Fmt.moneySmart(order.totals.payableAmount)}',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(checkoutControllerProvider.notifier);
    final paid = await controller.payExistingOrder(order.id);

    if (!context.mounted) return;

    if (paid) {
      ref.invalidate(orderDetailProvider(order.id));
      AppFeedback.showSuccess(context, 'Payment confirmed. Your order is on its way.');
      controller.reset();
      return;
    }

    final error = ref.read(checkoutControllerProvider).error;
    if (error != null) AppFeedback.showError(context, error);
    controller.reset();
  }
}

/// The customer's delivery OTP.
///
/// It is read from the order row the customer already owns; the rider verifies it
/// server-side, so showing it here cannot be used to fake a delivery.
class _DeliveryOtpCard extends ConsumerWidget {
  const _DeliveryOtpCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brand.primary,
        borderRadius: BorderRadius.circular(brand.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share your delivery OTP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Your OTP was sent by SMS. Give it to the delivery partner only '
                  'when you have your order in hand.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The rider moving towards the customer.
///
/// Both pins come from the server: the rider's position via
/// `delivery_partner_locations`, which this screen already subscribes to, and the
/// destination from the order's own snapshot. The app never interpolates a
/// position between fixes — a customer watching a smoothly gliding marker that is
/// actually a guess is worse than one that steps every few seconds and is true.
class _RiderMap extends StatelessWidget {
  const _RiderMap({required this.rider, required this.order});

  final RiderInfo rider;
  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final location = rider.liveLocation;
    if (location == null || !location.hasPosition) return const SizedBox.shrink();

    return LiveMap(
      height: 210,
      points: [
        MapPoint(
          id: 'rider',
          latitude: location.latitude!,
          longitude: location.longitude!,
          label: rider.name,
          kind: MapPointKind.rider,
          caption: location.etaMinutes == null
              ? Fmt.distance(location.distanceKm)
              : 'about ${location.etaMinutes} min away',
        ),
        if (order.delivery.latitude != null && order.delivery.longitude != null)
          MapPoint(
            id: 'destination',
            latitude: order.delivery.latitude!,
            longitude: order.delivery.longitude!,
            label: 'Your address',
            kind: MapPointKind.customer,
          ),
      ],
    );
  }
}

class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.rider, required this.order});

  final RiderInfo rider;
  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final location = rider.liveLocation;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: brand.surfaceMuted,
                child: Icon(Icons.two_wheeler_rounded, size: 22, color: brand.inkMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rider.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: brand.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (rider.ratingAverage > 0) ...[
                          RatingChip(rating: rider.ratingAverage, dense: true),
                          const SizedBox(width: 8),
                        ],
                        if (rider.vehicleNumber != null)
                          Text(
                            rider.vehicleNumber!,
                            style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (rider.canCall)
                IconButton.filledTonal(
                  onPressed: () => Launcher.dial(rider.phone),
                  icon: const Icon(Icons.call_rounded, size: 20),
                  tooltip: 'Call the delivery partner',
                ),
            ],
          ),
          if (location != null && location.isFresh) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: brand.secondary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(brand.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(Icons.near_me_rounded, size: 16, color: brand.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location.distanceKm == null
                          ? 'On the way to you'
                          : '${Fmt.distance(location.distanceKm)} away'
                              '${location.etaMinutes == null ? '' : ' · about ${location.etaMinutes} min'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: brand.secondary,
                      ),
                    ),
                  ),
                  if (location.hasPosition)
                    TextButton(
                      onPressed: () => Launcher.showOnMap(
                        latitude: location.latitude!,
                        longitude: location.longitude!,
                        label: rider.name,
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('View on map'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: brand.ink,
            ),
          ),
          const SizedBox(height: 10),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FoodTypeMark(foodType: item.foodType, size: 11),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.quantity} × ${item.productName}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration:
                                item.isCancelled ? TextDecoration.lineThrough : null,
                            color: item.isCancelled ? brand.inkMuted : brand.ink,
                          ),
                        ),
                        if (item.configurationLabel.isNotEmpty)
                          Text(
                            item.configurationLabel,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.3,
                              color: brand.inkMuted,
                            ),
                          ),
                        if ((item.specialInstructions ?? '').isNotEmpty)
                          Text(
                            item.specialInstructions!,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: brand.inkMuted,
                            ),
                          ),
                        if (item.refundedQuantity > 0)
                          Text(
                            '${item.refundedQuantity} refunded',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: brand.success,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    Fmt.moneySmart(item.netAmount),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: brand.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if ((order.customerNote ?? '').isNotEmpty) ...[
            Divider(height: 18, color: brand.hairline),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit_note_rounded, size: 15, color: brand.inkMuted),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    order.customerNote!,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                      color: brand.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    if (!order.delivery.hasAddress) return const SizedBox.shrink();

    return _InfoCard(
      icon: Icons.location_on_outlined,
      title: 'Delivery address',
      body: order.delivery.formatted,
      footer: (order.delivery.instructions ?? '').isEmpty
          ? null
          : 'Note: ${order.delivery.instructions}',
      trailing: order.delivery.latitude == null
          ? null
          : IconButton(
              onPressed: () => Launcher.showOnMap(
                latitude: order.delivery.latitude!,
                longitude: order.delivery.longitude!,
              ),
              icon: Icon(Icons.map_outlined, size: 20, color: brand.inkMuted),
              tooltip: 'View on map',
            ),
    );
  }
}

class _PickupCard extends ConsumerWidget {
  const _PickupCard({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider).valueOrNull;
    final phone = config?.supportPhone;

    return _InfoCard(
      icon: Icons.storefront_outlined,
      title: 'Collect from',
      body: config?.branchName ?? 'Bites Box',
      footer: order.status == 'READY_FOR_PICKUP'
          ? 'Your order is packed and waiting at the counter.'
          : 'We will let you know the moment it is ready.',
      trailing: phone == null
          ? null
          : IconButton(
              onPressed: () => Launcher.dial(phone),
              icon: const Icon(Icons.call_rounded, size: 20),
              tooltip: 'Call the outlet',
            ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final payment = order.payment;

    return _InfoCard(
      icon: payment.isCod ? Icons.payments_outlined : Icons.credit_card_rounded,
      title: 'Payment',
      body: payment.label,
      footer: payment.isCod
          ? (payment.codStatus == 'COD_COLLECTED'
              ? 'Cash collected on delivery.'
              : 'Please have ${Fmt.moneySmart(order.totals.payableAmount)} ready.')
          : (payment.isPaid
              ? 'Paid ${Fmt.smartDateTime(payment.paidAt)}'
              : 'Awaiting confirmation'),
    );
  }
}

class _RefundsCard extends StatelessWidget {
  const _RefundsCard({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Refunds',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: brand.ink,
            ),
          ),
          const SizedBox(height: 10),
          ...order.refunds.map(
            (refund) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          refund.statusLabel,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: brand.ink,
                          ),
                        ),
                        Text(
                          refund.destination == 'WALLET'
                              ? 'To your Bites Box wallet'
                              : 'To your original payment method',
                          style: TextStyle(fontSize: 12, color: brand.inkMuted),
                        ),
                        Text(
                          Fmt.smartDateTime(refund.completedAt ?? refund.createdAt),
                          style: TextStyle(fontSize: 11.5, color: brand.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Fmt.moneySmart(refund.amount),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: brand.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            'Bank refunds usually appear within 5 to 7 working days.',
            style: TextStyle(fontSize: 12, height: 1.4, color: brand.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order updates',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: brand.ink,
            ),
          ),
          const SizedBox(height: 12),
          OrderTimeline(entries: order.timeline),
        ],
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        if (order.canCancel)
          OutlinedButton.icon(
            onPressed: () => CancelOrderSheet.show(context, orderId: order.id),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Cancel this order'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.brand.error,
              side: BorderSide(color: context.brand.error.withValues(alpha: 0.4)),
            ),
          ),
        if (order.canReview) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => ReviewSheet.show(
              context,
              orderId: order.id,
              isDelivery: !order.isPickup,
            ),
            icon: const Icon(Icons.star_rounded, size: 18),
            label: const Text('Rate this order'),
          ),
        ],
        if (order.canReorder) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _reorder(context, ref),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Order this again'),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => OrderHelpSheet.show(context, order: order),
          icon: const Icon(Icons.support_agent_rounded, size: 18),
          label: const Text('I need help with this order'),
        ),
      ],
    );
  }

  Future<void> _reorder(BuildContext context, WidgetRef ref) async {
    try {
      final skipped = await ref.read(cartProvider.notifier).reorder(order.id);
      if (!context.mounted) return;

      if (skipped.isNotEmpty) {
        AppFeedback.showInfo(
          context,
          '${skipped.map((item) => item.label).join(', ')} '
          '${skipped.length == 1 ? 'is' : 'are'} unavailable and was not added.',
        );
      }

      context.push(Routes.cart);
    } catch (error) {
      if (context.mounted) AppFeedback.showError(context, error);
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    this.footer,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? footer;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: brand.inkMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: brand.inkMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(fontSize: 14, height: 1.45, color: brand.ink),
                ),
                if (footer != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    footer!,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: brand.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
