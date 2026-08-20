import 'dart:async';
import 'dart:io';

import 'package:bitesbox/core/errors/app_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Every guard rail in the database reports through `app.fail`, which puts the
/// stable machine code in the PostgREST `hint` and customer-safe copy in `message`.
/// If that mapping breaks, every screen starts showing raw Postgres text.
void main() {
  group('AppError.from', () {
    test('reads the business code out of the hint', () {
      final error = AppError.from(
        const PostgrestException(
          message: 'Chicken Biryani is not available right now.',
          code: 'P0001',
          hint: 'ITEM_UNAVAILABLE',
        ),
      );

      expect(error.code, ErrorCodes.itemUnavailable);
      expect(error.message, contains('Chicken Biryani'));
    });

    test('ignores a hint that is prose rather than a code', () {
      final error = AppError.from(
        const PostgrestException(
          message: 'column "foo" does not exist',
          code: '42703',
          hint: 'Perhaps you meant to reference the column "bar".',
        ),
      );

      expect(error.code, '42703');
    });

    // 42501 covers both a missing privilege and an RLS rejection. "new row violates
    // row-level security policy" is not something to show a customer.
    test('translates a row-level security rejection', () {
      final error = AppError.from(
        const PostgrestException(
          message: 'new row violates row-level security policy for table "orders"',
          code: '42501',
        ),
      );

      expect(error.code, ErrorCodes.permissionDenied);
      expect(error.message, isNot(contains('row-level security')));
    });

    test('treats an expired token as needing a fresh sign-in', () {
      final error = AppError.from(
        const PostgrestException(message: 'JWT expired', code: 'PGRST301'),
      );

      expect(error.code, ErrorCodes.unauthenticated);
      expect(error.requiresSignIn, isTrue);
    });

    test('maps a lost connection to a retryable network error', () {
      final error = AppError.from(const SocketException('Failed host lookup'));

      expect(error.code, ErrorCodes.networkError);
      expect(error.isRetryable, isTrue);
      expect(error.message, contains('offline'));
    });

    test('maps a timeout to something worth retrying', () {
      final error = AppError.from(TimeoutException('too slow'));

      expect(error.code, ErrorCodes.timeout);
      expect(error.isRetryable, isTrue);
    });

    test('passes an AppError through untouched', () {
      const original = AppError(code: 'COUPON_EXPIRED', message: 'That offer has ended.');
      expect(AppError.from(original), same(original));
    });

    test('never leaves the UI without a message', () {
      for (final thrown in <Object>[
        Exception('boom'),
        'a bare string',
        42,
        StateError('bad state'),
      ]) {
        final error = AppError.from(thrown);
        expect(error.message.trim(), isNotEmpty, reason: thrown.toString());
        expect(error.code.trim(), isNotEmpty);
      }
    });

    test('carries structured detail so the UI can be specific', () {
      final error = AppError.from(
        const PostgrestException(
          message: 'Collect ₹632.00 from the customer.',
          code: 'P0001',
          hint: 'COD_AMOUNT_MISMATCH',
          details: {'expected': 632, 'collected': 500},
        ),
      );

      expect(error.code, ErrorCodes.codAmountMismatch);
      expect(error.details?['expected'], 632);
    });
  });

  group('classification', () {
    test('knows which failures the customer must fix in their cart', () {
      for (final code in [
        ErrorCodes.itemUnavailable,
        ErrorCodes.modifierUnavailable,
        ErrorCodes.cartEmpty,
        ErrorCodes.minOrderNotMet,
        ErrorCodes.quantityLimitExceeded,
      ]) {
        expect(
          AppError(code: code, message: 'x').requiresCartFix,
          isTrue,
          reason: code,
        );
      }

      expect(
        const AppError(code: ErrorCodes.paymentFailed, message: 'x').requiresCartFix,
        isFalse,
      );
    });

    test('does not invite a retry of something that will fail again', () {
      expect(
        const AppError(code: ErrorCodes.couponExpired, message: 'x').isRetryable,
        isFalse,
      );
      expect(
        const AppError(code: ErrorCodes.rateLimited, message: 'x').isRetryable,
        isTrue,
      );
    });

    test('sends a blocked account back to sign-in', () {
      expect(
        const AppError(code: ErrorCodes.accountBlocked, message: 'x').requiresSignIn,
        isTrue,
      );
    });
  });

  group('ErrorCodes', () {
    // These strings are a contract shared with packages/shared-types/src/errors.ts
    // and with `app.fail` in the migrations. Renaming one silently breaks a screen.
    test('covers the delivery verification failures the rider app branches on', () {
      expect(ErrorCodes.deliveryOtpRequired, 'DELIVERY_OTP_REQUIRED');
      expect(ErrorCodes.deliveryOtpInvalid, 'DELIVERY_OTP_INVALID');
      expect(ErrorCodes.pickupCodeInvalid, 'PICKUP_CODE_INVALID');
      expect(ErrorCodes.tooManyAttempts, 'TOO_MANY_ATTEMPTS');
      expect(ErrorCodes.activeDeliveriesPending, 'ACTIVE_DELIVERIES_PENDING');
      expect(ErrorCodes.notADeliveryPartner, 'NOT_A_DELIVERY_PARTNER');
      expect(ErrorCodes.riderNotActive, 'RIDER_NOT_ACTIVE');
      expect(ErrorCodes.codAmountMismatch, 'COD_AMOUNT_MISMATCH');
    });
  });
}
