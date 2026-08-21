import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'update_manifest.dart';
import 'update_service.dart';

enum InstallPhase { idle, preparing, downloading, verifying, installing, completed, failed }

class UpdateProgress {
  const UpdateProgress({required this.phase, this.received = 0, this.total = 0});

  const UpdateProgress.idle() : this(phase: InstallPhase.idle);

  final InstallPhase phase;
  final int received;
  final int total;

  double? get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : null;
}

class UpdateInstaller {
  UpdateInstaller({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> install(
    UpdateArtifact artifact, {
    required void Function(UpdateProgress progress) onProgress,
  }) async {
    try {
      onProgress(const UpdateProgress(phase: InstallPhase.preparing));
      var permission = await Permission.requestInstallPackages.status;
      if (!permission.isGranted) permission = await Permission.requestInstallPackages.request();
      if (!permission.isGranted) {
        throw const UpdateException(
          'Allow Bites Box to install unknown apps, then try the update again.',
        );
      }

      final directory = await getTemporaryDirectory();
      final file = File(path.join(directory.path, _safeFileName(artifact.fileName)));
      final response = await _client
          .send(http.Request('GET', Uri.parse(artifact.url)))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        throw UpdateException('Download failed with HTTP ${response.statusCode}.');
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      onProgress(const UpdateProgress(phase: InstallPhase.downloading));
      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(UpdateProgress(phase: InstallPhase.downloading, received: received, total: total));
      }
      await sink.close();

      final expected = artifact.sha256?.trim().toLowerCase();
      if (expected != null && expected.isNotEmpty) {
        onProgress(const UpdateProgress(phase: InstallPhase.verifying));
        final actual = (await sha256.bind(file.openRead()).first).toString();
        if (actual != expected) {
          await file.delete().catchError((_) => file);
          throw const UpdateException('The update failed integrity verification.');
        }
      }

      onProgress(const UpdateProgress(phase: InstallPhase.installing));
      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done) {
        throw UpdateException('Could not open the Android installer: ${result.message}.');
      }
      onProgress(const UpdateProgress(phase: InstallPhase.completed));
    } on UpdateException {
      rethrow;
    } on TimeoutException {
      throw const UpdateException('The update download timed out.');
    } catch (error) {
      throw UpdateException('Update failed: $error');
    }
  }

  String _safeFileName(String value) {
    final name = path.basename(value).replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return name.isEmpty ? 'bitesbox-update.apk' : name;
  }

  void dispose() => _client.close();
}
