import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/errors/app_error.dart';
import '../data/payment_repository.dart';
import 'cart_controller.dart';
import 'customer_providers.dart';

/// Where the checkout flow currently is.
enum CheckoutStage {
  idle,
  placingOrder,
  startingPayment,
  awaitingPayment,
  verifyingPayment,
  done,
  failed,
}

class CheckoutState {
  const CheckoutState({
    this.stage = CheckoutStage.idle,
    this.order,
    this.error,
    this.paymentCancelled = false,
  });

  final CheckoutStage stage;
  final PlacedOrder? order;
  final AppError? error;

  /// The customer closed the payment sheet. The order exists and is payable, so
  /// this is a pause rather than a failure.
  final bool paymentCancelled;

  bool get isBusy =>
      stage == CheckoutStage.placingOrder ||
      stage == CheckoutStage.startingPayment ||
      stage == CheckoutStage.awaitingPayment ||
      stage == CheckoutStage.verifyingPayment;

  bool get isComplete => stage == CheckoutStage.done;

  /// Copy for the primary button while work is in progress.
  String get busyLabel => switch (stage) {
        CheckoutStage.placingOrder => 'Placing your order…',
        CheckoutStage.startingPayment => 'Opening payment…',
        CheckoutStage.awaitingPayment => 'Waiting for payment…',
        CheckoutStage.verifyingPayment => 'Confirming payment…',
        _ => 'Please wait…',
      };

  CheckoutState copyWith({
    CheckoutStage? stage,
    PlacedOrder? order,
    AppError? error,
    bool clearError = false,
    bool? paymentCancelled,
  }) {
    return CheckoutState(
      stage: stage ?? this.stage,
      order: order ?? this.order,
      error: clearError ? null : (error ?? this.error),
      paymentCancelled: paymentCancelled ?? this.paymentCancelled,
    );
  }
}

/// Drives order placement and payment.
///
/// The sequence is deliberately server-led:
///   1. `create-order` recalculates the whole bill and writes the order.
///   2. For an online order, `create-payment` mints (or reuses) the Razorpay order.
///   3. The SDK collects the payment.
///   4. `verify-payment` checks the signature and captures. Only then is the order
///      treated as paid — the SDK's success callback alone is never trusted.
///
/// A COD order skips steps 2–4 entirely.
class CheckoutController extends Notifier<CheckoutState> {
  Razorpay? _razorpay;
  Completer<_GatewayOutcome>? _pending;

  /// Stable for one checkout attempt, so a retry after a dropped connection
  /// returns the same order rather than creating a second one.
  String? _idempotencyKey;

  @override
  CheckoutState build() {
    ref.onDispose(_disposeGateway);
    return const CheckoutState();
  }

  void reset() {
    _idempotencyKey = null;
    state = const CheckoutState();
  }

  /// Places the order and, when required, collects payment.
  ///
  /// Returns the order id once the order exists — even if payment was cancelled —
  /// so the app can send the customer to a screen where they can pay again.
  Future<String?> submit({required String paymentMode, double tipAmount = 0, int loyaltyPoints = 0}) async {
    if (state.isBusy) return state.order?.orderId;

    _idempotencyKey ??= _newIdempotencyKey();
    state = state.copyWith(
      stage: CheckoutStage.placingOrder,
      clearError: true,
      paymentCancelled: false,
    );

    final payments = ref.read(paymentRepositoryProvider);
    PlacedOrder order;

    try {
      order = await payments.createOrder(
        idempotencyKey: _idempotencyKey!,
        paymentMode: paymentMode,
        cartId: ref.read(cartQuoteProvider).cartId,
        branchId: ref.read(activeBranchIdProvider),
        tipAmount: tipAmount,
        loyaltyPoints: loyaltyPoints,
      );
    } on AppError catch (error) {
      state = state.copyWith(stage: CheckoutStage.failed, error: error);
      // The cart may have been re-priced or an item may have sold out.
      ref.read(cartProvider.notifier).refresh();
      return null;
    }

    state = state.copyWith(order: order);

    if (!order.requiresPayment) {
      await _finish();
      return order.orderId;
    }

    final paid = await _collectPayment(order.orderId);
    if (paid) await _finish();

    return order.orderId;
  }

  /// Retries payment for an order that already exists (payment failed or the
  /// customer dismissed the sheet). No new order is ever created here.
  Future<bool> payExistingOrder(String orderId) async {
    if (state.isBusy) return false;

    state = state.copyWith(clearError: true, paymentCancelled: false);
    final paid = await _collectPayment(orderId);
    if (paid) await _finish();
    return paid;
  }

