import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/core_providers.dart';
import 'push_service.dart';

final pushServiceProvider = Provider<PushService>((ref) => PushService());

/// Owns this device's push registration for the signed-in user.
///
/// Registration is per user *and* per device: `register_device_token` upserts on
/// the token, so a handset that changes hands re-points cleanly, and sign-out
/// detaches it. Nothing here trusts the client — the row is written by a
/// SECURITY DEFINER function scoped to `auth.uid()`.
class PushRegistrar extends AsyncNotifier<String?> {
  StreamSubscription<String>? _refreshSubscription;

  @override
  Future<String?> build() async {
    ref.onDispose(() => _refreshSubscription?.cancel());

    final session = ref.watch(sessionProvider).valueOrNull;

    // Guests have nothing to register against; the token is requested the moment
    // they sign in, because that is when a notification could be addressed to them.
    if (session == null || session.isGuest || !session.accountActive) {
      return null;
    }

    final service = ref.read(pushServiceProvider);
    if (!await service.initialise()) return null;

    final granted = await service.requestPermission();
    if (!granted) {
      debugPrint('Push permission not granted; staying on in-app notifications.');
      return null;
    }

    final token = await service.token();
    if (token == null) return null;

    await _register(token);

    // Firebase rotates tokens; a stale row means silent notification loss.
    _refreshSubscription ??= service.onTokenRefresh.listen((next) async {
      await _register(next);
      state = AsyncValue.data(next);
    });

    return token;
  }

  Future<void> _register(String token) async {
    try {
      final device = await _describeDevice();

      await ref.read(authRepositoryProvider).registerDevice(
            token: token,
            platform: device.platform,
            deviceModel: device.model,
            osVersion: device.osVersion,
            appVersion: device.appVersion,
            locale: device.locale,
          );
    } on Object catch (error) {
      // Failing to register must not block the app; the next launch retries.
      debugPrint('Could not register the push token: $error');
    }
  }

  static Future<_DeviceDescription> _describeDevice() async {
    final info = DeviceInfoPlugin();
    final package = await PackageInfo.fromPlatform();
    final locale = Platform.localeName;

    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      return _DeviceDescription(
        platform: 'ANDROID',
        model: '${android.manufacturer} ${android.model}'.trim(),
        osVersion: 'Android ${android.version.release}',
        appVersion: '${package.version}+${package.buildNumber}',
        locale: locale,
      );
    }

    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      return _DeviceDescription(
        platform: 'IOS',
        model: ios.utsname.machine,
        osVersion: '${ios.systemName} ${ios.systemVersion}',
        appVersion: '${package.version}+${package.buildNumber}',
        locale: locale,
      );
    }

    return _DeviceDescription(
      platform: 'WEB',
      model: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
      appVersion: '${package.version}+${package.buildNumber}',
      locale: locale,
    );
  }
}

class _DeviceDescription {
  const _DeviceDescription({
    required this.platform,
    required this.model,
    required this.osVersion,
    required this.appVersion,
    required this.locale,
  });

  final String platform;
  final String model;
  final String osVersion;
  final String appVersion;
  final String locale;
}

final pushRegistrarProvider =
    AsyncNotifierProvider<PushRegistrar, String?>(PushRegistrar.new);

/// The current device token, or null when push is unavailable. Passed to sign-out
/// so the row is detached from this user.
final pushTokenProvider = Provider<String?>((ref) {
  return ref.watch(pushRegistrarProvider).valueOrNull;
});

/// Notifications arriving while the app is on screen. Android does not display
/// these itself, so the app shows an in-app banner instead.
final pushForegroundProvider = StreamProvider<PushPayload>((ref) {
  return ref
      .watch(pushServiceProvider)
      .onMessage
      .map(PushPayload.fromMessage)
      .where((payload) => payload.hasContent);
});

/// A notification the user tapped, either from the background or a cold start.
final pushOpenedProvider = StreamProvider<PushPayload>((ref) async* {
  final service = ref.watch(pushServiceProvider);

  final launch = await service.initialMessage();
  if (launch != null) yield PushPayload.fromMessage(launch);

  yield* service.onMessageOpenedApp.map(PushPayload.fromMessage);
});
