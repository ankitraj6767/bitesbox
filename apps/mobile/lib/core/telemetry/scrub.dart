import 'package:sentry_flutter/sentry_flutter.dart';

String redactTelemetryText(String value) {
  final sanitized = value
    .replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9._~+/-]+=*', caseSensitive: false),
      'Bearer [redacted]',
    )
    .replaceAll(
      RegExp(
        r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
        caseSensitive: false,
      ),
      '[email]',
    )
    .replaceAll(RegExp(r'(?:\+?\d[\d\s().-]{7,}\d)'), '[phone]')
    .replaceAll(
      RegExp(r'data:image/[A-Za-z0-9.+-]+;base64,[A-Za-z0-9+/=]+'),
      '[image redacted]',
    )
    .replaceAll(
      RegExp(r'https?://[^\s?]+\?[^\s)]+', caseSensitive: false),
      '[url with query redacted]',
    )
    .replaceAll(RegExp(r'[A-Za-z0-9_-]{80,}'), '[long value redacted]');
  return sanitized.length > 2000
      ? sanitized.substring(0, 2000)
      : sanitized;
}

String _safeRoute(String? value) {
  if (value == null || value.isEmpty) return '/';
  final uri = Uri.tryParse(value);
  final path = uri?.path ?? value.split('?').first;
  return path
      .split('/')
      .map((segment) {
        if (RegExp(
              r'^[0-9a-f-]{24,}$',
              caseSensitive: false,
            ).hasMatch(segment) ||
            RegExp(r'^\d{6,}$').hasMatch(segment)) {
          return '[id]';
        }
        return segment;
      })
      .join('/');
}

SentryEvent scrubSentryEvent(SentryEvent event, {String? route}) {
  event.user = null;
  // `extra` is deprecated by Sentry in favor of structured contexts, but clearing
  // it is still necessary to ensure old callers cannot leak arbitrary PII.
  // ignore: deprecated_member_use
  event.extra = null;
  event.request = event.request == null
      ? null
      : SentryRequest(
          url: _safeRoute(event.request!.url),
          method: event.request!.method,
        );
  event.transaction = _safeRoute(route ?? event.transaction);
  event.message?.formatted = redactTelemetryText(event.message!.formatted);
  event.message?.template = null;
  event.message?.params = null;
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    if (exception.value != null) {
      exception.value = redactTelemetryText(exception.value!);
    }
  }
  event.tags?.removeWhere(
    (key, _) => RegExp(
      r'(email|phone|address|token|secret|authorization)',
      caseSensitive: false,
    ).hasMatch(key),
  );
  event.tags?.updateAll((_, value) => redactTelemetryText(value));
  for (final breadcrumb in event.breadcrumbs ?? const <Breadcrumb>[]) {
    if (breadcrumb.message != null) {
      breadcrumb.message = redactTelemetryText(breadcrumb.message!);
    }
    breadcrumb.data = null;
  }
  return event;
}
