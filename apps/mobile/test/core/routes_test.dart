import 'package:flutter_test/flutter_test.dart';

import 'package:bitesbox/core/routing/routes.dart';

void main() {
  test('referral sign-in URL preserves and safely encodes the invite code', () {
    expect(Uri.parse(Routes.signInWithReferral(' bb /?42 ')).queryParameters['ref'], 'bb /?42');
  });
}
