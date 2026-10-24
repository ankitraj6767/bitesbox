import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/states.dart';
import '../data/menu_models.dart';
import '../providers/cart_controller.dart';
import '../providers/customer_providers.dart';

/// Every offer, with the server's verdict on whether it applies to the current
/// cart and, when it does not, exactly what would make it apply.
class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final coupons = ref.watch(availableCouponsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Offers for you')),
      body: AsyncValueView<List<CustomerCoupon>>(
        value: coupons,
        onRetry: () => ref.invalidate(availableCouponsProvider),
        data: (list) {
          if (list.isEmpty) {
            return AppEmptyState(
              title: 'No offers right now',
              message: 'New offers are added regularly. Do check back.',
              icon: Icons.local_offer_outlined,
              action: FilledButton(
                onPressed: () => context.go(Routes.menu),
                child: const Text('Browse the menu'),
              ),
            );
          }

          return RefreshIndicator(
            color: brand.primary,
            onRefresh: () async {
              ref.invalidate(availableCouponsProvider);
              await ref.read(availableCouponsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _OfferCard(coupon: list[index]),
            ),
          );
        },
      ),
    );
  }
}

class _OfferCard extends ConsumerStatefulWidget {
  const _OfferCard({required this.coupon});

  final CustomerCoupon coupon;

  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  bool _busy = false;

  Future<void> _apply() async {
    setState(() => _busy = true);

    try {
      await ref.read(cartProvider.notifier).applyCoupon(widget.coupon.code);
      if (!mounted) return;

      final quote = ref.read(cartQuoteProvider);
      final applied = quote.coupon?.valid ?? false;

      if (applied) {
        AppFeedback.showSuccess(
          context,
          'Applied. You save ${Fmt.moneySmart(quote.totals.couponDiscount)}.',
        );
        context.push(Routes.cart);
      } else {
        AppFeedback.showInfo(
          context,
          quote.coupon?.message ?? 'That coupon could not be applied to your cart.',
        );
      }
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final coupon = widget.coupon;
    final usable = coupon.isApplicable ?? false;
    final cartEmpty = ref.watch(cartQuoteProvider).isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: brand.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.vertical(top: Radius.circular(brand.radiusMd)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.headline,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: brand.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        coupon.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: brand.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: brand.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: brand.primary, style: BorderStyle.solid),
                  ),
                  child: Text(
                    coupon.code,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: brand.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((coupon.description ?? '').isNotEmpty) ...[
                  Text(
                    coupon.description!,
                    style: TextStyle(fontSize: 14, height: 1.45, color: brand.inkMuted),
                  ),
                  const SizedBox(height: 10),
                ],
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    if (coupon.minOrderAmount > 0)
                      _Detail(
                        icon: Icons.shopping_bag_outlined,
                        text: 'Min order ${Fmt.moneySmart(coupon.minOrderAmount)}',
                      ),
                    if (coupon.maxDiscountAmount != null)
                      _Detail(
                        icon: Icons.trending_down_rounded,
                        text: 'Up to ${Fmt.moneySmart(coupon.maxDiscountAmount)}',
                      ),
                    if (coupon.endsAt != null)
                      _Detail(
                        icon: Icons.event_outlined,
                        text: 'Till ${Fmt.day(coupon.endsAt)}',
                      ),
                  ],
                ),
                if ((coupon.terms ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    coupon.terms!,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: brand.inkMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (cartEmpty)
                  OutlinedButton(
                    onPressed: () => context.go(Routes.menu),
                    child: const Text('Add items to use this'),
                  )
                else if (usable)
                  FilledButton(
                    onPressed: _busy ? null : _apply,
                    child: Text(
                      _busy
                          ? 'Applying…'
                          : ((coupon.estimatedDiscount ?? 0) > 0
                              ? 'Apply and save ${Fmt.moneySmart(coupon.estimatedDiscount)}'
                              : 'Apply to my cart'),
                    ),
                  )
                else
                  AppNotice(
                    tone: NoticeTone.caution,
                    message: coupon.reason ?? 'This offer does not apply to your cart.',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: brand.inkMuted),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: brand.inkMuted,
          ),
        ),
      ],
    );
  }
}
