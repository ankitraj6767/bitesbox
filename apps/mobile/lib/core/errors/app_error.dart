import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Stable business error codes, mirrored from
/// `packages/shared-types/src/errors.ts`. These strings are a contract between
/// the database and every client — never rename one without changing both.
abstract final class ErrorCodes {
  static const unauthenticated = 'UNAUTHENTICATED';
  static const permissionDenied = 'PERMISSION_DENIED';
  static const accountBlocked = 'ACCOUNT_BLOCKED';
  static const rateLimited = 'RATE_LIMITED';

  static const itemNotFound = 'ITEM_NOT_FOUND';
  static const itemUnavailable = 'ITEM_UNAVAILABLE';
  static const variantRequired = 'VARIANT_REQUIRED';
  static const modifierUnavailable = 'MODIFIER_UNAVAILABLE';
  static const modifierSelectionRequired = 'MODIFIER_SELECTION_REQUIRED';
  static const modifierSelectionExceeded = 'MODIFIER_SELECTION_EXCEEDED';
  static const quantityLimitExceeded = 'QUANTITY_LIMIT_EXCEEDED';

  static const cartEmpty = 'CART_EMPTY';
  static const checkoutInvalid = 'CHECKOUT_INVALID';
  static const minOrderNotMet = 'MIN_ORDER_NOT_MET';
  static const addressRequired = 'ADDRESS_REQUIRED';
  static const addressNotFound = 'ADDRESS_NOT_FOUND';
  static const addressNotServiceable = 'ADDRESS_NOT_SERVICEABLE';
  static const outsideMaxDistance = 'OUTSIDE_MAX_DISTANCE';
  static const scheduleTooSoon = 'SCHEDULE_TOO_SOON';

  static const restaurantClosed = 'RESTAURANT_CLOSED';
  static const orderingPaused = 'ORDERING_PAUSED';
  static const outsideTradingHours = 'OUTSIDE_TRADING_HOURS';
  static const tooBusy = 'TOO_BUSY';
  static const maintenanceMode = 'MAINTENANCE_MODE';

  static const couponInvalid = 'COUPON_INVALID';
  static const couponExpired = 'COUPON_EXPIRED';
  static const couponExhausted = 'COUPON_EXHAUSTED';
  static const couponAlreadyUsed = 'COUPON_ALREADY_USED';
  static const couponMinOrderNotMet = 'COUPON_MIN_ORDER_NOT_MET';
  static const couponFirstOrderOnly = 'COUPON_FIRST_ORDER_ONLY';

  static const orderNotFound = 'ORDER_NOT_FOUND';
  static const invalidOrderTransition = 'INVALID_ORDER_TRANSITION';
  static const cancellationNotAllowed = 'CANCELLATION_NOT_ALLOWED';
  static const cancellationLimitReached = 'CANCELLATION_LIMIT_REACHED';

  static const paymentFailed = 'PAYMENT_FAILED';
  static const paymentSignatureInvalid = 'PAYMENT_SIGNATURE_INVALID';
  static const codUnavailable = 'COD_UNAVAILABLE';
  static const codLimitExceeded = 'COD_LIMIT_EXCEEDED';
  static const codAmountMismatch = 'COD_AMOUNT_MISMATCH';
  static const insufficientWalletBalance = 'INSUFFICIENT_WALLET_BALANCE';

  static const notADeliveryPartner = 'NOT_A_DELIVERY_PARTNER';
  static const riderNotActive = 'RIDER_NOT_ACTIVE';
  static const activeDeliveriesPending = 'ACTIVE_DELIVERIES_PENDING';
  static const assignmentNotFound = 'ASSIGNMENT_NOT_FOUND';
  static const assignmentExpired = 'ASSIGNMENT_EXPIRED';
  static const deliveryOtpRequired = 'DELIVERY_OTP_REQUIRED';
  static const deliveryOtpInvalid = 'DELIVERY_OTP_INVALID';
  static const pickupCodeInvalid = 'PICKUP_CODE_INVALID';
  static const tooManyAttempts = 'TOO_MANY_ATTEMPTS';

  static const reviewAlreadySubmitted = 'REVIEW_ALREADY_SUBMITTED';

  static const networkError = 'NETWORK_ERROR';
  static const timeout = 'TIMEOUT';
  static const unknown = 'UNKNOWN';
}

