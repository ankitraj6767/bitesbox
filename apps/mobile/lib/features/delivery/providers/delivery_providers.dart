import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import '../../../core/errors/app_error.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/storage/image_upload_service.dart';
import '../data/delivery_models.dart';
import '../data/delivery_repository.dart';

final deliveryRepositoryProvider = Provider<DeliveryRepository>(
  (ref) => DeliveryRepository(ref.watch(apiClientProvider)),
);

/// The rider's live dashboard, refreshed whenever their assignments change.
class RiderDashboardController extends AsyncNotifier<RiderDashboard> {
  StreamSubscription<void>? _subscription;

  @override
  Future<RiderDashboard> build() async {
    ref.onDispose(() => _subscription?.cancel());

    final dashboard = await ref
        .watch(deliveryRepositoryProvider)
        .dashboard(includeHistory: true);

    // Subscribe once we know the partner id. Realtime is only a signal; the whole
    // dashboard is re-read so state can never be half-applied.
    _subscription ??= ref
        .read(deliveryRepositoryProvider)
        .watchAssignments(dashboard.profile.id)
        .listen((_) => ref.invalidateSelf());

    return dashboard;
  }

  Future<void> refresh() async {
    state = const AsyncValue<RiderDashboard>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () =>
          ref.read(deliveryRepositoryProvider).dashboard(includeHistory: true),
    );
  }

  /// Duty availability is separate from GPS sharing. Going offline with a live
  /// delivery is refused by the server.
  Future<void> setDuty(DutyState next) async {
    await ref.read(deliveryRepositoryProvider).setDutyState(state: next);

    await refresh();
  }

  Future<void> respond({
    required String assignmentId,
    required bool accept,
    String? reason,
  }) async {
    await ref
        .read(deliveryRepositoryProvider)
        .respondToOffer(
          assignmentId: assignmentId,
          accept: accept,
          rejectionReason: reason,
        );
    await refresh();
  }

  Future<void> arrivedAtStore(String assignmentId) async {
    await ref.read(deliveryRepositoryProvider).arrivedAtStore(assignmentId);
    await refresh();
  }

  Future<PickupResult> verifyPickup({
    required String assignmentId,
    required String code,
  }) async {
    final result = await ref
        .read(deliveryRepositoryProvider)
        .verifyPickup(assignmentId: assignmentId, code: code);
    await refresh();
    return result;
  }

  Future<void> arrivedAtCustomer(String assignmentId) async {
    await ref.read(deliveryRepositoryProvider).arrivedAtCustomer(assignmentId);
    await refresh();
  }

  Future<void> completeDelivery({
    required String assignmentId,
    String? otp,
    double? cashCollected,
    String? note,
    String? proofPhotoPath,
  }) async {
    await ref
        .read(deliveryRepositoryProvider)
        .completeDelivery(
          assignmentId: assignmentId,
          otp: otp,
          cashCollected: cashCollected,
          note: note,
          proofPhotoPath: proofPhotoPath,
        );

    await refresh();
    ref.invalidate(riderEarningsProvider);
  }

  Future<void> failDelivery({
    required String assignmentId,
    required String reason,
    String? note,
  }) async {
    await ref
        .read(deliveryRepositoryProvider)
        .failDelivery(assignmentId: assignmentId, reason: reason, note: note);
    await refresh();
  }
}

final riderDashboardProvider =
    AsyncNotifierProvider<RiderDashboardController, RiderDashboard>(
      RiderDashboardController.new,
    );

final riderProfileProvider = Provider<RiderProfile?>((ref) {
  return ref.watch(riderDashboardProvider).valueOrNull?.profile;
});

final riderEarningsProvider = FutureProvider<RiderEarnings>((ref) async {
  return ref.watch(deliveryRepositoryProvider).earnings();
});

/// Shared image picker + uploader. One instance so a screen never constructs its
/// own and gets the storage-path convention wrong.
final imageUploadServiceProvider = Provider<ImageUploadService>(
  (ref) => ImageUploadService(ref.watch(supabaseClientProvider)),
);

/// The rider's onboarding checklist.
class RiderOnboardingController extends AsyncNotifier<RiderOnboarding> {
  @override
  Future<RiderOnboarding> build() =>
      ref.watch(deliveryRepositoryProvider).onboarding();

