import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'update_installer.dart';
import 'update_manifest.dart';
import 'update_service.dart';

final currentVersionLoaderProvider = Provider<CurrentVersionLoader>((ref) {
  return () async {
    final info = await PackageInfo.fromPlatform();
    return AppVersion.tryParse(info.version, build: int.tryParse(info.buildNumber)) ??
        const AppVersion(0, 0, 0);
  };
});

final updateConfigProvider = Provider<UpdateConfig>((ref) => UpdateConfig.resolve());

final updateServiceProvider = Provider<UpdateService>((ref) {
  final service = UpdateService(
    config: ref.watch(updateConfigProvider),
    currentVersionLoader: ref.watch(currentVersionLoaderProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final updateInstallerProvider = Provider<UpdateInstaller>((ref) {
  final installer = UpdateInstaller();
  ref.onDispose(installer.dispose);
  return installer;
});

@immutable
class UpdateUiState {
  const UpdateUiState({
    this.availability,
    this.isChecking = false,
    this.isInstalling = false,
    this.progress = const UpdateProgress.idle(),
    this.error,
    this.checkedOnLaunch = false,
    this.prompted = false,
  });

  final UpdateAvailability? availability;
  final bool isChecking;
  final bool isInstalling;
  final UpdateProgress progress;
  final String? error;
  final bool checkedOnLaunch;
  final bool prompted;

  bool get hasUpdate => availability?.hasUpdate == true;
  bool get mandatory => availability?.mandatory == true;
  bool get shouldPrompt => hasUpdate && (mandatory || !prompted);

  UpdateUiState copyWith({
    UpdateAvailability? availability,
    bool? isChecking,
    bool? isInstalling,
    UpdateProgress? progress,
    String? error,
    bool clearError = false,
    bool? checkedOnLaunch,
    bool? prompted,
  }) => UpdateUiState(
        availability: availability ?? this.availability,
        isChecking: isChecking ?? this.isChecking,
        isInstalling: isInstalling ?? this.isInstalling,
        progress: progress ?? this.progress,
        error: clearError ? null : (error ?? this.error),
        checkedOnLaunch: checkedOnLaunch ?? this.checkedOnLaunch,
        prompted: prompted ?? this.prompted,
      );
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateUiState>(UpdateController.new);

class UpdateController extends Notifier<UpdateUiState> {
  @override
  UpdateUiState build() => const UpdateUiState();

  Future<void> checkOnLaunch() async {
    if (state.checkedOnLaunch) return;
    state = state.copyWith(checkedOnLaunch: true);
    await checkNow();
  }

  Future<UpdateAvailability?> checkNow() async {
    if (state.isChecking) return state.availability;
    state = state.copyWith(isChecking: true, clearError: true);
    try {
      final availability = await ref.read(updateServiceProvider).check();
      state = state.copyWith(availability: availability, isChecking: false);
      return availability;
    } on UpdateException catch (error) {
      state = state.copyWith(isChecking: false, error: error.message);
      return null;
    } catch (error) {
      state = state.copyWith(isChecking: false, error: '$error');
      return null;
    }
  }

  void markPrompted() => state = state.copyWith(prompted: true);

  Future<void> install() async {
    final artifact = state.availability?.artifact;
    if (artifact == null || state.isInstalling) return;
    state = state.copyWith(
      isInstalling: true,
      progress: const UpdateProgress(phase: InstallPhase.preparing),
      clearError: true,
    );
    try {
      await ref.read(updateInstallerProvider).install(
            artifact,
            onProgress: (progress) => state = state.copyWith(progress: progress),
          );
      state = state.copyWith(isInstalling: false);
    } on UpdateException catch (error) {
      state = state.copyWith(isInstalling: false, error: error.message, progress: const UpdateProgress(phase: InstallPhase.failed));
    } catch (error) {
      state = state.copyWith(isInstalling: false, error: '$error', progress: const UpdateProgress(phase: InstallPhase.failed));
    }
  }
}
