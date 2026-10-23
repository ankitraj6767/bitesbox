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
}
