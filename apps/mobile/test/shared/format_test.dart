import 'package:bitesbox/shared/format.dart';
import 'package:flutter_test/flutter_test.dart';

/// Formatting is where a correct number becomes a wrong-looking one. These are the
/// cases a customer or an operator would notice: Indian digit grouping, paise that
/// should not appear, and a timer that must never run backwards.
void main() {
  group('money', () {
    test('groups digits the Indian way', () {
      expect(Fmt.money(123456), '₹1,23,456');
      expect(Fmt.money(1234), '₹1,234');
      expect(Fmt.money(249), '₹249');
    });

    test('treats a missing amount as zero', () {
      expect(Fmt.money(null), '₹0');
    });

    test('moneyPrecise always shows paise', () {
      expect(Fmt.moneyPrecise(249), '₹249.00');
      expect(Fmt.moneyPrecise(249.5), '₹249.50');
    });

    // A bill of ₹20.00 reads as an error; ₹20.50 must keep its paise.
    test('moneySmart drops only trailing zeroes', () {
      expect(Fmt.moneySmart(20), '₹20');
      expect(Fmt.moneySmart(20.0), '₹20');
      expect(Fmt.moneySmart(20.5), '₹20.50');
      expect(Fmt.moneySmart(null), '₹0');
    });
  });

  group('elapsed', () {
    test('counts mm:ss below an hour', () {
      expect(Fmt.elapsed(0), '0:00');
      expect(Fmt.elapsed(9), '0:09');
      expect(Fmt.elapsed(65), '1:05');
      expect(Fmt.elapsed(3599), '59:59');
    });

    test('switches to hours past sixty minutes', () {
      expect(Fmt.elapsed(3600), '1h 00m');
      expect(Fmt.elapsed(3900), '1h 05m');
    });

    // Clock skew between a kitchen tablet and the server can produce a negative
    // age. A ticket timer showing "-2:-30" would look broken to the kitchen.
    test('clamps a negative duration', () {
      expect(Fmt.elapsed(-30), '0:00');
    });
  });

  group('duration', () {
    test('reads naturally either side of an hour', () {
      expect(Fmt.duration(24), '24 min');
      expect(Fmt.duration(60), '1 hr');
      expect(Fmt.duration(65), '1 hr 5 min');
      expect(Fmt.duration(120), '2 hr');
    });
  });

  group('distance', () {
    test('uses metres below a kilometre', () {
      expect(Fmt.distance(0.8), '800 m');
      expect(Fmt.distance(0.05), '50 m');
    });

    test('uses one decimal kilometre above it', () {
      expect(Fmt.distance(1.44), '1.4 km');
      expect(Fmt.distance(12), '12.0 km');
    });

    test('does not invent a distance it does not have', () {
      expect(Fmt.distance(null), '—');
    });
  });

  group('humanise', () {
    test('turns an enum into a sentence', () {
      expect(Fmt.humanise('ORDER_PLACED'), 'Order placed');
      expect(Fmt.humanise('OUT_FOR_DELIVERY'), 'Out for delivery');
      expect(Fmt.humanise('MOTORCYCLE'), 'Motorcycle');
    });

    test('handles nothing gracefully', () {
      expect(Fmt.humanise(null), '—');
      expect(Fmt.humanise(''), '—');
    });
  });

  group('relative', () {
    test('describes recent moments loosely', () {
      final now = DateTime.now();
      expect(Fmt.relative(now), 'just now');
      expect(Fmt.relative(now.subtract(const Duration(minutes: 4))), '4 min ago');
      expect(Fmt.relative(now.subtract(const Duration(hours: 3))), '3 h ago');
      expect(Fmt.relative(now.subtract(const Duration(days: 2))), '2 d ago');
    });

    test('falls back to a date beyond a week', () {
      final old = DateTime.now().subtract(const Duration(days: 30));
      expect(Fmt.relative(old), isNot(contains('ago')));
    });

    test('renders nothing for null', () {
      expect(Fmt.relative(null), '—');
    });
  });

  group('until', () {
    test('reassures rather than showing a negative countdown', () {
      final past = DateTime.now().subtract(const Duration(minutes: 5));
      expect(Fmt.until(past), 'any moment now');
    });

    // Asserted as a pattern, not an exact string: the few microseconds between
    // building the timestamp and formatting it truncate 24 minutes to 23.
    test('counts minutes within the hour', () {
      final soon = DateTime.now().add(const Duration(minutes: 24, seconds: 30));
      expect(Fmt.until(soon), matches(RegExp(r'^in 2[34] min$')));
    });

    test('switches to a clock time further out', () {
      final later = DateTime.now().add(const Duration(hours: 3));
      expect(Fmt.until(later), startsWith('at '));
    });
  });

  group('maskPhone', () {
    // Rider and kitchen screens are visible to whoever is standing nearby, so a
    // customer's full number is not shown where it is not needed.
    test('hides the middle of a number', () {
      final masked = Fmt.maskPhone('+919900000001');
      expect(masked, contains('•'));
      expect(masked, endsWith('01'));
      expect(masked, isNot(contains('9900000')));
    });

    test('leaves something too short alone rather than corrupting it', () {
      expect(Fmt.maskPhone('123'), '123');
      expect(Fmt.maskPhone(null), '—');
    });
  });

  group('smartDateTime', () {
    test('shows only the time for today', () {
      final result = Fmt.smartDateTime(DateTime.now());
      expect(result, matches(RegExp(r'^\d{1,2}:\d{2} (AM|PM)$')));
    });

    test('names yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(Fmt.smartDateTime(yesterday), startsWith('Yesterday'));
    });

    test('renders nothing for null', () {
      expect(Fmt.smartDateTime(null), '—');
    });
  });
}
