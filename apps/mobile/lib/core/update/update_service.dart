import 'dart:async';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';
import 'update_manifest.dart';

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

@immutable
class UpdateConfig {
  const UpdateConfig({required this.manifestUrl, required this.platform});

  final String manifestUrl;
  final UpdatePlatform platform;

  static const overrideUrl = String.fromEnvironment('UPDATE_MANIFEST_URL');

  factory UpdateConfig.resolve() {
    final base = Env.supabaseUrl.replaceFirst(RegExp(r'/$'), '');
    return UpdateConfig(
      manifestUrl: overrideUrl.isNotEmpty
          ? overrideUrl
          : '$base/storage/v1/object/public/app-releases/update-manifest.json',
      platform: currentUpdatePlatform(),
    );
  }
}

typedef CurrentVersionLoader = Future<AppVersion> Function();

class UpdateService {
  UpdateService({required this.config, required this.currentVersionLoader, http.Client? client})
      : _client = client ?? http.Client();

  final UpdateConfig config;
  final CurrentVersionLoader currentVersionLoader;
  final http.Client _client;

  Future<UpdateAvailability> check() async {
    if (config.platform != UpdatePlatform.android) {
      return UpdateAvailability.none;
    }

    final current = await currentVersionLoader();
    final manifest = await _fetchManifest();
    final release = manifest.android;
    if (release == null || release.appVersion.compareTo(current) <= 0) {
      return UpdateAvailability(hasUpdate: false, currentVersion: current);
    }

    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final artifact = release.artifactFor(deviceInfo.supportedAbis);
    if (artifact == null) {
      throw const UpdateException('No compatible update is available for this device.');
    }

    return UpdateAvailability(
      hasUpdate: true,
      release: release,
      artifact: artifact,
      currentVersion: current,
    );
  }

  Future<UpdateManifest> _fetchManifest() async {
    final response = await _client
        .get(Uri.parse(config.manifestUrl), headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw UpdateException('Update server returned HTTP ${response.statusCode}.');
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return UpdateManifest.fromJson(decoded);
    } catch (_) {
      throw const UpdateException('The update manifest is malformed.');
    }
  }

  void dispose() => _client.close();
}
