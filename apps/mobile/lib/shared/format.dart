import 'package:intl/intl.dart';

/// Formatting helpers shared by all three shells.
///
/// Money is always formatted from the exact numeric the server sent — the app
/// never computes a total itself, so there is nothing here that rounds or sums.
abstract final class Fmt {
  static final NumberFormat _rupees = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final NumberFormat _rupeesPrecise = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static String _dateLocale = 'en_IN';

  /// Set from the active account language so date and duration copy follows the
  /// same locale as the customer UI without changing Indian currency formatting.
  static void setLanguage(String languageCode) {
    _dateLocale = languageCode == 'hi' ? 'hi_IN' : 'en_IN';
  }

  static DateFormat get _time => DateFormat('h:mm a', _dateLocale);
  static DateFormat get _dayTime => DateFormat('d MMM, h:mm a', _dateLocale);
  static DateFormat get _day => DateFormat('d MMM yyyy', _dateLocale);

  /// ₹249 — the default for prices and totals.
  static String money(num? amount) => _rupees.format(amount ?? 0);

  /// ₹249.50 — used on bills and invoices where paise matter.
  static String moneyPrecise(num? amount) => _rupeesPrecise.format(amount ?? 0);

  /// Trims trailing zeros: "₹20" not "₹20.00", but keeps "₹20.50".
  static String moneySmart(num? amount) {
    final value = amount ?? 0;
    return value == value.roundToDouble() ? money(value) : moneyPrecise(value);
  }

  static String time(DateTime? value) => value == null ? '—' : _time.format(value.toLocal());

  static String dayTime(DateTime? value) =>
      value == null ? '—' : _dayTime.format(value.toLocal());

  static String day(DateTime? value) => value == null ? '—' : _day.format(value.toLocal());

  /// "2:34 PM" today, "Yesterday 8:01 PM", otherwise "12 Aug, 8:01 PM".
  static String smartDateTime(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);

    if (that == today) return _time.format(local);
    if (that == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${_time.format(local)}';
    }
    return _dayTime.format(local);
  }

  /// "just now", "4 min ago", "2 h ago", "3 d ago"
  static String relative(DateTime? value) {
    if (value == null) return '—';
    final diff = DateTime.now().difference(value.toLocal());

    if (diff.inSeconds < 45) {
      return _dateLocale == 'hi_IN' ? 'अभी-अभी' : 'just now';
    }
    if (diff.inMinutes < 60) {
      return _dateLocale == 'hi_IN'
          ? '${diff.inMinutes} मिनट पहले'
          : '${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      return _dateLocale == 'hi_IN'
          ? '${diff.inHours} घंटे पहले'
          : '${diff.inHours} h ago';
    }
    if (diff.inDays < 7) {
      return _dateLocale == 'hi_IN'
          ? '${diff.inDays} दिन पहले'
          : '${diff.inDays} d ago';
    }
    return day(value);
  }

  /// "in 24 min" / "any moment now" — used for the delivery promise.
  static String until(DateTime? value) {
    if (value == null) return '—';
    final diff = value.toLocal().difference(DateTime.now());

    if (diff.isNegative) return _dateLocale == 'hi_IN' ? 'अभी' : 'any moment now';
    if (diff.inMinutes < 1) {
      return _dateLocale == 'hi_IN' ? 'एक मिनट से कम में' : 'in under a minute';
    }
    if (diff.inMinutes < 60) {
      return _dateLocale == 'hi_IN'
          ? '${diff.inMinutes} मिनट में'
          : 'in ${diff.inMinutes} min';
    }
    return _dateLocale == 'hi_IN' ? time(value) : 'at ${time(value)}';
  }

  /// mm:ss for kitchen timers, "1h 05m" beyond an hour.
  static String elapsed(int seconds) {
    final total = seconds < 0 ? 0 : seconds;
    final minutes = total ~/ 60;
    if (minutes < 60) {
      return '$minutes:${(total % 60).toString().padLeft(2, '0')}';
    }
    return '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';
  }

  /// "24 min" / "1 hr 5 min"
  static String duration(int minutes) {
    if (_dateLocale == 'hi_IN') {
      if (minutes < 60) return '$minutes मिनट';
      final hindiHours = minutes ~/ 60;
      final hindiMinutes = minutes % 60;
      final hoursLabel = hindiHours == 1 ? 'घंटा' : 'घंटे';
      if (hindiMinutes == 0) return '$hindiHours $hoursLabel';
      return '$hindiHours $hoursLabel $hindiMinutes मिनट';
    }
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours hr' : '$hours hr $rest min';
  }

  /// ORDER_PLACED → Order placed
  static String humanise(String? value) {
    if (value == null || value.isEmpty) return '—';
    final spaced = value.replaceAll('_', ' ').toLowerCase();
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  /// "1.4 km" / "800 m"
  static String distance(num? km) {
    if (km == null) return '—';
    if (km < 1) {
      return _dateLocale == 'hi_IN'
          ? '${(km * 1000).round()} मीटर'
          : '${(km * 1000).round()} m';
    }
    return _dateLocale == 'hi_IN'
        ? '${km.toStringAsFixed(1)} किमी'
        : '${km.toStringAsFixed(1)} km';
  }

  /// Masks a phone number for display on a shared screen: +9199•••••01
  static String maskPhone(String? phone) {
    if (phone == null || phone.length < 6) return phone ?? '—';
    final tail = phone.substring(phone.length - 2);
    final head = phone.substring(0, phone.length - 7);
    return '$head•••••$tail';
  }
}
