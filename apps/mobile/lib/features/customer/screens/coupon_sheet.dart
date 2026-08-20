import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/states.dart';
import '../data/menu_models.dart';
import '../providers/cart_controller.dart';
import '../providers/customer_providers.dart';

/// Coupon picker.
///
/// Applicability is decided by the server for this exact basket, so a coupon that
/// cannot be used is shown greyed out *with the reason* rather than hidden — that
/// is what turns "invalid coupon" into "add ₹80 more to use this".
class CouponSheet extends ConsumerStatefulWidget {
  const CouponSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AppFeedback.sheet<void>(
      context,
      expand: true,
      builder: (_) => const CouponSheet(),
    );
  }

  @override
  ConsumerState<CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends ConsumerState<CouponSheet> {
  final _controller = TextEditingController();
  String? _applying;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply(String code) async {
    setState(() => _applying = code);

    try {
      await ref.read(cartProvider.notifier).applyCoupon(code);
      if (!mounted) return;

      final quote = ref.read(cartQuoteProvider);
      final coupon = quote.coupon;

      // The server may accept the code but decide an automatic offer is better.
      if (coupon != null && !coupon.valid) {
        AppFeedback.showInfo(context, coupon.message ?? 'That coupon was not applied.');
      } else {
        Navigator.of(context).pop();
        AppFeedback.showSuccess(
          context,
          'Coupon applied. You saved ${Fmt.moneySmart(quote.totals.couponDiscount)}.',
        );
      }
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _applying = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupons = ref.watch(availableCouponsProvider);
    final applied = ref.watch(cartQuoteProvider).appliedCouponCode;

    return Column(
      children: [
        const SheetHeader(
          title: 'Offers for you',
          subtitle: 'Only one coupon can be used per order.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseFormatter()],
                  decoration: const InputDecoration(
                    hintText: 'Enter a coupon code',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) _apply(value.trim());
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _applying != null || _controller.text.trim().isEmpty
                      ? null
                      : () => _apply(_controller.text.trim()),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(84, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView<List<CustomerCoupon>>(
            value: coupons,
            onRetry: () => ref.invalidate(availableCouponsProvider),
            data: (list) {
              if (list.isEmpty) {
                return const AppEmptyState(
                  title: 'No offers right now',
                  message: 'New offers are added regularly. Do check back.',
                  icon: Icons.local_offer_outlined,
                  compact: true,
                );
              }

              // Usable coupons first, then the ones with an explanation.
              final sorted = [...list]..sort((a, b) {
                  final aOk = a.isApplicable ?? false;
                  final bOk = b.isApplicable ?? false;
                  if (aOk != bOk) return aOk ? -1 : 1;
                  return (b.estimatedDiscount ?? 0).compareTo(a.estimatedDiscount ?? 0);
                });

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _CouponCard(
                  coupon: sorted[index],
                  isApplied: sorted[index].code == applied,
                  busy: _applying == sorted[index].code,
                  onApply: () => _apply(sorted[index].code),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.coupon,
    required this.isApplied,
    required this.busy,
    required this.onApply,
  });

  final CustomerCoupon coupon;
  final bool isApplied;
  final bool busy;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final tokens = context.brand;
    final usable = coupon.isApplicable ?? false;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(
          color: isApplied
              ? tokens.success
              : (usable ? tokens.hairline : tokens.hairline.withValues(alpha: 0.6)),
          width: isApplied ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.primary.withValues(alpha: 0.35)),
                ),
                child: Text(
                  coupon.code,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: tokens.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  coupon.headline,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: usable ? tokens.ink : tokens.inkMuted,
                  ),
                ),
              ),
              if (isApplied)
                Icon(Icons.check_circle_rounded, size: 22, color: tokens.success)
              else
                TextButton(
                  onPressed: usable && !busy ? onApply : null,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 34),
                  ),
                  child: Text(busy ? 'Applying…' : 'Apply'),
                ),
            ],
          ),
          if ((coupon.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              coupon.description!,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: tokens.inkMuted),
            ),
          ],
          if (usable && (coupon.estimatedDiscount ?? 0) > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Saves about ${Fmt.moneySmart(coupon.estimatedDiscount)} on this order',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: tokens.success,
              ),
            ),
          ],
          if (!usable && (coupon.reason ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: tokens.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    coupon.reason!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.warning,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if ((coupon.terms ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              coupon.terms!,
              style: TextStyle(fontSize: 11.5, height: 1.35, color: tokens.inkMuted),
            ),
          ],
          if (coupon.endsAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Valid till ${Fmt.day(coupon.endsAt)}',
              style: TextStyle(fontSize: 11.5, color: tokens.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Coupon codes are stored upper case; normalising as the customer types avoids a
/// pointless round trip for "save20".
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