  Future<void> refresh() async {
    state = const AsyncValue<RiderOnboarding>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(deliveryRepositoryProvider).onboarding(),
    );
  }

  /// Uploads [file] and records it against [documentType] in one step.
  ///
  /// Upload first, then submit. If the upload succeeds and the submit fails the
  /// rider retries and the object is overwritten — harmless. The other order would
  /// record a path to a file that does not exist, which the reviewer would only
  /// discover when the preview came back empty.
  Future<void> submit({
    required RiderDocumentType type,
    required File file,
    String? documentNumber,
    DateTime? issuedOn,
    DateTime? expiresOn,
  }) async {
    final uploader = ref.read(imageUploadServiceProvider);

    final path = await uploader.upload(
      file: file,
      bucket: StorageBuckets.riderDocuments,
      name: type.code.toLowerCase(),
    );

    await ref
        .read(deliveryRepositoryProvider)
        .submitDocument(
          documentType: type.code,
          storagePath: path,
          documentNumber: documentNumber,
          issuedOn: issuedOn,
          expiresOn: expiresOn,
        );

    await refresh();
    // Onboarding status gates the duty toggle on the home screen.
    ref.invalidate(riderDashboardProvider);
  }

  Future<void> updateContactDetails({
    String? alternatePhone,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? upiId,
  }) async {
    await ref
        .read(deliveryRepositoryProvider)
        .updateProfile(
          alternatePhone: alternatePhone,
          emergencyContactName: emergencyContactName,
          emergencyContactPhone: emergencyContactPhone,
          upiId: upiId,
        );

    ref.invalidate(riderDashboardProvider);
  }
}

final riderOnboardingProvider =
    AsyncNotifierProvider<RiderOnboardingController, RiderOnboarding>(
      RiderOnboardingController.new,
    );

