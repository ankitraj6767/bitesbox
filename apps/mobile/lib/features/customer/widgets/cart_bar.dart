import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/format.dart';
import '../data/order_models.dart';
import '../providers/cart_controller.dart';
import '../providers/customer_providers.dart';

/// The floating cart bar shown above the menu and home screens.
///
/// Prices come straight from the server-computed quote; this widget only formats
/// them. It collapses to nothing when the cart is empty.
class CartBar extends ConsumerWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final quote = ref.watch(cartQuoteProvider);

    if (quote.isEmpty) return const SizedBox.shrink();

    final blocked = quote.hasUnavailableLines;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        height: 64,
        child: Material(
          color: blocked ? brand.warning : brand.primary,
          borderRadius: BorderRadius.circular(brand.radiusMd),
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.22),
          child: InkWell(
            onTap: () => context.push(Routes.cart),
            borderRadius: BorderRadius.circular(brand.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${quote.unitCount} item${quote.unitCount == 1 ? '' : 's'}'
                          ' · ${Fmt.moneySmart(quote.totals.grandTotal)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          blocked
                              ? 'An item is unavailable — tap to fix'
                              : (quote.totals.hasSavings
                                    ? 'Saving ${Fmt.moneySmart(quote.totals.totalSavings)}'
                                    : 'View cart'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 19,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A strip that surfaces orders still in flight, so a customer never has to hunt
/// for "where is my food".
class ActiveOrderStrip extends ConsumerWidget {
  const ActiveOrderStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final orders = ref.watch(_activeOrdersForStrip);

    if (orders.isEmpty) return const SizedBox.shrink();
    final order = orders.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: brand.secondary,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        child: InkWell(
          onTap: () => context.push(Routes.order(order.id)),
          borderRadius: BorderRadius.circular(brand.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.statusView.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        order.promisedAt == null
                            ? order.orderNumber
                            : 'Arriving ${Fmt.until(order.promisedAt)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Track',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kept private so the strip never blocks on a loading state.
final _activeOrdersForStrip = Provider<List<OrderSummary>>((ref) {
  return ref
      .watch(activeOrdersProvider)
      .maybeWhen(
        data: (orders) => orders,
        orElse: () => const <OrderSummary>[],
      );
});
