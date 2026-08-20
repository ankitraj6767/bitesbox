import 'package:flutter/material.dart';

import '../../../core/theme/brand_tokens.dart';
import '../../../shared/format.dart';
import '../data/cart_models.dart';

/// The bill.
///
/// Every line is read from the server's computed totals. Nothing is summed here —
/// if a row is missing it is simply not shown, which is why the displayed total
/// always equals the amount that will be charged.
class BillSummary extends StatelessWidget {
  const BillSummary({
    required this.totals,
    this.couponCode,
    this.promotionLabel,
    this.isDelivery = true,
    this.showTaxBreakdown = false,
    super.key,
  });

  final CheckoutTotals totals;
  final String? couponCode;
  final String? promotionLabel;
  final bool isDelivery;
  final bool showTaxBreakdown;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill details',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: brand.ink,
            ),
          ),
          const SizedBox(height: 12),
          _Row(label: 'Item total', amount: totals.itemsSubtotal),
          if (totals.itemsDiscount > 0)
            _Row(
              label: 'Item discounts',
              amount: -totals.itemsDiscount,
              positive: true,
            ),
          if (totals.promotionDiscount > 0)
            _Row(
              label: promotionLabel ?? 'Offer applied',
              amount: -totals.promotionDiscount,
              positive: true,
            ),
          if (totals.couponDiscount > 0)
            _Row(
              label: couponCode == null ? 'Coupon discount' : 'Coupon $couponCode',
              amount: -totals.couponDiscount,
              positive: true,
            ),
          if (totals.packagingCharge > 0)
            _Row(label: 'Packaging', amount: totals.packagingCharge),
          if (isDelivery)
            _Row(
              label: 'Delivery fee',
              amount: totals.deliveryFee,
              strikethroughAmount:
                  totals.hasDeliveryWaiver ? totals.deliveryFeeWaived : null,
              freeLabel: totals.deliveryFee == 0 ? 'FREE' : null,
            ),
          if (totals.serviceFee > 0)
            _Row(label: 'Service fee', amount: totals.serviceFee),
          if (totals.taxAmount > 0)
            _Row(
              label: 'GST and charges',
              amount: totals.taxAmount,
              // Inclusive GST is already inside the item price; saying so avoids
              // the "why is tax added twice" question.
              note: 'included',
            ),
          if (showTaxBreakdown && totals.taxAmount > 0) ...[
            const SizedBox(height: 2),
            if (totals.cgstAmount > 0)
              _SubRow(label: 'CGST', amount: totals.cgstAmount),
            if (totals.sgstAmount > 0)
              _SubRow(label: 'SGST', amount: totals.sgstAmount),
            if (totals.igstAmount > 0)
              _SubRow(label: 'IGST', amount: totals.igstAmount),
            if (totals.cessAmount > 0)
              _SubRow(label: 'Cess', amount: totals.cessAmount),
          ],
          if (totals.tipAmount > 0)
            _Row(label: 'Tip for delivery partner', amount: totals.tipAmount),
          if (totals.loyaltyDiscount > 0)
            _Row(
              label: '${totals.loyaltyPointsRedeemed} loyalty points',
              amount: -totals.loyaltyDiscount,
              positive: true,
            ),
          if (totals.roundOff != 0)
            _Row(label: 'Round off', amount: totals.roundOff),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: brand.hairline),
          ),
          _Row(label: 'Order total', amount: totals.grandTotal, emphasis: true),
          if (totals.walletApplied > 0) ...[
            _Row(
              label: 'Paid from wallet',
              amount: -totals.walletApplied,
              positive: true,
            ),
            const SizedBox(height: 6),
            _Row(label: 'To pay now', amount: totals.payableAmount, emphasis: true),
          ],
          if (totals.hasSavings) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: brand.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(brand.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(Icons.savings_outlined, size: 16, color: brand.success),
                  const SizedBox(width: 8),
                  Text(
                    'You saved ${Fmt.moneySmart(totals.totalSavings)} on this order',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: brand.success,
                    ),
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

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.amount,
    this.positive = false,
    this.emphasis = false,
    this.note,
    this.strikethroughAmount,
    this.freeLabel,
  });

  final String label;
  final double amount;
  final bool positive;
  final bool emphasis;
  final String? note;
  final double? strikethroughAmount;
  final String? freeLabel;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final colour = positive ? brand.success : brand.ink;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: emphasis ? 15.5 : 14,
                    fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
                    color: emphasis ? brand.ink : brand.inkMuted,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    '($note)',
                    style: TextStyle(fontSize: 12, color: brand.inkMuted),
                  ),
                ],
              ],
            ),
          ),
          if (strikethroughAmount != null) ...[
            Text(
              Fmt.moneySmart(strikethroughAmount),
              style: TextStyle(
                fontSize: 13,
                color: brand.inkMuted,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            freeLabel ??
                (positive
                    ? '- ${Fmt.moneySmart(amount.abs())}'
                    : Fmt.moneySmart(amount)),
            style: TextStyle(
              fontSize: emphasis ? 15.5 : 14,
              fontWeight: emphasis || positive ? FontWeight.w700 : FontWeight.w600,
              color: freeLabel != null ? brand.success : colour,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
            ),
          ),
          Text(
            Fmt.moneyPrecise(amount),
            style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
          ),
        ],
      ),
    );
  }
}
