import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/states.dart';
import '../data/order_models.dart';
import '../providers/customer_providers.dart';

/// Cancellation.
///
/// The refund and any fee are quoted by the server's cancellation policy for this
/// order's current status, so the customer agrees to a number that will actually
/// be honoured — the app never estimates it.
class CancelOrderSheet extends ConsumerStatefulWidget {
  const CancelOrderSheet({required this.orderId, super.key});

  final String orderId;

  static Future<void> show(BuildContext context, {required String orderId}) {
    return AppFeedback.sheet<void>(
      context,
      builder: (_) => CancelOrderSheet(orderId: orderId),
    );
  }

  @override
  ConsumerState<CancelOrderSheet> createState() => _CancelOrderSheetState();
}

class _CancelOrderSheetState extends ConsumerState<CancelOrderSheet> {
  String _reason = 'CUSTOMER_CHANGED_MIND';
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _cancel(CancellationOptions options) async {
    final confirmed = await AppFeedback.confirm(
      context,
      title: 'Cancel this order?',
      message: options.refundAmount > 0
          ? 'You will be refunded ${Fmt.moneySmart(options.refundAmount)}. '
              'This cannot be undone.'
          : 'This cannot be undone.',
      confirmLabel: 'Yes, cancel',
      cancelLabel: 'Keep order',
      destructive: true,
    );

    if (!confirmed || !mounted) return;
    setState(() => _busy = true);

    try {
      await ref.read(orderRepositoryProvider).cancel(
            orderId: widget.orderId,
            reason: _reason,
            note: _note.text,
          );

      if (!mounted) return;
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.invalidate(activeOrdersProvider);
      ref.invalidate(myOrdersProvider);

      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Your order has been cancelled.');
    } catch (error) {
      if (!mounted) return;
      AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final options = ref.watch(cancellationOptionsProvider(widget.orderId));

    return AsyncValueView<CancellationOptions>(
      value: options,
      compact: true,
      onRetry: () => ref.invalidate(cancellationOptionsProvider(widget.orderId)),
      loading: const SizedBox(height: 200, child: AppLoader()),
      data: (data) {
        if (!data.canCancel) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SheetHeader(title: 'Cannot cancel'),
                AppNotice(tone: NoticeTone.caution, message: data.message),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHeader(
                  title: 'Cancel your order',
                  subtitle: 'Tell us why so we can do better.',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: data.hasFee
                          ? brand.warning.withValues(alpha: 0.08)
                          : brand.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(brand.radiusMd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.refundAmount > 0
                              ? 'Refund: ${Fmt.moneySmart(data.refundAmount)}'
                              : 'No refund applies',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: data.hasFee ? brand.warning : brand.success,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.message,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: brand.inkMuted,
                          ),
                        ),
                        if (data.hasFee) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Cancellation fee: ${Fmt.moneySmart(data.cancellationFee)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: brand.warning,
                            ),
                          ),
                        ],
                        if (data.requiresApproval) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Our team will review this cancellation.',
                            style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: _reason,
                  onChanged: (value) =>
                      setState(() => _reason = value ?? _reason),
                  child: Column(
                    children: CancellationOptions.customerReasons.entries
                        .map(
                          (entry) => RadioListTile<String>(
                            value: entry.key,
                            dense: true,
                            title: Text(entry.value),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: TextField(
                    controller: _note,
                    maxLines: 2,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      hintText: 'Anything else we should know? (optional)',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => Navigator.of(context).pop(),
                          child: const Text('Keep order'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy ? null : () => _cancel(data),
                          style: FilledButton.styleFrom(backgroundColor: brand.error),
                          child: Text(_busy ? 'Cancelling…' : 'Cancel order'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
