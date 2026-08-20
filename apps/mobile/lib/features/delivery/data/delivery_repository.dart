import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import 'delivery_models.dart';

/// The rider's side of a delivery.
///
/// The sequence is enforced in Postgres, not here: a rider cannot mark an order
/// delivered without the customer OTP (or an audited manager override), and cannot
/// go offline while carrying food.
class DeliveryRepository {
  const DeliveryRepository(this._api);

  final ApiClient _api;

  Future<RiderDashboard> dashboard({bool includeHistory = false}) async {
    final result = await _api.rpc<dynamic>(
      'my_deliveries',
      params: {'p_include_history': includeHistory},
      dedupeKey: 'my_deliveries:$includeHistory',
    );

    return RiderDashboard.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<RiderEarnings> earnings({DateTime? from, DateTime? to}) async {
    final result = await _api.rpc<dynamic>(
      'my_earnings',
      params: {
        if (from != null) 'p_from': _date(from),
        if (to != null) 'p_to': _date(to),
      },
    );

    return RiderEarnings.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// Going online seeds the live location so dispatch can rank by proximity.
  Future<void> setDutyState({
    required DutyState state,
    double? latitude,
    double? longitude,
    int? batteryLevel,
    String? reason,
  }) async {
    await _api.rpc<dynamic>('set_duty_state', params: {
      'p_state': state.code,
      if (latitude != null) 'p_latitude': latitude,
      if (longitude != null) 'p_longitude': longitude,
      if (batteryLevel != null) 'p_battery_level': batteryLevel,
      if (reason != null) 'p_reason': reason,
    });
  }

  Future<void> respondToOffer({
    required String assignmentId,
    required bool accept,
    String? rejectionReason,
  }) async {
    await _api.rpc<dynamic>(
      'respond_to_assignment',
      params: {
        'p_assignment_id': assignmentId,
        'p_accept': accept,
        if (rejectionReason != null) 'p_rejection_reason': rejectionReason,
      },
      dedupeKey: 'respond_assignment:$assignmentId',
    );
  }

  Future<void> arrivedAtStore(String assignmentId) async {
    await _api.rpc<dynamic>(
      'rider_arrived_at_store',
      params: {'p_assignment_id': assignmentId},
      dedupeKey: 'arrived_store:$assignmentId',
    );
  }

  /// Verifies the code on the kitchen ticket. On success the server returns the
  /// destination and the exact cash to collect.
  Future<PickupResult> verifyPickup({
    required String assignmentId,
    required String code,
  }) async {
    final result = await _api.rpc<dynamic>(
      'verify_pickup',
      params: {'p_assignment_id': assignmentId, 'p_code': code.trim()},
    );

    return PickupResult.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<void> arrivedAtCustomer(String assignmentId) async {
    await _api.rpc<dynamic>(
      'rider_arrived_at_customer',
      params: {'p_assignment_id': assignmentId},
      dedupeKey: 'arrived_customer:$assignmentId',
    );
  }

  /// Completes the delivery. [otp] is required unless a manager overrides, and
  /// [cashCollected] must cover the COD amount or the server refuses.
  /// [proofPhotoPath] is the object key in the `delivery-proofs` bucket. It is
  /// what settles "it was left at the door" three days later, so it is captured
  /// before the OTP is submitted rather than after — once the delivery is closed
  /// there is nothing to attach it to.
  Future<void> completeDelivery({
    required String assignmentId,
    String? otp,
    double? cashCollected,
    String? note,
    String? proofPhotoPath,
    bool managerOverride = false,
  }) async {
    await _api.rpc<dynamic>('complete_delivery', params: {
      'p_assignment_id': assignmentId,
      'p_manager_override': managerOverride,
      if (otp != null && otp.trim().isNotEmpty) 'p_otp': otp.trim(),
      if (cashCollected != null) 'p_cash_collected': cashCollected,
      if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
      if (proofPhotoPath != null && proofPhotoPath.trim().isNotEmpty)
        'p_proof_photo_path': proofPhotoPath.trim(),
    });
  }

  Future<void> failDelivery({
    required String assignmentId,
    required String reason,
    String? note,
  }) async {
    await _api.rpc<dynamic>('fail_delivery', params: {
      'p_assignment_id': assignmentId,
      'p_reason': reason,
      if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
    });
  }

  /// Publishes a GPS fix. Returns false once there is nothing live to track, which
  /// tells the app to stop sampling and save the rider's battery.
  Future<bool> publishLocation({
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    double? headingDegrees,
    double? speedKmph,
    int? batteryLevel,
    bool isMoving = true,
  }) async {
    final result = await _api.rpc<dynamic>('publish_rider_location', params: {
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_is_moving': isMoving,
      if (accuracyMeters != null) 'p_accuracy_meters': accuracyMeters,
      if (headingDegrees != null) 'p_heading_degrees': headingDegrees,
      if (speedKmph != null) 'p_speed_kmph': speedKmph,
      if (batteryLevel != null) 'p_battery_level': batteryLevel,
    });

    if (result is! Map) return false;
    return result['should_keep_publishing'] == true;
  }

  // ─── Onboarding ───────────────────────────────────────────────────────────

  /// The rider's own checklist: what is submitted, approved and still outstanding.
  ///
  /// The required-document list is decided server-side, so a rider on a bicycle is
  /// not asked for a vehicle RC and an outlet can change its requirements without
  /// an app release.
  Future<RiderOnboarding> onboarding() async {
    final result = await _api.rpc<dynamic>(
      'my_rider_onboarding',
      dedupeKey: 'my_rider_onboarding',
    );

    return RiderOnboarding.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// Records an already-uploaded document.
  ///
  /// [storagePath] must be the object key returned by the uploader. The server
  /// re-checks that it starts with this rider's user id before accepting it, so a
  /// crafted call cannot point at somebody else's file.
  Future<void> submitDocument({
    required String documentType,
    required String storagePath,
    String? documentNumber,
    DateTime? issuedOn,
    DateTime? expiresOn,
  }) async {
    await _api.rpc<dynamic>(
      'submit_rider_document',
      params: {
        'p_document_type': documentType,
        'p_storage_path': storagePath,
        if (documentNumber != null && documentNumber.trim().isNotEmpty)
          'p_document_number': documentNumber.trim(),
        if (issuedOn != null) 'p_issued_on': _date(issuedOn),
        if (expiresOn != null) 'p_expires_on': _date(expiresOn),
      },
      dedupeKey: 'submit_document:$documentType',
    );
  }

  /// Updates only the fields a rider owns.
  ///
  /// Deliberately narrow. The `delivery_partners` row has no self-update policy
  /// because riders and staff are both `authenticated`, so a column grant could not
  /// separate them — a rider was previously able to set their own onboarding
  /// status, zero their cash-in-hand and inflate their rating. Everything else is
  /// corrected by a manager, which is audited.
  Future<void> updateProfile({
    String? alternatePhone,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? upiId,
    String? photoPath,
  }) async {
    await _api.rpc<dynamic>('update_my_rider_profile', params: {
      if (_present(alternatePhone)) 'p_alternate_phone': alternatePhone!.trim(),
      if (_present(emergencyContactName))
        'p_emergency_contact_name': emergencyContactName!.trim(),
      if (_present(emergencyContactPhone))
        'p_emergency_contact_phone': emergencyContactPhone!.trim(),
      if (_present(upiId)) 'p_upi_id': upiId!.trim(),
      if (_present(photoPath)) 'p_photo_path': photoPath!.trim(),
    });
  }

  /// Signals when this rider's assignments change, so a new offer appears without
  /// polling. The payload is ignored and the dashboard is re-read.
  Stream<void> watchAssignments(String deliveryPartnerId) {
    final controller = StreamController<void>.broadcast();

    final channel = _api.raw.channel('rider:$deliveryPartnerId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'delivery_assignments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'delivery_partner_id',
          value: deliveryPartnerId,
        ),
        callback: (_) => controller.add(null),
      );

    channel.subscribe();

    controller.onCancel = () async {
      await _api.raw.removeChannel(channel);
    };

    return controller.stream;
  }

  /// Reasons a rider can give for declining or failing, matching what operations
  /// expects to see in the order notes.
  static const declineReasons = <String>[
    'Too far from me',
    'My vehicle has a problem',
    'I am finishing another delivery',
    'End of my shift',
  ];

  static const failureReasons = <String>[
    'Customer not reachable',
    'Wrong or incomplete address',
    'Customer refused the order',
    'Cannot access the building',
    'Vehicle breakdown',
  ];

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  /// Omitted rather than nulled: every parameter on `update_my_rider_profile`
  /// coalesces, so a null means "leave unchanged" and sending one is pointless.
  static bool _present(String? value) => value != null && value.trim().isNotEmpty;
}
