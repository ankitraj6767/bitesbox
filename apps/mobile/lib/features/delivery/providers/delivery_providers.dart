import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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

    final dashboard =
        await ref.watch(deliveryRepositoryProvider).dashboard(includeHistory: true);

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
      () => ref.read(deliveryRepositoryProvider).dashboard(includeHistory: true),
    );
  }

  /// Toggling duty sends the current position so dispatch can rank by proximity.
  /// Going offline with a live delivery is refused by the server.
  Future<void> setDuty(DutyState next) async {
    final position = await _currentPosition();

    await ref.read(deliveryRepositoryProvider).setDutyState(
          state: next,
          latitude: position?.latitude,
          longitude: position?.longitude,
        );

    await refresh();
  }

  Future<void> respond({required String assignmentId, required bool accept, String? reason}) async {
    await ref.read(deliveryRepositoryProvider).respondToOffer(
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
    await ref.read(deliveryRepositoryProvider).completeDelivery(
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

  /// Best-effort location read. A rider who has denied permission can still work;
  /// only the live-tracking map degrades.
  Future<Position?> _currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on Exception {
      return null;
    }
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

    await ref.read(deliveryRepositoryProvider).submitDocument(
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
    await ref.read(deliveryRepositoryProvider).updateProfile(
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

/// Publishes the rider's GPS while a delivery is live, and stops as soon as the
/// server says there is nothing left to track.
///
/// Distance-filtered rather than time-based: a stationary rider waiting at a
/// traffic light does not drain their battery sending identical fixes.
class RiderLocationPublisher extends Notifier<bool> {
  StreamSubscription<Position>? _subscription;
  DateTime? _lastSent;

  static const _minInterval = Duration(seconds: 8);

  @override
  bool build() {
    ref.onDispose(stop);

    // Follow the dashboard: start when a delivery is live, stop when it is not.
    final dashboard = ref.watch(riderDashboardProvider).valueOrNull;
    final shouldRun = dashboard?.shouldPublishLocation ?? false;

    if (shouldRun) {
      Future.microtask(start);
    } else {
      Future.microtask(stop);
    }

    return shouldRun;
  }

  Future<void> start() async {
    if (_subscription != null) return;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 40,
      ),
    ).listen(_publish, onError: (_) {});
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _publish(Position position) async {
    final now = DateTime.now();
    final last = _lastSent;
    if (last != null && now.difference(last) < _minInterval) return;
    _lastSent = now;

    try {
      final keepGoing = await ref.read(deliveryRepositoryProvider).publishLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyMeters: position.accuracy,
            headingDegrees: position.heading,
            speedKmph: position.speed * 3.6,
            isMoving: position.speed > 0.5,
          );

      // Only record a fix the server accepted, so the rider's own map agrees with
      // what the customer is being shown.
      ref.read(riderLastFixProvider.notifier).state = RiderFix(
        latitude: position.latitude,
        longitude: position.longitude,
        recordedAt: DateTime.now(),
      );

      if (!keepGoing) stop();
    } on AppError {
      // A failed fix is not worth interrupting a delivery for.
    }
  }
}

final riderLocationPublisherProvider =
    NotifierProvider<RiderLocationPublisher, bool>(RiderLocationPublisher.new);
