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
import '../data/cart_models.dart';
import '../providers/cart_controller.dart';
import '../widgets/bill_summary.dart';
import 'coupon_sheet.dart';

/// The cart.
///
/// Quantities, coupons and the bill are all server state. The screen's only jobs
/// are to send intents and to surface, in plain language, anything the server says
/// is blocking checkout.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final cart = ref.watch(cartProvider);
    final session = ref.watch(currentSessionProvider);

    if (session.isGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your cart')),
        body: AppEmptyState(
          title: 'Sign in to build your cart',
          message: 'Your cart is saved to your account so you can pick up where you left off.',
          icon: Icons.shopping_bag_outlined,
          action: FilledButton(
            onPressed: () => context.push(Routes.signIn),
            child: const Text('Sign in'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your cart'),
        actions: [
          if ((cart.valueOrNull?.lines.isNotEmpty ?? false))
            TextButton(
              onPressed: () => _clear(context, ref),
              child: Text('Clear', style: TextStyle(color: brand.error)),
            ),
        ],
      ),
      body: AsyncValueView<CheckoutQuote>(
        value: cart,
        onRetry: () => ref.read(cartProvider.notifier).refresh(),
        data: (quote) {
          if (quote.isEmpty) {
            return AppEmptyState(
              title: 'Your cart is empty',
              message: 'Add a few dishes from the menu and they will show up here.',
              icon: Icons.shopping_bag_outlined,
              action: FilledButton(
                onPressed: () => context.go(Routes.menu),
                child: const Text('Browse the menu'),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              ...quote.blockingIssues.map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppNotice(tone: NoticeTone.critical, message: issue.message),
                ),
              ),
              ...quote.warnings.map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppNotice(message: issue.message),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: brand.surface,
                  borderRadius: BorderRadius.circular(brand.radiusMd),
                  border: Border.all(color: brand.hairline),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < quote.lines.length; index++) ...[
                      if (index > 0)
                        Divider(height: 1, color: brand.hairline, indent: 14, endIndent: 14),
                      _CartLineTile(line: quote.lines[index]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _CouponRow(quote: quote),
              const SizedBox(height: 14),
              _FreeDeliveryNudge(quote: quote),
              BillSummary(
                totals: quote.totals,
                couponCode: quote.appliedCouponCode,
                promotionLabel: quote.promotion?.headline ?? quote.promotion?.name,
                isDelivery: quote.isDelivery,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _CartFooter(quote: cart.valueOrNull),
    );
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppFeedback.confirm(
      context,
      title: 'Clear your cart?',
      message: 'This removes every item you have added.',
      confirmLabel: 'Clear cart',
      destructive: true,
    );

    if (!confirmed) return;

    try {
      await ref.read(cartProvider.notifier).clear();
    } catch (error) {
      if (context.mounted) AppFeedback.showError(context, error);
    }
  }
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.line});

  final CheckoutLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final busy = ref.watch(cartProvider).isLoading;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FoodImage(path: line.imagePath, width: 52, height: 52, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FoodTypeMark(foodType: line.foodType, size: 11),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        line.productName,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: brand.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                if (line.configurationLabel.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    line.configurationLabel,
                    style: TextStyle(fontSize: 12.5, height: 1.3, color: brand.inkMuted),
                  ),
                ],
                if ((line.specialInstructions ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.edit_note_rounded, size: 13, color: brand.inkMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          line.specialInstructions!,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: brand.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (!line.isAvailable) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.error_outline_rounded, size: 14, color: brand.error),
                      const SizedBox(width: 5),
                      Text(
                        'Unavailable — remove to continue',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: brand.error,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    QuantityStepper(
                      quantity: line.quantity,
                      dense: true,
                      busy: busy,
                      onChanged: (next) => _setQuantity(context, ref, next),
                    ),
                    const Spacer(),
                    if (line.allocatedDiscount > 0) ...[
                      Text(
                        Fmt.moneySmart(line.grossAmount),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: brand.inkMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      Fmt.moneySmart(line.netAmount),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: brand.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setQuantity(BuildContext context, WidgetRef ref, int quantity) async {
    try {
      await ref
          .read(cartProvider.notifier)
          .setQuantity(cartItemId: line.cartItemId, quantity: quantity);
    } catch (error) {
      if (context.mounted) AppFeedback.showError(context, error);
    }
  }
}

class _CouponRow extends ConsumerWidget {
  const _CouponRow({required this.quote});

  final CheckoutQuote quote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final applied = quote.appliedCouponCode;

    return InkWell(
      onTap: () => CouponSheet.show(context),
      borderRadius: BorderRadius.circular(brand.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: brand.surface,
          borderRadius: BorderRadius.circular(brand.radiusMd),
          border: Border.all(
            color: applied == null ? brand.hairline : brand.success.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 19,
              color: applied == null ? brand.primary : brand.success,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: applied == null
                  ? Text(
                      'Apply a coupon',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: brand.ink,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$applied applied',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: brand.success,
                          ),
                        ),
                        Text(
                          'Saving ${Fmt.moneySmart(quote.totals.couponDiscount)}',
                          style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
                        ),
                      ],
                    ),
            ),
            if (applied != null)
              TextButton(
                onPressed: () => _remove(context, ref),
                child: const Text('Remove'),
              )
            else
              Icon(Icons.chevron_right_rounded, size: 20, color: brand.inkMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(cartProvider.notifier).removeCoupon();
    } catch (error) {
      if (context.mounted) AppFeedback.showError(context, error);
    }
  }
}

/// "Add ₹120 more for free delivery" — only shown when it is actually reachable.
class _FreeDeliveryNudge extends StatelessWidget {
  const _FreeDeliveryNudge({required this.quote});

  final CheckoutQuote quote;

  @override
  Widget build(BuildContext context) {
    if (!quote.isDelivery || quote.totals.deliveryFee <= 0) {
      return const SizedBox.shrink();
    }

    final shortfall =
        quote.delivery.shortfallToFreeDelivery(quote.totals.itemsSubtotal);
    if (shortfall == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppNotice(
        tone: NoticeTone.info,
        icon: Icons.delivery_dining_rounded,
        message:
            'Add ${Fmt.moneySmart(shortfall)} more to get free delivery on this order.',
      ),
    );
  }
}

class _CartFooter extends ConsumerWidget {
  const _CartFooter({required this.quote});

  final CheckoutQuote? quote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final value = quote;

    if (value == null || value.isEmpty) return const SizedBox.shrink();

    final blocking = value.blockingMessage;
    final canProceed = value.isValid;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: brand.surface,
        border: Border(top: BorderSide(color: brand.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!canProceed && blocking != null) ...[
              AppNotice(tone: NoticeTone.critical, message: blocking),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Fmt.moneySmart(value.totals.payableAmount),
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: brand.ink,
                      ),
                    ),
                    Text(
                      '${value.unitCount} item${value.unitCount == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    // Checkout stays reachable when the block is fixable there —
                    // choosing an address, for instance.
                    onPressed: canProceed || _fixableAtCheckout(value)
                        ? () => context.push(Routes.checkout)
                        : null,
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Blocks the checkout screen itself can resolve.
  bool _fixableAtCheckout(CheckoutQuote quote) {
    if (quote.hasUnavailableLines) return false;

    return quote.blockingIssues.every(
      (issue) =>
          issue.code == 'ADDRESS_REQUIRED' ||
          issue.code == 'ADDRESS_NOT_SERVICEABLE' ||
          issue.code == 'MIN_ORDER_NOT_MET' ||
          issue.code.startsWith('COD_'),
    );
  }
}
