import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/states.dart';
import '../data/cart_models.dart';
import '../providers/cart_controller.dart';
import '../providers/checkout_controller.dart';
import '../providers/customer_providers.dart';
import '../widgets/bill_summary.dart';
import 'coupon_sheet.dart';

/// Checkout: fulfilment, timing, payment.
///
/// Changing any option re-prices the whole basket on the server, so the total on
/// screen is always the one that will be charged. The button is disabled until the
/// server itself says the order is valid.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _paymentMode = 'ONLINE';
  double _tip = 0;

  /// Loyalty redemption is a phase-two switch; the quote already accepts it, so
  /// the value is threaded through at zero until the screen exposes a control.
  final int _loyaltyPoints = 0;

  static const _tipOptions = <double>[0, 10, 20, 30, 50];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reprice());
  }

  Future<void> _reprice() async {
    try {
      await ref
          .read(cartProvider.notifier)
          .reprice(
            paymentMode: _paymentMode,
            tipAmount: _tip,
            loyaltyPoints: _loyaltyPoints,
          );
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    }
  }

  Future<void> _setPaymentMode(String mode) async {
    setState(() => _paymentMode = mode);
    await _reprice();
  }

  Future<void> _setFulfilment(String fulfilmentType) async {
    try {
      await ref.read(cartProvider.notifier).setFulfilment(fulfilmentType);

      // Pickup is settled at the kitchen counter; delivery falls back to COD
      // when Razorpay is not configured in this build.
      final paymentMode = fulfilmentType == 'PICKUP'
          ? 'PAY_AT_STORE'
          : 'ONLINE';
      if (mounted) setState(() => _paymentMode = paymentMode);
      await _reprice();
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    }
  }

  Future<void> _setTip(double tip) async {
    setState(() => _tip = tip);
    await _reprice();
  }

  Future<void> _placeOrder() async {
    final controller = ref.read(checkoutControllerProvider.notifier);

    final orderId = await controller.submit(
      paymentMode: _paymentMode,
      tipAmount: _tip,
      loyaltyPoints: _loyaltyPoints,
    );

    if (!mounted) return;
    final state = ref.read(checkoutControllerProvider);

    if (state.isComplete && orderId != null) {
      controller.reset();
      context.go(Routes.order(orderId));
      return;
    }

    if (state.paymentCancelled && orderId != null) {
      // The order exists and is payable: tracking is where they can retry.
      AppFeedback.showInfo(
        context,
        'Your order is saved. Finish the payment to confirm it.',
      );
      controller.reset();
      context.go(Routes.order(orderId));
      return;
    }

    final error = state.error;
    if (error != null) {
      AppFeedback.showError(context, error);
      if (orderId != null) context.go(Routes.order(orderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: AsyncValueView<CheckoutQuote>(
        value: cart,
        onRetry: () => ref.read(cartProvider.notifier).refresh(),
        data: (quote) {
          if (quote.isEmpty) {
            return AppEmptyState(
              title: 'Your cart is empty',
              message: 'Add something delicious before checking out.',
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
                  child: AppNotice(
                    tone: NoticeTone.critical,
                    message: issue.message,
                  ),
                ),
              ),
              ...quote.warnings.map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppNotice(message: issue.message),
                ),
              ),
              _FulfilmentPicker(quote: quote, onChanged: _setFulfilment),
              const SizedBox(height: 14),
              if (quote.isDelivery) ...[
                _AddressCard(quote: quote),
                const SizedBox(height: 14),
              ],
              _TimingCard(quote: quote),
              const SizedBox(height: 14),
              _PaymentPicker(
                quote: quote,
                selected: _paymentMode,
                onChanged: _setPaymentMode,
              ),
              const SizedBox(height: 14),
              _WalletCard(quote: quote),
              if (quote.isDelivery) ...[
                const SizedBox(height: 14),
                _TipPicker(
                  options: _tipOptions,
                  selected: _tip,
                  onChanged: _setTip,
                ),
              ],
              const SizedBox(height: 14),
              _CouponTile(quote: quote),
              const SizedBox(height: 14),
              BillSummary(
                totals: quote.totals,
                couponCode: quote.appliedCouponCode,
                promotionLabel:
                    quote.promotion?.headline ?? quote.promotion?.name,
                isDelivery: quote.isDelivery,
                showTaxBreakdown: true,
              ),
              const SizedBox(height: 14),
              _PromiseCard(quote: quote),
            ],
          );
        },
      ),
      bottomNavigationBar: _CheckoutFooter(
        quote: cart.valueOrNull,
        paymentMode: _paymentMode,
        onPlaceOrder: _placeOrder,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: brand.ink,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _FulfilmentPicker extends ConsumerWidget {
  const _FulfilmentPicker({required this.quote, required this.onChanged});

  final CheckoutQuote quote;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider).valueOrNull;
    final pickupEnabled = config?.flag('self_pickup', fallback: true) ?? true;

    return _SectionCard(
      title: 'How would you like it?',
      child: SegmentedButton<String>(
        segments: [
          const ButtonSegment(
            value: 'DELIVERY',
            label: Text('Delivery'),
            icon: Icon(Icons.delivery_dining_rounded, size: 18),
          ),
          ButtonSegment(
            value: 'PICKUP',
            label: const Text('Pick up'),
            icon: const Icon(Icons.storefront_rounded, size: 18),
            enabled: pickupEnabled,
          ),
        ],
        selected: {quote.fulfilmentType},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard({required this.quote});

  final CheckoutQuote quote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final addresses = ref.watch(addressesProvider);

    return _SectionCard(
      title: 'Deliver to',
      trailing: TextButton(
        onPressed: () => context.push(Routes.addresses),
        child: Text(quote.addressId == null ? 'Add' : 'Change'),
      ),
      child: addresses.maybeWhen(
        data: (list) {
          final matches = list
              .where((item) => item.id == quote.addressId)
              .toList();
          final selected = matches.isEmpty ? null : matches.first;

          if (selected == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose where we should deliver this order.',
                  style: TextStyle(fontSize: 13.5, color: brand.inkMuted),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push(Routes.addresses),
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: const Text('Choose an address'),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: brand.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selected.labelText,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: brand.ink,
                    ),
                  ),
                  if (quote.delivery.zoneName != null) ...[
                    const Spacer(),
                    Text(
                      quote.delivery.zoneName!,
                      style: TextStyle(fontSize: 12, color: brand.inkMuted),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Text(
                selected.singleLine,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: brand.inkMuted,
                ),
              ),
              if (quote.delivery.distanceKm != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${Fmt.distance(quote.delivery.distanceKm)} from our kitchen',
                  style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
                ),
              ],
            ],
          );
        },
        orElse: () => const SkeletonBox(height: 44),
      ),
    );
  }
}

