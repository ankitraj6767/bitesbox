import 'package:flutter/material.dart';

import '../../../core/theme/brand_tokens.dart';
import '../../../shared/format.dart';
import '../data/order_models.dart';

/// The five-step tracker at the top of the tracking screen.
///
/// The active step comes from the order status, which only the server's state
/// machine can change — so the tracker can never run ahead of reality.
class OrderProgressBar extends StatelessWidget {
  const OrderProgressBar({required this.order, super.key});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final view = order.statusView;

    if (view.isFailure || view.step < 0) return const SizedBox.shrink();

    final steps = order.isPickup
        ? const ['Placed', 'Accepted', 'Preparing', 'Ready']
        : OrderStatusView.trackerSteps;

    // Pickup collapses "on the way" and "delivered" into "ready".
    final current = order.isPickup && view.step >= 4 ? 3 : view.step;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final segment = index ~/ 2;
            return Expanded(
              child: Container(
                height: 2.5,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: segment < current ? brand.success : brand.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }

          final step = index ~/ 2;
          final done = step < current;
          final active = step == current;

          return Column(
            children: [
              Container(
                width: active ? 22 : 18,
                height: active ? 22 : 18,
                decoration: BoxDecoration(
                  color: done
                      ? brand.success
                      : (active ? brand.primary : brand.surfaceMuted),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: done || active ? Colors.transparent : brand.hairline,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                    : (active
                        ? const Padding(
                            padding: EdgeInsets.all(5),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : null),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 62,
                child: Text(
                  steps[step],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.2,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: done || active ? brand.ink : brand.inkMuted,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// The full, auditable history of an order.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({required this.entries, super.key});

  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    if (entries.isEmpty) return const SizedBox.shrink();

    // Newest first: what just happened matters most.
    final ordered = entries.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(ordered.length, (index) {
        final entry = ordered[index];
        final isLatest = index == 0;
        final isLast = index == ordered.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: isLatest ? brand.primary : brand.hairline,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Container(width: 1.5, height: 34, color: brand.hairline),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isLatest ? FontWeight.w700 : FontWeight.w500,
                        color: brand.ink,
                      ),
                    ),
                    Text(
                      Fmt.smartDateTime(entry.createdAt),
                      style: TextStyle(fontSize: 12, color: brand.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