/// The last GPS fix this device published.
///
/// Kept separately from the dashboard so the rider's own map can draw their
/// position without a second GPS subscription draining the battery.
@immutable
class RiderFix {
  const RiderFix({
    required this.latitude,
    required this.longitude,
    this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final DateTime? recordedAt;
}

final riderLastFixProvider = StateProvider<RiderFix?>((ref) => null);

enum LocationSharingStatus {
  idle,
  requestingPermission,
  sharing,
  stale,
  permissionDenied,
  permissionRestricted,
  locationServicesOff,
  networkUnavailable,
  unavailable,
}

@immutable
class LocationSharingState {
  const LocationSharingState(this.status, {this.message});

  final LocationSharingStatus status;
  final String? message;
}

/// Location is collected only after the server confirms a rider-approved live
/// assignment. The system service is started while the app is visible so Android
/// and iOS can continue it under their foreground/background location rules.
class RiderLocationPublisher extends Notifier<LocationSharingState>
    with WidgetsBindingObserver {
  StreamSubscription<Position>? _subscription;
  Timer? _staleTimer;
  DateTime? _lastSent;
  bool _starting = false;
  bool _reconciling = false;
  String? _localStopPendingAssignmentId;
  DateTime? _streamStartedAt;

  static const _minInterval = Duration(seconds: 8);
  static const _staleAfter = Duration(minutes: 2);

  @override
  LocationSharingState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.listen(riderDashboardProvider, (_, __) => unawaited(_reconcile()));
    ref.listen(authStateChangesProvider, (_, next) {
      if (next.valueOrNull?.event == AuthChangeEvent.signedOut) {
        unawaited(_stopLocal());
        _set(LocationSharingStatus.idle);
      }
    });
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _staleTimer?.cancel();
      unawaited(_subscription?.cancel());
    });
    Future.microtask(_reconcile);
    return const LocationSharingState(LocationSharingStatus.idle);
  }

  Future<void> startSharing() async {
    if (_starting) return;
    final dashboard = ref.read(riderDashboardProvider).valueOrNull;
    final assignment = dashboard?.current;
    if (assignment == null) {
      _set(
        LocationSharingStatus.unavailable,
        'There is no active delivery to track.',
      );
      return;
    }

    _starting = true;
    _set(LocationSharingStatus.requestingPermission);
    try {
      final problem = await _checkPermissions(request: true);
      if (problem != null) {
        _set(problem.$1, problem.$2);
        return;
      }

      // Consent is stored only after device permission succeeds. The server
      // rechecks the authenticated rider and current assignment before enabling.
      await ref
          .read(deliveryRepositoryProvider)
          .setLocationSharing(
            assignmentId: assignment.assignmentId,
            enabled: true,
          );
      final userId = ref.read(apiClientProvider).currentUserId;
      if (userId != null) {
        await (await SharedPreferences.getInstance()).remove(
          _stopPendingKey(userId),
        );
      }
      await ref.read(riderDashboardProvider.notifier).refresh();
      await _reconcile();
    } on AppError catch (error) {
      _set(LocationSharingStatus.unavailable, error.message);
    } catch (_) {
      _set(
        LocationSharingStatus.unavailable,
        'Location sharing could not start. Try again.',
      );
    } finally {
      _starting = false;
    }
  }

  Future<void> stopSharing() async {
    final userId = ref.read(apiClientProvider).currentUserId;
    await _stopLocal();
    SharedPreferences? preferences;
    if (userId != null) {
      try {
        preferences = await SharedPreferences.getInstance();
        await preferences.setBool(_stopPendingKey(userId), true);
      } catch (_) {
        // Still stop locally and attempt to revoke server consent below.
      }
    }
    if (userId != null) {
      try {
        await ref.read(deliveryRepositoryProvider).stopMyLocationSharing();
        await preferences?.remove(_stopPendingKey(userId));
        _localStopPendingAssignmentId = null;
        await ref.read(riderDashboardProvider.notifier).refresh();
      } on Exception {
        final assignment = ref
            .read(riderDashboardProvider)
            .valueOrNull
            ?.current;
        _localStopPendingAssignmentId = assignment?.assignmentId;
        _set(
          LocationSharingStatus.networkUnavailable,
          'The phone stopped sharing, but we could not update the server yet. Reconnect and try again.',
        );
        return;
      }
    }
    _set(LocationSharingStatus.idle);
  }

  Future<void> openPermissionSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh from the server after settings changes or a process/background
      // transition. No old fix is queued or resent on resume.
      unawaited(ref.read(riderDashboardProvider.notifier).refresh());
    }
    // On pause/inactive the Android foreground service and iOS location mode
    // continue the already-consented active delivery.
  }

  Future<void> _reconcile() async {
    if (_reconciling) return;
    _reconciling = true;
    try {
      final dashboard = ref.read(riderDashboardProvider).valueOrNull;
      final assignment = dashboard?.current;

      final userId = ref.read(apiClientProvider).currentUserId;
      if (userId != null) {
        SharedPreferences preferences;
        try {
          preferences = await SharedPreferences.getInstance();
        } catch (_) {
          await _stopLocal();
          _localStopPendingAssignmentId = dashboard?.current?.assignmentId;
          _set(
            LocationSharingStatus.unavailable,
            'Location sharing could not verify the saved stop request. Reopen the app and retry.',
          );
          return;
        }
        if (preferences.getBool(_stopPendingKey(userId)) == true) {
          await _stopLocal();
          try {
            await ref.read(deliveryRepositoryProvider).stopMyLocationSharing();
            await preferences.remove(_stopPendingKey(userId));
            _localStopPendingAssignmentId = null;
            _set(LocationSharingStatus.idle);
            unawaited(ref.read(riderDashboardProvider.notifier).refresh());
          } catch (_) {
            _set(
              LocationSharingStatus.networkUnavailable,
              'Location is stopped on this phone. Reconnect so the server can confirm the stop.',
            );
          }
          return;
        }
      }
      if (assignment == null ||
          !dashboard!.isSharingLocationFor(assignment.assignmentId)) {
        await _stopLocal();
        if (_localStopPendingAssignmentId != assignment?.assignmentId) {
          _localStopPendingAssignmentId = null;
          _set(LocationSharingStatus.idle);
        }
        return;
      }

      if (_localStopPendingAssignmentId == assignment.assignmentId) {
        await _stopLocal();
        _set(
          LocationSharingStatus.networkUnavailable,
          'Sharing is paused on this phone. Reconnect and tap Stop sharing to update the server.',
        );
        return;
      }

      final problem = await _checkPermissions(request: false);
      if (problem != null) {
        await _stopLocal();
        _set(problem.$1, problem.$2);
        if (problem.$1 == LocationSharingStatus.permissionDenied ||
            problem.$1 == LocationSharingStatus.permissionRestricted) {
          await ref
              .read(deliveryRepositoryProvider)
              .setLocationSharing(
                assignmentId: assignment.assignmentId,
                enabled: false,
              );
          unawaited(ref.read(riderDashboardProvider.notifier).refresh());
        }
        return;
      }

      await _startLocalStream();
    } finally {
      _reconciling = false;
    }
  }

  Future<(LocationSharingStatus, String)?> _checkPermissions({
    required bool request,
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return (
        LocationSharingStatus.locationServicesOff,
        'Turn on Location Services to share this delivery with the customer.',
      );
    }

    final status = await Permission.locationWhenInUse.status;
    if (status.isRestricted) {
      return (
        LocationSharingStatus.permissionRestricted,
        'Location access is restricted on this device. Ask the device administrator for help.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && request) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return (
        LocationSharingStatus.permissionDenied,
        'Location access is blocked. Open app settings to allow it while using Bites Box.',
      );
    }
    if (permission == LocationPermission.denied) {
      return (
        LocationSharingStatus.permissionDenied,
        'Location access is off. Allow it while using Bites Box to share this delivery.',
      );
    }
    if (permission == LocationPermission.unableToDetermine) {
      return (
        LocationSharingStatus.permissionRestricted,
        'This device cannot currently confirm location access. Check its privacy settings.',
      );
    }
    return null;
  }

  Future<void> _startLocalStream() async {
    if (_subscription != null) {
      if (state.status == LocationSharingStatus.stale ||
          state.status == LocationSharingStatus.networkUnavailable) {
        return;
      }
      _set(LocationSharingStatus.sharing);
      return;
    }

    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 40,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Bites Box delivery location',
          notificationText:
              'Sharing only for an active delivery. Open the app to stop or finish.',
          notificationChannelName: 'Active delivery tracking',
          setOngoing: true,
        ),
      );
    } else if (Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 40,
        pauseLocationUpdatesAutomatically: true,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 40,
      );
    }

    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          (position) => unawaited(_publish(position)),
          onError: (Object error) => unawaited(_handleStreamError(error)),
          cancelOnError: false,
        );
    _streamStartedAt = DateTime.now().toUtc();
    _staleTimer?.cancel();
    _staleTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final fixAt =
          ref.read(riderLastFixProvider)?.recordedAt ?? _streamStartedAt;
      if (fixAt != null &&
          DateTime.now().toUtc().difference(fixAt.toUtc()) > _staleAfter) {
        _set(
          LocationSharingStatus.stale,
          'Your last GPS update is old. Check Location Services and battery saver or background restrictions.',
        );
      }
    });
    _set(LocationSharingStatus.sharing);
  }

  Future<void> _stopLocal() async {
    await _subscription?.cancel();
    _subscription = null;
    _staleTimer?.cancel();
    _staleTimer = null;
    _lastSent = null;
    _streamStartedAt = null;
    ref.read(riderLastFixProvider.notifier).state = null;
  }

  Future<void> _handleStreamError(Object _) async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await _stopLocal();
      _set(
        LocationSharingStatus.permissionDenied,
        'Location access was removed. Allow it in settings to resume tracking.',
      );
      final dashboard = ref.read(riderDashboardProvider).valueOrNull;
      final assignment = dashboard?.current;
      if (assignment != null) {
        await ref
            .read(deliveryRepositoryProvider)
            .setLocationSharing(
              assignmentId: assignment.assignmentId,
              enabled: false,
            )
            .catchError((_) {});
        unawaited(ref.read(riderDashboardProvider.notifier).refresh());
      }
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      await _stopLocal();
      _set(
        LocationSharingStatus.locationServicesOff,
        'Location Services are off. Turn them on to resume delivery tracking.',
      );
      return;
    }
    _set(
      LocationSharingStatus.unavailable,
      'The phone paused GPS. Reopen the app and try again.',
    );
    await _stopLocal();
  }

  Future<void> _publish(Position position) async {
    final capturedAt = position.timestamp.toUtc();
    final now = DateTime.now().toUtc();
    final decision = evaluateRiderFix(
      capturedAt: capturedAt,
      now: now,
      lastSent: _lastSent,
      staleAfter: _staleAfter,
      minimumInterval: _minInterval,
    );
    if (decision == RiderFixDecision.stale ||
        decision == RiderFixDecision.future) {
      _set(
        LocationSharingStatus.stale,
        'The phone returned an old GPS fix. Waiting for a new one.',
      );
      return;
    }
    if (decision == RiderFixDecision.outOfOrder ||
        decision == RiderFixDecision.tooSoon) {
      return;
    }

    try {
      final keepGoing = await ref
          .read(deliveryRepositoryProvider)
          .publishLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            capturedAt: capturedAt,
            accuracyMeters: position.accuracy,
            headingDegrees: position.heading,
            speedKmph: position.speed * 3.6,
            isMoving: position.speed > 0.5,
          );
      if (!keepGoing) {
        await _stopLocal();
        _set(LocationSharingStatus.idle);
        unawaited(ref.read(riderDashboardProvider.notifier).refresh());
        return;
      }

      _lastSent = capturedAt;
      ref.read(riderLastFixProvider.notifier).state = RiderFix(
        latitude: position.latitude,
        longitude: position.longitude,
        recordedAt: capturedAt,
      );
      _set(LocationSharingStatus.sharing);
    } on AppError {
      // Do not queue or replay this fix. The next OS capture is the only retry.
      _set(
        LocationSharingStatus.networkUnavailable,
        'Location could not reach the server. Waiting for a fresh GPS update.',
      );
    } on Exception {
      _set(
        LocationSharingStatus.networkUnavailable,
        'Location could not reach the server. Waiting for a fresh GPS update.',
      );
    } catch (_) {
      _set(
        LocationSharingStatus.networkUnavailable,
        'Location could not reach the server. Waiting for a fresh GPS update.',
      );
    }
  }

  void _set(LocationSharingStatus status, [String? message]) {
    state = LocationSharingState(status, message: message);
  }

  void stop() {
    unawaited(_stopLocal());
  }

  String _stopPendingKey(String userId) =>
      'rider_location_stop_pending_$userId';
}

final riderLocationPublisherProvider =
    NotifierProvider<RiderLocationPublisher, LocationSharingState>(
      RiderLocationPublisher.new,
    );
