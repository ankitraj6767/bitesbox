import 'package:bitesbox/features/delivery/data/delivery_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 23, 10);

  RiderFixDecision evaluate({required Duration age, Duration? afterLast}) =>
      evaluateRiderFix(
        capturedAt: now.subtract(age),
        now: now,
        staleAfter: const Duration(minutes: 2),
        minimumInterval: const Duration(seconds: 8),
        lastSent: afterLast == null ? null : now.subtract(afterLast),
      );

  test('accepts a recent OS capture and does not require a queued fix', () {
    expect(evaluate(age: const Duration(seconds: 10)), RiderFixDecision.accept);
  });

  test('rejects stale, future, out-of-order and overly frequent captures', () {
    expect(evaluate(age: const Duration(minutes: 3)), RiderFixDecision.stale);
    expect(
      evaluateRiderFix(
        capturedAt: now.add(const Duration(seconds: 20)),
        now: now,
        staleAfter: const Duration(minutes: 2),
        minimumInterval: const Duration(seconds: 8),
      ),
      RiderFixDecision.future,
    );
    expect(
      evaluateRiderFix(
        capturedAt: now.subtract(const Duration(seconds: 10)),
        now: now,
        lastSent: now.subtract(const Duration(seconds: 8)),
        staleAfter: const Duration(minutes: 2),
        minimumInterval: const Duration(seconds: 8),
      ),
      RiderFixDecision.outOfOrder,
    );
    expect(
      evaluate(
        age: const Duration(seconds: 5),
        afterLast: const Duration(seconds: 8),
      ),
      RiderFixDecision.tooSoon,
    );
  });

  test(
    'a fresh fix after network recovery is accepted, while an old fix is not replayable',
    () {
      expect(
        evaluate(age: const Duration(seconds: 4)),
        RiderFixDecision.accept,
      );
      expect(evaluate(age: const Duration(minutes: 4)), RiderFixDecision.stale);
    },
  );

  test(
    'location watchdog requests a fresh fix after the stream goes quiet',
    () {
      expect(
        shouldRequestLocationRecoveryFix(
          lastSuccessfulFixAt: null,
          streamStartedAt: now.subtract(const Duration(seconds: 31)),
          lastAttemptAt: now.subtract(const Duration(seconds: 25)),
          now: now,
          recoveryAfter: const Duration(seconds: 30),
          retryInterval: const Duration(seconds: 20),
          requestInProgress: false,
        ),
        isTrue,
      );
    },
  );

  test(
    'location watchdog respects recent fixes and bounds duplicate requests',
    () {
      bool shouldRecover({
        DateTime? lastSuccessfulFixAt,
        DateTime? lastAttemptAt,
        bool requestInProgress = false,
      }) => shouldRequestLocationRecoveryFix(
        lastSuccessfulFixAt: lastSuccessfulFixAt,
        streamStartedAt: now.subtract(const Duration(seconds: 60)),
        lastAttemptAt: lastAttemptAt,
        now: now,
        recoveryAfter: const Duration(seconds: 30),
        retryInterval: const Duration(seconds: 20),
        requestInProgress: requestInProgress,
      );

      expect(
        shouldRecover(
          lastSuccessfulFixAt: now.subtract(const Duration(seconds: 10)),
          lastAttemptAt: now.subtract(const Duration(seconds: 25)),
        ),
        isFalse,
      );
      expect(
        shouldRecover(lastAttemptAt: now.subtract(const Duration(seconds: 5))),
        isFalse,
      );
      expect(
        shouldRecover(
          lastAttemptAt: now.subtract(const Duration(seconds: 25)),
          requestInProgress: true,
        ),
        isFalse,
      );
      expect(
        shouldRequestLocationRecoveryFix(
          lastSuccessfulFixAt: null,
          streamStartedAt: null,
          lastAttemptAt: null,
          now: now,
          recoveryAfter: const Duration(seconds: 30),
          retryInterval: const Duration(seconds: 20),
          requestInProgress: false,
        ),
        isFalse,
      );
    },
  );
}
