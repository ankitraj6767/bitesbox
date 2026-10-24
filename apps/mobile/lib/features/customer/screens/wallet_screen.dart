import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../../../l10n/customer_copy.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/states.dart';
import '../data/account_models.dart';
import '../data/payment_repository.dart';
import '../providers/customer_providers.dart';

/// Wallet balance and ledger.
///
/// The balance is a server-maintained ledger total, not a sum of the rows shown
/// here — only the last fifty transactions are fetched, and the balance stays
/// correct regardless.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  static const double _minimumTopUp = 100;
  static const double _maximumTopUp = 10000;

  bool _addingMoney = false;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.customerText("Bites Box wallet"))),
      body: AsyncValueView<WalletSummary>(
        value: wallet,
        onRetry: () => ref.invalidate(walletProvider),
        data: (data) {
          if (!data.enabled) {
            return AppEmptyState(
              title: context.customerText("Wallet is not available"),
              message: context.customerText("This feature is currently switched off."),
              icon: Icons.account_balance_wallet_outlined,
            );
          }

          return RefreshIndicator(
            color: brand.primary,
            onRefresh: () async {
              ref.invalidate(walletProvider);
              await ref.read(walletProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        brand.secondary,
                        brand.secondary.withValues(alpha: 0.82),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(brand.radiusLg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.customerText('Available balance'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        Fmt.moneyPrecise(data.balance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        data.isFrozen
                            ? context.customerText('Your wallet is on hold. Please contact support.')
                            : context.customerText('Applied to your order total automatically at checkout.'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!data.isFrozen) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _addingMoney ? null : _chooseTopUpAmount,
                      icon: _addingMoney
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_rounded),
                      label: Text(
                        context.customerText(
                          _addingMoney ? 'Opening secure checkout…' : 'Add money',
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: brand.primary,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(brand.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: brand.inkMuted,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          context.customerText('Secure checkout · Add ₹100–₹10,000 · Use wallet at Bites Box'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: brand.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (data.isFrozen) ...[
                  const SizedBox(height: 14),
                  AppNotice(
                    tone: NoticeTone.caution,
                    message:
                        'While your wallet is on hold you can still pay by card, UPI or cash.',
                    action: TextButton(
                      onPressed: () => context.push(Routes.support),
                      child: Text(context.customerText("Contact us")),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                        context.customerText('Transactions'),
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: brand.ink,
                  ),
                ),
                const SizedBox(height: 10),
                if (data.transactions.isEmpty)
                  AppEmptyState(
                    title: context.customerText("Nothing here yet"),
                    message: context.customerText("Top-ups, refunds and cashback will show up here."),
                    icon: Icons.receipt_outlined,
                    compact: true,
                  )
                else
                  ...data.transactions.map(
                    (transaction) => _TransactionTile(transaction: transaction),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _chooseTopUpAmount() async {
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.brand.surface,
      builder: (_) =>
          const _AddMoneySheet(minimum: _minimumTopUp, maximum: _maximumTopUp),
    );
    if (!mounted || amount == null) return;
    await _startTopUp(amount);
  }

  Future<void> _startTopUp(double amount) async {
    if (_addingMoney) return;
    setState(() => _addingMoney = true);

    try {
      final repository = ref.read(paymentRepositoryProvider);
      final session = await repository.createWalletTopUpSession(
        amount: amount,
        idempotencyKey: _newIdempotencyKey(),
      );
      if (!mounted) return;

      final result = await _openCheckout(session);
      if (!mounted) return;

      if (result.cancelled) {
        AppFeedback.showInfo(
          context,
          'Payment cancelled. Your wallet was not charged.',
        );
        return;
      }
      if (!result.success ||
          result.paymentId == null ||
          result.signature == null) {
        AppFeedback.showError(
          context,
          result.message ??
              'The payment could not be completed. Please try again.',
        );
        return;
      }

      final verification = await repository.verifyWalletTopUp(
        razorpayOrderId: result.orderId ?? session.providerOrderId,
        razorpayPaymentId: result.paymentId!,
        razorpaySignature: result.signature!,
      );
      if (!mounted) return;
      ref.invalidate(walletProvider);

      if (verification.verified) {
        await ref.read(walletProvider.future);
        if (mounted) {
          AppFeedback.showSuccess(
            context,
            context.customerText(
              '{amount} added to your wallet',
              values: {'amount': Fmt.moneyPrecise(amount)},
            ),
          );
        }
      } else if (mounted) {
        AppFeedback.showInfo(
          context,
          verification.message ??
              'Payment is processing. Refresh your wallet shortly.',
        );
      }
    } catch (error) {
      // A webhook can finish a captured payment even if the app loses its
      // connection during verification, so refresh before reporting the error.
      if (mounted) {
        ref.invalidate(walletProvider);
        AppFeedback.showError(context, error);
      }
    } finally {
      if (mounted) setState(() => _addingMoney = false);
    }
  }

  Future<_WalletGatewayResult> _openCheckout(WalletTopUpSession session) async {
    final gateway = Razorpay();
    final completer = Completer<_WalletGatewayResult>();

    gateway.on(Razorpay.EVENT_PAYMENT_SUCCESS, (
      PaymentSuccessResponse response,
    ) {
      if (!completer.isCompleted) {
        completer.complete(
          _WalletGatewayResult.success(
            paymentId: response.paymentId,
            orderId: response.orderId,
            signature: response.signature,
          ),
        );
      }
    });
    gateway.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      if (!completer.isCompleted) {
        completer.complete(
          _WalletGatewayResult.failure(
            cancelled: response.code == Razorpay.PAYMENT_CANCELLED,
            message: response.message,
          ),
        );
      }
    });

    try {
      gateway.open(session.toCheckoutOptions());
      final result = await completer.future;
      gateway.clear();
      return result;
    } catch (error) {
      gateway.clear();
      return _WalletGatewayResult.failure(message: error.toString());
    }
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return 'wallet_${base64UrlEncode(bytes).replaceAll('=', '')}';
  }
}

class _AddMoneySheet extends StatefulWidget {
  const _AddMoneySheet({required this.minimum, required this.maximum});

  final double minimum;
  final double maximum;

  @override
  State<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends State<_AddMoneySheet> {
  static const _suggestions = [200.0, 500.0, 1000.0, 2000.0];

  final _amountController = TextEditingController(text: '500');

  double? get _amount => double.tryParse(_amountController.text.trim());

  bool get _isValid {
    final amount = _amount;
    return amount != null &&
        amount >= widget.minimum &&
        amount <= widget.maximum &&
        (amount * 100 - (amount * 100).round()).abs() < 0.000001;
  }

  String? get _amountError {
    final amount = _amount;
    if (amount == null) return 'Enter a valid amount';
    if (amount < widget.minimum || amount > widget.maximum) {
      return 'Choose an amount within the allowed range';
    }
    if ((amount * 100 - (amount * 100).round()).abs() >= 0.000001) {
      return 'Use up to two decimal places';
    }
    return null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final amount = _amount;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.customerText('Add money to your wallet'),
            style: TextStyle(
              color: brand.ink,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            context.customerText('Choose an amount. Your balance updates after secure payment confirmation.'),
            style: TextStyle(color: brand.inkMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          Text(
            context.customerText('Quick add'),
            style: TextStyle(
              color: brand.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((suggestion) {
              final selected = amount == suggestion;
              return ChoiceChip(
              label: Text(context.customerText('₹${suggestion.toStringAsFixed(0)}')),
                selected: selected,
                onSelected: (_) {
                  setState(
                    () =>
                        _amountController.text = suggestion.toStringAsFixed(0),
                  );
                },
                selectedColor: brand.primary.withValues(alpha: 0.12),
                labelStyle: TextStyle(
                  color: selected ? brand.primary : brand.ink,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: selected
                      ? brand.primary.withValues(alpha: 0.45)
                      : brand.hairline,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _amountController,
            autofocus: false,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.customerText("Amount"),
              prefixText: '₹ ',
              hintText: context.customerText("Enter amount"),
              helperText: context.customerText(
                'Minimum ₹{minimum} · Maximum ₹{maximum}',
                values: {
                  'minimum': widget.minimum.toStringAsFixed(0),
                  'maximum': widget.maximum.toStringAsFixed(0),
                },
              ),
              errorText: _amountError == null
                  ? null
                  : context.customerText(_amountError!),
              filled: true,
              fillColor: brand.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(brand.radiusMd),
                borderSide: BorderSide(color: brand.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(brand.radiusMd),
                borderSide: BorderSide(color: brand.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(brand.radiusMd),
                borderSide: BorderSide(color: brand.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _isValid
                  ? () => Navigator.of(context).pop(amount)
                  : null,
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: Text(
                _isValid
                    ? context.customerText(
                        'Continue · {amount}',
                        values: {'amount': Fmt.moneyPrecise(amount!)},
                      )
                    : context.customerText('Continue to payment'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: brand.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(brand.radiusMd),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              context.customerText('Payments are securely processed by Razorpay.'),
              style: TextStyle(color: brand.inkMuted, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletGatewayResult {
  const _WalletGatewayResult._({
    this.success = false,
    this.cancelled = false,
    this.paymentId,
    this.orderId,
    this.signature,
    this.message,
  });

  factory _WalletGatewayResult.success({
    String? paymentId,
    String? orderId,
    String? signature,
  }) => _WalletGatewayResult._(
    success: true,
    paymentId: paymentId,
    orderId: orderId,
    signature: signature,
  );

  factory _WalletGatewayResult.failure({
    bool cancelled = false,
    String? message,
  }) => _WalletGatewayResult._(cancelled: cancelled, message: message);

  final bool success;
  final bool cancelled;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? message;
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final debit = transaction.isDebit;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (debit ? brand.error : brand.success).withValues(
                alpha: 0.10,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              debit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 17,
              color: debit ? brand.error : brand.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.customerText(transaction.description),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: brand.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${context.customerText(transaction.kindLabel)} · ${Fmt.smartDateTime(transaction.createdAt)}',
                  style: TextStyle(fontSize: 12, color: brand.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${debit ? '' : '+'}${Fmt.moneyPrecise(transaction.amount)}',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: debit ? brand.ink : brand.success,
                ),
              ),
              Text(
                context.customerText(
                  'Balance {amount}',
                  values: {'amount': Fmt.moneySmart(transaction.balanceAfter)},
                ),
                style: TextStyle(fontSize: 11.5, color: brand.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
