import 'package:url_launcher/url_launcher.dart';

/// Hand-offs to the phone's own apps: dialler, maps, WhatsApp.
///
/// Every call returns whether it worked, so a caller can fall back to showing the
/// raw number rather than silently doing nothing.
abstract final class Launcher {
  static Future<bool> dial(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return false;
    return _open(Uri(scheme: 'tel', path: phone.trim()));
  }

  static Future<bool> sms(String? phone, {String? body}) async {
    if (phone == null || phone.trim().isEmpty) return false;
    return _open(Uri(
      scheme: 'sms',
      path: phone.trim(),
      queryParameters: body == null ? null : {'body': body},
    ));
  }

  /// Opens WhatsApp, falling back to the browser when it is not installed.
  static Future<bool> whatsapp(String? phone, {String? message}) async {
    if (phone == null || phone.trim().isEmpty) return false;

    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.https('wa.me', '/$digits', {
      if (message != null && message.isNotEmpty) 'text': message,
    });

    return _open(uri);
  }

  /// Turn-by-turn navigation to a coordinate.
  ///
  /// `google.navigation:` starts navigation directly on Android; the universal
  /// maps URL is the fallback and is what iOS and the web use.
  static Future<bool> navigate({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final navigation = Uri.parse('google.navigation:q=$latitude,$longitude&mode=d');
    if (await canLaunchUrl(navigation)) {
      return launchUrl(navigation);
    }

    return _open(Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
      'travelmode': 'driving',
      if (label != null) 'destination_place_id': label,
    }));
  }

  /// Shows a pin without starting navigation.
  static Future<bool> showOnMap({
    required double latitude,
    required double longitude,
    String? label,
  }) {
    return _open(Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$latitude,$longitude',
      if (label != null) 'query_place_id': label,
    }));
  }

  static Future<bool> web(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return Future.value(false);
    return _open(uri);
  }

  static Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}
