import 'package:flutter/foundation.dart';

/// Platforms for which this app has a self-updatable artifact.
enum UpdatePlatform { android, unsupported }

UpdatePlatform currentUpdatePlatform() {
  if (kIsWeb) return UpdatePlatform.unsupported;
  return defaultTargetPlatform == TargetPlatform.android
      ? UpdatePlatform.android
      : UpdatePlatform.unsupported;
}

@immutable
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, {this.build});

  final int major;
  final int minor;
  final int patch;
  final int? build;

  static AppVersion? tryParse(String? raw, {int? build}) {
    if (raw == null || raw.trim().isEmpty) return null;
    var value = raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final plus = value.indexOf('+');
    if (plus >= 0) {
      build ??= int.tryParse(value.substring(plus + 1));
      value = value.substring(0, plus);
    }
    final dash = value.indexOf('-');
    if (dash >= 0) value = value.substring(0, dash);
    final parts = value.split('.');
    final major = int.tryParse(parts.first);
    if (major == null) return null;
    int component(int index) =>
        index < parts.length ? int.tryParse(parts[index]) ?? 0 : 0;
    return AppVersion(major, component(1), component(2), build: build);
  }

  @override
  int compareTo(AppVersion other) {
    final version = major.compareTo(other.major);
    if (version != 0) return version;
    final minorVersion = minor.compareTo(other.minor);
    if (minorVersion != 0) return minorVersion;
    final patchVersion = patch.compareTo(other.patch);
    if (patchVersion != 0) return patchVersion;
    return (build ?? 0).compareTo(other.build ?? 0);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator <(AppVersion other) => compareTo(other) < 0;

  String get displayLabel => build == null
      ? '$major.$minor.$patch'
      : '$major.$minor.$patch ($build)';

  @override
  String toString() => displayLabel;
}

@immutable
class UpdateArtifact {
  const UpdateArtifact({
    required this.abi,
    required this.url,
    required this.fileName,
    this.sha256,
  });

  final String abi;
  final String url;
  final String fileName;
  final String? sha256;

  factory UpdateArtifact.fromJson(Map<String, dynamic> json) => UpdateArtifact(
        abi: (json['abi'] as String?) ?? 'universal',
        url: (json['url'] as String?) ?? '',
        fileName: (json['fileName'] as String?) ?? 'bitesbox-update.apk',
        sha256: json['sha256'] as String?,
      );
}

@immutable
class AndroidRelease {
  const AndroidRelease({
    required this.version,
    required this.buildNumber,
    required this.artifacts,
    this.notes,
    this.mandatory = false,
    this.minSupportedVersion,
  });

  final String version;
  final int? buildNumber;
  final List<UpdateArtifact> artifacts;
  final String? notes;
  final bool mandatory;
  final String? minSupportedVersion;

  AppVersion get appVersion =>
      AppVersion.tryParse(version, build: buildNumber) ??
      const AppVersion(0, 0, 0);

  UpdateArtifact? artifactFor(Iterable<String> supportedAbis) {
    for (final abi in supportedAbis) {
      for (final artifact in artifacts) {
        if (artifact.abi == abi && artifact.url.isNotEmpty) return artifact;
      }
    }
    return artifacts
        .where((artifact) => artifact.abi == 'universal' && artifact.url.isNotEmpty)
        .firstOrNull;
  }

  factory AndroidRelease.fromJson(Map<String, dynamic> json) {
    final rawArtifacts = json['artifacts'];
    final artifacts = rawArtifacts is List
        ? rawArtifacts
            .whereType<Map>()
            .map((item) => UpdateArtifact.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <UpdateArtifact>[];

    // Accept the simple single-URL shape too, so the manifest can be repaired
    // manually without needing an APK matrix.
    if (artifacts.isEmpty && json['url'] is String) {
      artifacts.add(
        UpdateArtifact(
          abi: 'universal',
          url: json['url'] as String,
          fileName: (json['fileName'] as String?) ?? 'bitesbox-update.apk',
          sha256: json['sha256'] as String?,
        ),
      );
    }

    return AndroidRelease(
      version: (json['version'] as String?) ?? '0.0.0',
      buildNumber: (json['buildNumber'] as num?)?.toInt(),
      artifacts: artifacts,
      notes: json['notes'] as String?,
      mandatory: json['mandatory'] == true,
      minSupportedVersion: json['minSupportedVersion'] as String?,
    );
  }
}

@immutable
class UpdateManifest {
  const UpdateManifest({this.android});

  final AndroidRelease? android;

  factory UpdateManifest.fromJson(Map<String, dynamic> json) => UpdateManifest(
        android: json['android'] is Map
            ? AndroidRelease.fromJson(
                Map<String, dynamic>.from(json['android'] as Map),
              )
            : null,
      );
}

@immutable
class UpdateAvailability {
  const UpdateAvailability({
    required this.hasUpdate,
    this.release,
    this.artifact,
    this.currentVersion,
  });

  final bool hasUpdate;
  final AndroidRelease? release;
  final UpdateArtifact? artifact;
  final AppVersion? currentVersion;

  bool get mandatory {
    final current = currentVersion;
    final releaseVersion = release;
    if (!hasUpdate || current == null || releaseVersion == null) return false;
    final minimum = AppVersion.tryParse(releaseVersion.minSupportedVersion);
    return releaseVersion.mandatory || (minimum != null && current < minimum);
  }

  static const none = UpdateAvailability(hasUpdate: false);
}
