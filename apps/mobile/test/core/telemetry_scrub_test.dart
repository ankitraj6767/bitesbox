import 'package:bitesbox/core/telemetry/scrub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test(
    'Sentry event scrubbing removes identity, auth, location query, and uploads',
    () {
      // ignore: deprecated_member_use
      final event = SentryEvent(
        user: SentryUser(id: 'customer-1', email: 'customer@example.test'),
        request: SentryRequest(
          url: 'https://api.example.test/orders/12345678?token=secret',
          headers: const {'authorization': 'Bearer private-token'},
          cookies: 'session=private',
          data: {'address': '21 Main Street'},
        ),
        message: SentryMessage(
          'Could not send OTP to +91 98765 43210 customer@example.test',
        ),
        exceptions: [
          SentryException(
            type: 'StateError',
            value: 'Request failed for customer@example.test',
          ),
        ],
        tags: {'role_category': 'customer', 'phone': '+919876543210'},
        breadcrumbs: [
          Breadcrumb(
            message: 'Opened customer@example.test',
            data: {'photo': 'private-image'},
          ),
        ],
        // ignore: deprecated_member_use
        extra: {'upload_image': 'raw image'},
      );

      final scrubbed = scrubSentryEvent(
        event,
        route: '/orders/12345678?address=private',
      );
      expect(scrubbed.user, isNull);
      expect(scrubbed.request!.url, '/orders/[id]');
      expect(scrubbed.request!.headers, isEmpty);
      expect(scrubbed.request!.cookies, isNull);
      expect(scrubbed.request!.data, isNull);
      expect(scrubbed.transaction, '/orders/[id]');
      expect(
        scrubbed.message!.formatted,
        isNot(contains('customer@example.test')),
      );
      expect(scrubbed.message!.formatted, isNot(contains('98765')));
      expect(scrubbed.exceptions!.single.value, 'Request failed for [email]');
      expect(scrubbed.tags, {'role_category': 'customer'});
      expect(scrubbed.breadcrumbs!.single.data, isNull);
      // ignore: deprecated_member_use
      expect(scrubbed.extra, isNull);
    },
  );
}
