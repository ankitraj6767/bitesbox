import 'package:flutter_test/flutter_test.dart';

import 'package:bitesbox/core/update/update_manifest.dart';

void main() {
  test('AppVersion compares marketing version before build number', () {
    expect(AppVersion.tryParse('1.2.0+9')! > AppVersion.tryParse('1.1.99+99')!, isTrue);
    expect(AppVersion.tryParse('1.2.0+10')! > AppVersion.tryParse('1.2.0+9')!, isTrue);
    expect(AppVersion.tryParse('v1.2.0-beta.1')!.displayLabel, '1.2.0');
  });

  test('AndroidRelease selects the first compatible device ABI', () {
    final release = AndroidRelease.fromJson({
      'version': '1.0.8',
      'buildNumber': 8,
      'artifacts': [
        {'abi': 'armeabi-v7a', 'url': 'https://example.test/v7.apk', 'fileName': 'v7.apk'},
        {'abi': 'arm64-v8a', 'url': 'https://example.test/64.apk', 'fileName': '64.apk'},
      ],
    });

    expect(release.artifactFor(['arm64-v8a', 'armeabi-v7a'])?.fileName, '64.apk');
    expect(release.artifactFor(['x86'])?.fileName, isNull);
  });

  test('AndroidRelease accepts a single artifact manifest for compatibility', () {
    final release = AndroidRelease.fromJson({
      'version': '1.0.2',
      'url': 'https://example.test/update.apk',
      'fileName': 'update.apk',
    });

    expect(release.artifactFor(['arm64-v8a'])?.abi, 'universal');
  });
}
