import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';
import '../data/order_models.dart';
import '../providers/cart_controller.dart';
import '../providers/customer_providers.dart';
import 'review_sheet.dart';

/// Order history, split into what is happening now and what has already happened.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);

    if (session.isGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your orders')),
        body: AppEmptyState(
          title: 'Sign in to see your orders',
          message: 'Your order history and live tracking live in your account.',
          icon: Icons.receipt_long_outlined,
          action: FilledButton(
            onPressed: () => context.push(Routes.signIn),
            child: const Text('Sign in'),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your orders'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Active'), Tab(text: 'Past')],
          ),
        ),
        body: const TabBarView(
          children: [
            _OrderList(scope: 'CURRENT'),
            _OrderList(scope: 'PAST'),
          ],
        ),
      ),
    );
  }
}

class _OrderList extends ConsumerWidget {
  const _OrderList({required this.scope});

  final String scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final orders = ref.watch(myOrdersProvider(scope));

    return AsyncValueView<OrderList>(
      value: orders,
      onRetry: () => ref.invalidate(myOrdersProvider(scope)),
      loading: const _OrdersSkeleton(),
      data: (list) {
        if (list.orders.isEmpty) {
          return AppEmptyState(
            title: scope == 'CURRENT' ? 'No live orders' : 'No past orders yet',
            message: scope == 'CURRENT'
                ? 'When you place an order you can follow it here, step by step.'
                : 'Your completed orders will appear here.',
            icon: Icons.receipt_long_outlined,
            action: FilledButton(
              onPressed: () => context.go(Routes.menu),
              child: const Text('Browse the menu'),
            ),
          );
        }

        return RefreshIndicator(
          color: brand.primary,
          onRefresh: () async {
            ref.invalidate(myOrdersProvider(scope));
            await ref.read(myOrdersProvider(scope).future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _OrderCard(order: list.orders[index]),
          ),
        );
      },
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final view = order.statusView;

    final statusColour = view.isFailure
        ? brand.error
        : (order.isActive ? brand.secondary : brand.success);

    return Container(
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => context.push(Routes.order(order.id)),
            borderRadius: BorderRadius.vertical(top: Radius.circular(brand.radiusMd)),
            child: Padding
              (padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppPill(
                        label: view.label,
                        dense: true,
                        background: statusColour.withValues(alpha: 0.10),
                        foreground: statusColour,
                      ),
                      const Spacer(),
                      Text(
                        Fmt.smartDateTime(order.placedAt ?? order.createdAt),
                        style: TextStyle(fontSize: 12, color: brand.inkMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order.itemsPreview.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: FoodImage(
                            path: order.itemsPreview.first.imagePath,
                            width: 48,
                            height: 48,
                            radius: 10,
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.itemsLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                                color: brand.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${order.orderNumber} · ${Fmt.moneySmart(order.grandTotal)}'
                              '${order.isPickup ? ' · Pickup' : ''}',
                              style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: brand.inkMuted,
                      ),
                    ],
                  ),
                  if (order.isActive && order.promisedAt != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 14, color: brand.secondary),
                        const SizedBox(width: 6),
                        Text(
                          order.isPickup
                              ? 'Ready ${Fmt.until(order.promisedAt)}'
                              : 'Arriving ${Fmt.until(order.promisedAt)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: brand.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (order.refundedAmount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${Fmt.moneySmart(order.refundedAmount)} refunded',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: brand.success,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (order.awaitingPayment || order.canReview || !order.isActive)
            Divider(height: 1, color: brand.hairline),
          if (order.awaitingPayment)
            _CardAction(
              icon: Icons.payment_rounded,
              label: 'Finish payment',
              emphasis: true,
              onTap: () => context.push(Routes.order(order.id)),
            )
          else
            Row(
              children: [
                if (order.canReview)
                  Expanded(
                    child: _CardAction(
                      icon: Icons.star_outline_rounded,
                      label: 'Rate order',
                      onTap: () => ReviewSheet.show(
                        context,
                        orderId: order.id,
                        isDelivery: !order.isPickup,
                      ),
                    ),
                  ),
                if (order.canReview && !order.isActive)
                  Container(width: 1, height: 44, color: brand.hairline),
                if (!order.isActive)
                  Expanded(
                    child: _CardAction(
                      icon: Icons.refresh_rounded,
                      label: 'Reorder',
                      onTap: () => _reorder(context, ref),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _reorder(BuildContext context, WidgetRef ref) async {
    try {
      final skipped = await ref.read(cartProvider.notifier).reorder(order.id);
      if (!context.mounted) return;

      if (skipped.isEmpty) {
        AppFeedback.showSuccess(context, 'Added back to your cart.');
      } else {
        // Being specific about what was dropped beats a vague warning.
        AppFeedback.showInfo(
          context,
          'Added, but ${skipped.map((item) => item.label).join(', ')} '
          '${skipped.length == 1 ? 'is' : 'are'} unavailable.',
        );
      }

      context.push(Routes.cart);
    } catch (error) {
      if (context.mounted) AppFeedback.showError(context, error);
    }
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasis = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: emphasis ? brand.primary : brand.inkMuted),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: emphasis ? brand.primary : brand.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersSkeleton extends StatelessWidget {
  const _OrdersSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const SkeletonBox(height: 130, radius: 14),
    );
  }
}