/// A failure the UI can act on: a stable [code], copy that is safe to show a
/// customer, and optional structured [details] for richer presentation
/// (for example the shortfall on a minimum-order error).
class AppError implements Exception {
  const AppError({
    required this.code,
    required this.message,
    this.details,
    this.cause,
  });

  final String code;
  final String message;
  final Map<String, dynamic>? details;
  final Object? cause;

  /// Retrying the same action unchanged could plausibly succeed.
  bool get isRetryable =>
      code == ErrorCodes.networkError ||
      code == ErrorCodes.timeout ||
      code == ErrorCodes.rateLimited;

  /// The session is gone or invalid; the shell should send the user to sign-in.
  bool get requiresSignIn =>
      code == ErrorCodes.unauthenticated || code == ErrorCodes.accountBlocked;

  /// The cart or basket needs changing before this action can work.
  bool get requiresCartFix =>
      code == ErrorCodes.itemUnavailable ||
      code == ErrorCodes.modifierUnavailable ||
      code == ErrorCodes.cartEmpty ||
      code == ErrorCodes.minOrderNotMet ||
      code == ErrorCodes.quantityLimitExceeded;

  /// Translates anything thrown by supabase_flutter into an [AppError].
  ///
  /// Postgres business errors raised by `app.fail()` carry the machine code in
  /// `hint` and customer-safe copy in `message`; that is the case we care about
  /// most, because every guard rail in the database reports through it.
  factory AppError.from(Object error, [StackTrace? stackTrace]) {
    if (error is AppError) return error;

    if (error is PostgrestException) {
      final hint = error.hint;
      if (hint != null && RegExp(r'^[A-Z][A-Z0-9_]+$').hasMatch(hint)) {
        return AppError(
          code: hint,
          message: error.message,
          details: _parseDetails(error.details),
          cause: error,
        );
      }

      // 42501 is a row-level security or privilege rejection.
      if (error.code == '42501') {
        return AppError(
          code: ErrorCodes.permissionDenied,
          message: 'You do not have permission to do that.',
          cause: error,
        );
      }

      if (error.code == 'PGRST301') {
        return const AppError(
          code: ErrorCodes.unauthenticated,
          message: 'Your session has expired. Please sign in again.',
        );
      }

      return AppError(
        code: error.code ?? ErrorCodes.unknown,
        message: error.message,
        cause: error,
      );
    }

    if (error is FunctionException) {
      final body = error.details;
      if (body is Map) {
        final nested = body['error'];
        if (nested is Map) {
          return AppError(
            code: (nested['code'] as String?) ?? ErrorCodes.unknown,
            message: (nested['message'] as String?) ?? _fallback(ErrorCodes.unknown),
            details: nested['details'] is Map
                ? Map<String, dynamic>.from(nested['details'] as Map)
                : null,
            cause: error,
          );
        }
      }

      return AppError(
        code: ErrorCodes.unknown,
        message: _fallback(ErrorCodes.unknown),
        cause: error,
      );
    }

    if (error is AuthException) {
      return AppError(
        code: error.statusCode == '400' ? 'INVALID_CREDENTIALS' : ErrorCodes.unauthenticated,
        message: error.message,
        cause: error,
      );
    }

    if (error is SocketException || error is HttpException) {
      return AppError(
        code: ErrorCodes.networkError,
        message: _fallback(ErrorCodes.networkError),
        cause: error,
      );
    }

    if (error is TimeoutException) {
      return AppError(
        code: ErrorCodes.timeout,
        message: _fallback(ErrorCodes.timeout),
        cause: error,
      );
    }

    return AppError(
      code: ErrorCodes.unknown,
      message: _fallback(ErrorCodes.unknown),
      cause: error,
    );
  }

  static Map<String, dynamic>? _parseDetails(Object? details) {
    if (details is Map) return Map<String, dynamic>.from(details);
    return null;
  }

  static String _fallback(String code) => switch (code) {
        ErrorCodes.networkError =>
          'You appear to be offline. Check your connection and try again.',
        ErrorCodes.timeout => 'That took too long. Please try again.',
        ErrorCodes.rateLimited => 'Too many attempts. Please wait a moment.',
        _ => 'Something went wrong on our side. Please try again.',
      };

  @override
  String toString() => 'AppError($code): $message';
}