  Future<bool> _collectPayment(String orderId) async {
    if (!Env.onlinePaymentsEnabled) {
      state = state.copyWith(
        stage: CheckoutStage.failed,
        error: const AppError(
          code: 'PAYMENT_UNAVAILABLE',
          message: 'Online payment is not available in this build. Please choose cash on delivery.',
        ),
      );
      return false;
    }

    state = state.copyWith(stage: CheckoutStage.startingPayment);

    final payments = ref.read(paymentRepositoryProvider);
    PaymentSession session;

    try {
      session = await payments.createPaymentSession(orderId);
    } on AppError catch (error) {
      state = state.copyWith(stage: CheckoutStage.failed, error: error);
      return false;
    }

    state = state.copyWith(stage: CheckoutStage.awaitingPayment);

    final outcome = await _openGateway(session);

    if (outcome.cancelled) {
      state = state.copyWith(stage: CheckoutStage.idle, paymentCancelled: true);
      return false;
    }

    if (!outcome.succeeded) {
      state = state.copyWith(
        stage: CheckoutStage.failed,
        error: AppError(
          code: ErrorCodes.paymentFailed,
          message: outcome.message ?? 'The payment did not go through. Please try again.',
        ),
      );
      return false;
    }

    state = state.copyWith(stage: CheckoutStage.verifyingPayment);

    try {
      final verification = await payments.verifyPayment(
        razorpayOrderId: outcome.providerOrderId!,
        razorpayPaymentId: outcome.providerPaymentId!,
        razorpaySignature: outcome.signature!,
      );

      if (!verification.verified) {
        state = state.copyWith(
          stage: CheckoutStage.failed,
          error: const AppError(
            code: ErrorCodes.paymentSignatureInvalid,
            message: 'We could not confirm that payment. Our team is checking it.',
          ),
        );
        return false;
      }
    } on AppError catch (error) {
      // The webhook is the backstop: the payment may still be captured server-side,
      // so the customer is told to check the order rather than to pay again.
      state = state.copyWith(stage: CheckoutStage.failed, error: error);
      return false;
    }

    return true;
  }

  /// Opens the Razorpay sheet and resolves once it reports an outcome.
  Future<_GatewayOutcome> _openGateway(PaymentSession session) {
    _disposeGateway();

    final completer = Completer<_GatewayOutcome>();
    _pending = completer;

    final gateway = Razorpay();
    _razorpay = gateway;

    gateway.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
      _settle(_GatewayOutcome(
        succeeded: response.orderId != null &&
            response.paymentId != null &&
            response.signature != null,
        providerOrderId: response.orderId,
        providerPaymentId: response.paymentId,
        signature: response.signature,
        message: 'The payment response was incomplete. Please try again.',
      ));
    });

    gateway.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      // Code 2 is "cancelled by user" in the Razorpay SDK.
      final cancelled = response.code == Razorpay.PAYMENT_CANCELLED;
      _settle(_GatewayOutcome(
        succeeded: false,
        cancelled: cancelled,
        message: response.message,
      ));
    });

    try {
      gateway.open(session.toCheckoutOptions());
    } catch (error) {
      _settle(_GatewayOutcome(
        succeeded: false,
        message: AppError.from(error).message,
      ));
    }

    return completer.future;
  }

  void _settle(_GatewayOutcome outcome) {
    final completer = _pending;
    _pending = null;
    _disposeGateway();
    if (completer != null && !completer.isCompleted) completer.complete(outcome);
  }

  void _disposeGateway() {
    _razorpay?.clear();
    _razorpay = null;
  }

  /// The order is placed and paid: refresh everything that depends on it.
  Future<void> _finish() async {
    _idempotencyKey = null;
    state = state.copyWith(stage: CheckoutStage.done, clearError: true);

    ref.invalidate(cartProvider);
    ref.invalidate(activeOrdersProvider);
    ref.invalidate(myOrdersProvider);
    ref.invalidate(walletProvider);
  }

  static String _newIdempotencyKey() {
    final random = Random.secure();
    final suffix = List<int>.generate(8, (_) => random.nextInt(16))
        .map((value) => value.toRadixString(16))
        .join();
    return 'bb-${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }
}

final checkoutControllerProvider = NotifierProvider<CheckoutController, CheckoutState>(
  CheckoutController.new,
);

class _GatewayOutcome {
  const _GatewayOutcome({
    required this.succeeded,
    this.cancelled = false,
    this.providerOrderId,
    this.providerPaymentId,
    this.signature,
    this.message,
  });

  final bool succeeded;
  final bool cancelled;
  final String? providerOrderId;
  final String? providerPaymentId;
  final String? signature;
  final String? message;
}