class _TimingCard extends ConsumerWidget {
  const _TimingCard({required this.quote});

  final CheckoutQuote quote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final config = ref.watch(appConfigProvider).valueOrNull;
    final schedulingEnabled =
        config?.flag('scheduled_orders', fallback: true) ?? true;

    return _SectionCard(
      title: 'When?',
      child: RadioGroup<String>(
        groupValue: quote.timing,
        // Choosing "later" opens the slot picker; the server still validates the
        // slot, so an out-of-hours choice is refused there rather than here.
        onChanged: (value) => value == 'SCHEDULED'
            ? _pickSlot(context, ref)
            : _setNow(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioListTile<String>(
              value: 'NOW',
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('As soon as possible'),
              subtitle: Text(
                'Ready in about ${Fmt.duration(quote.timingEstimate.totalMinutes)}',
                style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
              ),
            ),
            if (schedulingEnabled)
              RadioListTile<String>(
                value: 'SCHEDULED',
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Schedule for later'),
                subtitle: Text(
                  quote.scheduledFor == null
                      ? 'Pick a slot at least 30 minutes from now'
                      : Fmt.dayTime(quote.scheduledFor),
                  style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
                ),
              ),
            if (quote.isScheduled && quote.scheduledFor != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _pickSlot(context, ref),
                  icon: const Icon(Icons.schedule_rounded, size: 16),
                  label: const Text('Change slot'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setNow(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(cartProvider.notifier).setTimingNow();
    } catch (error) {
      if (context.mounted) AppFeedback.showError(context, error);
    }
  }

  /// The server rejects anything under 30 minutes or beyond 7 days; the picker
  /// starts inside those bounds so a customer is not told off for guessing.
  Future<void> _pickSlot(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final earliest = now.add(const Duration(minutes: 35));

    final date = await showDatePicker(
      context: context,
      initialDate: earliest,
      firstDate: earliest,
      lastDate: now.add(const Duration(days: 7)),
      helpText: 'Choose a delivery date',
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(earliest),
      helpText: 'Choose a delivery time',
    );
    if (time == null || !context.mounted) return;

    final slot = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (slot.isBefore(earliest)) {
      AppFeedback.showInfo(
        context,
        'Please choose a slot at least 30 minutes from now.',
      );
      return;
    }

    try {
      await ref.read(cartProvider.notifier).scheduleFor(slot);
    } catch (error) {
      if (context.mounted) AppFeedback.showError(context, error);
    }
  }
}

class _PaymentPicker extends ConsumerWidget {
  const _PaymentPicker({
    required this.quote,
    required this.selected,
    required this.onChanged,
  });

  final CheckoutQuote quote;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;

    // COD availability is decided by the server (zone rules, value caps, pickup);
    // its verdict arrives as a blocking issue on the quote.
    final codIssue =
        quote.issueWithCode('COD_UNAVAILABLE') ??
        quote.issueWithCode('COD_LIMIT_EXCEEDED') ??
        quote.issueWithCode('COD_MIN_ORDER_NOT_MET');

    final codBlocked = codIssue != null && selected != 'ONLINE';
    // The server returns the public Razorpay key from create-payment. The APK
    // must not carry a compile-time gateway key or disable the option locally.
    const onlineAvailable = true;

    return _SectionCard(
      title: 'Payment',
      child: RadioGroup<String>(
        groupValue: selected,
        onChanged: (value) {
          if (value == null) return;
          onChanged(value);
        },
        child: Column(
          children: [
            RadioListTile<String>(
              value: 'ONLINE',
              contentPadding: EdgeInsets.zero,
              dense: true,
              enabled: onlineAvailable,
              title: const Text('Pay online'),
              subtitle: Text(
                'UPI, cards, netbanking and wallets',
                style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
              ),
            ),
            if (quote.isDelivery)
              RadioListTile<String>(
                value: 'COD',
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Cash on delivery'),
                subtitle: Text(
                  codBlocked
                      ? codIssue.message
                      : 'Pay the delivery partner when your order arrives',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: codBlocked ? brand.error : brand.inkMuted,
                  ),
                ),
              )
            else
              RadioListTile<String>(
                value: 'PAY_AT_STORE',
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Pay at the counter'),
                subtitle: Text(
                  'Settle the bill when you collect your order',
                  style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WalletCard extends ConsumerWidget {
  const _WalletCard({required this.quote});

  final CheckoutQuote quote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final wallet = ref.watch(walletProvider).valueOrNull;

    if (wallet == null || !wallet.enabled || wallet.balance <= 0) {
      return const SizedBox.shrink();
    }

    final applied = quote.totals.walletApplied > 0;

    return _SectionCard(
      title: 'Bites Box wallet',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wallet.isFrozen)
            Text(
              'Your wallet is on hold. Please contact support.',
              style: TextStyle(fontSize: 13, color: brand.warning),
            )
          else
            SwitchListTile.adaptive(
              value: applied,
              contentPadding: EdgeInsets.zero,
              title: Text('Use my ${Fmt.moneySmart(wallet.balance)} balance'),
              subtitle: Text(
                applied
                    ? '${Fmt.moneySmart(quote.totals.walletApplied)} applied to this order'
                    : 'Applied to the order total first',
                style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
              ),
              onChanged: (value) => _toggle(context, ref, value),
            ),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool value) async {
    try {
      await ref.read(cartProvider.notifier).setUseWallet(value);
    } catch (error) {
      if (context.mounted) AppFeedback.showError(context, error);
    }
  }
}

class _TipPicker extends StatelessWidget {
  const _TipPicker({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<double> options;
  final double selected;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return _SectionCard(
      title: 'Tip your delivery partner',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The full tip goes to your delivery partner.',
            style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: options
                .map(
                  (amount) => ChoiceChip(
                    label: Text(
                      amount == 0 ? 'No tip' : Fmt.moneySmart(amount),
                    ),
                    selected: selected == amount,
                    onSelected: (_) => onChanged(amount),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _CouponTile extends StatelessWidget {
  const _CouponTile({required this.quote});

  final CheckoutQuote quote;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final applied = quote.appliedCouponCode;

    return _SectionCard(
      title: 'Offers',
      trailing: TextButton(
        onPressed: () => CouponSheet.show(context),
        child: Text(applied == null ? 'View offers' : 'Change'),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 17,
            color: applied == null ? brand.inkMuted : brand.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              applied == null
                  ? (quote.promotion?.applied == true
                        ? '${quote.promotion!.headline ?? 'An offer'} applied automatically'
                        : 'No coupon applied')
                  : '$applied · saving ${Fmt.moneySmart(quote.totals.couponDiscount)}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: applied == null ? FontWeight.w500 : FontWeight.w700,
                color: applied == null ? brand.inkMuted : brand.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromiseCard extends StatelessWidget {
  const _PromiseCard({required this.quote});

  final CheckoutQuote quote;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final estimate = quote.timingEstimate;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            quote.isPickup
                ? Icons.storefront_rounded
                : Icons.delivery_dining_rounded,
            size: 20,
            color: brand.secondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.isScheduled
                      ? 'Scheduled for ${Fmt.dayTime(quote.scheduledFor)}'
                      : (quote.isPickup
                            ? 'Ready to collect in ${Fmt.duration(estimate.prepMinutes)}'
                            : 'Arriving in about ${Fmt.duration(estimate.totalMinutes)}'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: brand.secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  quote.isPickup
                      ? 'We will let you know the moment it is packed.'
                      : 'Cooking takes about ${Fmt.duration(estimate.prepMinutes)}, '
                            'delivery about ${Fmt.duration(estimate.deliveryMinutes)}.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: brand.inkMuted,
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

class _CheckoutFooter extends ConsumerWidget {
  const _CheckoutFooter({
    required this.quote,
    required this.paymentMode,
    required this.onPlaceOrder,
  });

  final CheckoutQuote? quote;
  final String paymentMode;
  final VoidCallback onPlaceOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final value = quote;
    final checkout = ref.watch(checkoutControllerProvider);

    if (value == null || value.isEmpty) return const SizedBox.shrink();

    final busy = checkout.isBusy || ref.watch(cartProvider).isLoading;
    final canPlace = value.isValid && !busy;

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
                      paymentMode == 'ONLINE'
                          ? 'Pay now'
                          : paymentMode == 'PAY_AT_STORE'
                          ? 'Pay at counter'
                          : 'Pay on delivery',
                      style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: canPlace ? onPlaceOrder : null,
                    child: busy
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(checkout.busyLabel),
                            ],
                          )
                        : Text(
                            paymentMode == 'ONLINE'
                                ? 'Pay ${Fmt.moneySmart(value.totals.payableAmount)}'
                                : 'Place order',
                          ),
                  ),
                ),
              ],
            ),
            if (!value.isValid && value.blockingMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                value.blockingMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: brand.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
