import 'package:bitesbox/features/delivery/data/delivery_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rider screens show exactly one action at a time, derived from the assignment
/// status the server reports. If that derivation is wrong the rider is told to do
/// the wrong thing, so it is pinned here alongside the JSON contract of
/// `my_deliveries()`.
void main() {
  Map<String, dynamic> assignmentJson({
    String status = 'ACCEPTED',
    String? expiresAt,
    double codAmount = 0,
    double payout = 45,
  }) {
    return {
      'assignment_id': 'a-1',
      'status': status,
      'offered_at': '2026-08-19T10:00:00Z',
      if (expiresAt != null) 'expires_at': expiresAt,
      'total_payout': payout,
      'order': {
        'id': 'o-1',
        'order_number': 'BB-BKP01-260819-00005',
        'status': 'RIDER_ASSIGNED',
        'item_count': 2,
        'unit_count': 3,
        'payment_mode': codAmount > 0 ? 'COD' : 'ONLINE',
        'cod_amount': codAmount,
        'grand_total': 632,
        'customer_name': 'Diya Sharma',
        'customer_phone': '+919900000002',
        'address': '12 Station Road, Bakhtiyarpur',
        'latitude': 25.4632,
        'longitude': 85.5252,
        'distance_km': 1.4,
        'items': [
          {'name': 'Chicken Dum Biryani', 'variant': 'Full', 'quantity': 2},
          {'name': 'Coke', 'quantity': 1},
        ],
      },
      'branch': {
        'id': 'b-1',
        'name': 'Bites Box Bakhtiyarpur',
        'phone': '+916122000000',
        'address': 'Main Road, Bakhtiyarpur',
        'latitude': 25.4608,
        'longitude': 85.5230,
      },
    };
  }

  group('DutyState', () {
    test('maps the database enum', () {
      expect(DutyState.fromCode('OFFLINE'), DutyState.offline);
      expect(DutyState.fromCode('AVAILABLE'), DutyState.available);
      expect(DutyState.fromCode('BUSY'), DutyState.busy);
      expect(DutyState.fromCode('ON_BREAK'), DutyState.onBreak);
    });

    // Defaulting to offline is the safe direction: a rider is never assumed
    // reachable because the app failed to understand the server.
    test('defaults to offline for anything unknown', () {
      expect(DutyState.fromCode(null), DutyState.offline);
      expect(DutyState.fromCode('SOMETHING_ELSE'), DutyState.offline);
    });

    test('counts available and busy as working', () {
      expect(DutyState.available.isWorking, isTrue);
      expect(DutyState.busy.isWorking, isTrue);
      expect(DutyState.offline.isWorking, isFalse);
      expect(DutyState.onBreak.isWorking, isFalse);
    });
  });

  group('RiderProfile', () {
    test('explains why a rider cannot go on duty', () {
      String? blocker(String status) =>
          RiderProfile.fromJson({'id': 'p1', 'full_name': 'Rahul', 'onboarding_status': status})
              .onboardingBlocker;

      expect(blocker('ACTIVE'), isNull);
      expect(blocker('PENDING'), contains('onboarding'));
      expect(blocker('DOCUMENTS_SUBMITTED'), contains('review'));
      expect(blocker('VERIFIED'), contains('activation'));
      expect(blocker('SUSPENDED'), contains('suspended'));
      expect(blocker('REJECTED'), isNotNull);
    });

    test('knows when the rider is at capacity', () {
      final full = RiderProfile.fromJson({
        'id': 'p1',
        'full_name': 'Rahul',
        'max_concurrent_orders': 2,
        'active_load': 2,
      });

      expect(full.atCapacity, isTrue);

      final spare = RiderProfile.fromJson({
        'id': 'p1',
        'full_name': 'Rahul',
        'max_concurrent_orders': 2,
        'active_load': 1,
      });

      expect(spare.atCapacity, isFalse);
    });

    test('parses money and counters as numbers, whatever their JSON type', () {
      final profile = RiderProfile.fromJson({
        'id': 'p1',
        'full_name': 'Rahul Kumar',
        'cash_in_hand': '450.50',
        'rating_average': '4.8',
        'total_deliveries': '132',
      });

      expect(profile.cashInHand, 450.5);
      expect(profile.ratingAverage, 4.8);
      expect(profile.totalDeliveries, 132);
      expect(profile.firstName, 'Rahul');
    });
  });

  group('DeliveryAssignment', () {
    test('reads the payload from my_deliveries', () {
      final assignment = DeliveryAssignment.fromJson(assignmentJson());

      expect(assignment.assignmentId, 'a-1');
      expect(assignment.order.orderNumber, 'BB-BKP01-260819-00005');
      expect(assignment.order.unitCount, 3);
      expect(assignment.order.items, hasLength(2));
      expect(assignment.order.items.first.label, 'Chicken Dum Biryani (Full)');
      expect(assignment.order.items.last.label, 'Coke');
      expect(assignment.branch.hasCoordinates, isTrue);
      expect(assignment.order.hasCoordinates, isTrue);
      expect(assignment.order.canCall, isTrue);
    });

    test('derives one next action per status', () {
      String action(String status) =>
          DeliveryAssignment.fromJson(assignmentJson(status: status)).nextActionLabel;

      expect(action('OFFERED'), 'Accept delivery');
      expect(action('ACCEPTED'), 'I have reached the restaurant');
      expect(action('AT_STORE'), 'Verify pickup code');
      expect(action('PICKED_UP'), 'I have reached the customer');
      expect(action('AT_CUSTOMER'), 'Complete delivery');
    });

    test('never leaves the rider without a label', () {
      final odd = DeliveryAssignment.fromJson(assignmentJson(status: 'SOMETHING_NEW'));
      expect(odd.nextActionLabel, isNotEmpty);
      expect(odd.statusLabel, isNotEmpty);
    });

    // Before pickup the rider drives to the kitchen; after it, to the customer.
    // Getting this backwards sends them to the wrong end of town.
    test('navigates to the outlet only until the food is collected', () {
      for (final status in ['OFFERED', 'ACCEPTED', 'AT_STORE']) {
        expect(
          DeliveryAssignment.fromJson(assignmentJson(status: status)).navigatesToBranch,
          isTrue,
          reason: status,
        );
      }

      for (final status in ['PICKED_UP', 'AT_CUSTOMER']) {
        expect(
          DeliveryAssignment.fromJson(assignmentJson(status: status)).navigatesToBranch,
          isFalse,
          reason: status,
        );
      }
    });

    test('knows when it is carrying food', () {
      expect(DeliveryAssignment.fromJson(assignmentJson(status: 'PICKED_UP')).isCarrying, isTrue);
      expect(DeliveryAssignment.fromJson(assignmentJson(status: 'AT_CUSTOMER')).isCarrying, isTrue);
      expect(DeliveryAssignment.fromJson(assignmentJson(status: 'ACCEPTED')).isCarrying, isFalse);
    });

    test('flags a cash order by the amount to collect, not the payment mode', () {
      expect(DeliveryAssignment.fromJson(assignmentJson(codAmount: 632)).order.isCod, isTrue);
      expect(DeliveryAssignment.fromJson(assignmentJson()).order.isCod, isFalse);
    });

    test('has no countdown without an expiry', () {
      expect(DeliveryAssignment.fromJson(assignmentJson()).offerTimeLeft, isNull);
    });

    // A clock that has already passed the expiry must read zero, not a negative
    // duration rendered as "-0:07".
    test('clamps an elapsed countdown to zero', () {
      final expired = DeliveryAssignment.fromJson(
        assignmentJson(status: 'OFFERED', expiresAt: '2020-01-01T00:00:00Z'),
      );

      expect(expired.offerTimeLeft, Duration.zero);
    });

    test('reports time remaining on a live offer', () {
      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 90));
      final live = DeliveryAssignment.fromJson(
        assignmentJson(status: 'OFFERED', expiresAt: expiry.toIso8601String()),
      );

      expect(live.offerTimeLeft, isNotNull);
      expect(live.offerTimeLeft!.inSeconds, greaterThan(60));
      expect(live.isOffer, isTrue);
    });
  });

  group('RiderDashboard', () {
    RiderDashboard dashboardWith(List<String> statuses) {
      return RiderDashboard.fromJson({
        'partner': {
          'id': 'p1',
          'full_name': 'Rahul Kumar',
          'onboarding_status': 'ACTIVE',
          'duty_state': 'BUSY',
          'max_concurrent_orders': 3,
          'active_load': statuses.length,
        },
        'active': [
          for (var i = 0; i < statuses.length; i++)
            {...assignmentJson(status: statuses[i]), 'assignment_id': 'a-$i'},
        ],
        'history': [],
      });
    }

    test('separates offers from work in progress', () {
      final dashboard = dashboardWith(['OFFERED', 'ACCEPTED', 'PICKED_UP']);

      expect(dashboard.offers, hasLength(1));
      expect(dashboard.inProgress, hasLength(2));
    });

    // With several live jobs the screen must open the one furthest along, which is
    // the one the rider is physically doing.
    test('picks the most advanced job as the current one', () {
      expect(dashboardWith(['ACCEPTED', 'AT_CUSTOMER']).current?.status, 'AT_CUSTOMER');
      expect(dashboardWith(['ACCEPTED', 'PICKED_UP']).current?.status, 'PICKED_UP');
      expect(dashboardWith(['ACCEPTED', 'AT_STORE']).current?.status, 'AT_STORE');
      expect(dashboardWith(['ACCEPTED']).current?.status, 'ACCEPTED');
    });

    // GPS is the rider's battery. It only runs while there is something to track,
    // and an unaccepted offer is not something to track.
    test('publishes location only while a job is live', () {
      expect(dashboardWith([]).shouldPublishLocation, isFalse);
      expect(dashboardWith(['OFFERED']).shouldPublishLocation, isFalse);
      expect(dashboardWith(['ACCEPTED']).shouldPublishLocation, isTrue);
    });

    test('survives an empty payload', () {
      final empty = RiderDashboard.fromJson({
        'partner': {'id': 'p1', 'full_name': 'Rahul'},
        'active': [],
        'history': [],
      });

      expect(empty.active, isEmpty);
      expect(empty.current, isNull);
      expect(empty.offers, isEmpty);
    });
  });

  group('RiderEarnings', () {
    test('reads the my_earnings payload', () {
      final earnings = RiderEarnings.fromJson({
        'today': 340,
        'this_week': 1820,
        'this_month': 7400,
        'lifetime': 68400,
        'cash_in_hand': 632,
        'unsettled_cash': 632,
        'deliveries_today': 7,
        'daily': [
          {'date': '2026-08-19', 'amount': 340, 'deliveries': 7},
          {'date': '2026-08-18', 'amount': 280, 'deliveries': 6},
        ],
        'entries': [
          {'id': 'e1', 'entry_type': 'DELIVERY_PAYOUT', 'amount': 45, 'earned_on': '2026-08-19'},
          {'id': 'e2', 'entry_type': 'PENALTY', 'amount': -150, 'earned_on': '2026-08-19'},
        ],
      });

      expect(earnings.today, 340);
      expect(earnings.unsettledCash, 632);
      expect(earnings.deliveriesToday, 7);
      expect(earnings.daily, hasLength(2));
      expect(earnings.entries, hasLength(2));
    });

    test('reads a penalty as a deduction', () {
      final entry = EarningsEntry.fromJson({
        'id': 'e2',
        'entry_type': 'PENALTY',
        'amount': -150,
      });

      expect(entry.isDeduction, isTrue);
      expect(entry.typeLabel, 'Penalty');
    });

    test('labels every entry type the ledger allows', () {
      for (final type in [
        'DELIVERY_PAYOUT',
        'TIP',
        'INCENTIVE',
        'PENALTY',
        'ADJUSTMENT',
        'DISTANCE_BONUS',
        'SURGE_BONUS',
        'CASH_SHORTFALL',
      ]) {
        final entry = EarningsEntry.fromJson({'id': 'e', 'entry_type': type, 'amount': 1});
        expect(entry.typeLabel.trim(), isNotEmpty, reason: type);
      }
    });

    test('defaults to zeroes rather than throwing on an empty payload', () {
      const empty = RiderEarnings();
      expect(empty.today, 0);
      expect(empty.lifetime, 0);
      expect(empty.entries, isEmpty);
    });
  });

  group('PickupResult', () {
    test('flattens the destination the server returns after pickup', () {
      final result = PickupResult.fromJson({
        'assignment_id': 'a-1',
        'order_id': 'o-1',
        'verified': true,
        'changed': true,
        'cod_amount': 632,
        'destination': {
          'latitude': 25.4632,
          'longitude': 85.5252,
          'address': '12 Station Road, Bakhtiyarpur',
          'contact_name': 'Diya Sharma',
          'contact_phone': '+919900000002',
          'instructions': 'Ring the bell twice',
        },
      });

      expect(result.verified, isTrue);
      expect(result.codAmount, 632);
      expect(result.destinationLatitude, 25.4632);
      expect(result.contactName, 'Diya Sharma');
      expect(result.instructions, 'Ring the bell twice');
    });

    test('copes with a payload carrying no destination', () {
      final result = PickupResult.fromJson({
        'assignment_id': 'a-1',
        'verified': true,
        'changed': false,
      });

      expect(result.verified, isTrue);
      expect(result.destinationLatitude, isNull);
      expect(result.codAmount, 0);
    });
  });

  group('DeliveryHistoryEntry', () {
    test('distinguishes a completed trip from a failed one', () {
      final done = DeliveryHistoryEntry.fromJson({
        'assignment_id': 'a-1',
        'status': 'COMPLETED',
        'order_number': 'BB-1',
        'total_payout': 45,
      });

      final failed = DeliveryHistoryEntry.fromJson({
        'assignment_id': 'a-2',
        'status': 'FAILED',
        'order_number': 'BB-2',
      });

      expect(done.succeeded, isTrue);
      expect(failed.succeeded, isFalse);
    });
  });

  onboardingTests();
}

/// Onboarding, mirroring `my_rider_onboarding()`.
///
/// The checklist is the rider's only route to being able to work, so the two
/// things worth pinning are: the order and required-flag of the steps (which comes
/// from the server, not from a hard-coded list), and that a rejected or expired
/// document is treated as needing action even when the server has not yet counted
/// it as missing.
void onboardingTests() {
  Map<String, dynamic> onboardingJson({
    String status = 'PENDING',
    List<Map<String, dynamic>> documents = const [],
    List<String> outstanding = const ['DRIVING_LICENCE', 'AADHAAR', 'PROFILE_PHOTO'],
  }) {
    return {
      'delivery_partner_id': 'dp-1',
      'onboarding_status': status,
      'partner_code': status == 'ACTIVE' ? 'BB-BKP01-001' : null,
      'required_documents': ['DRIVING_LICENCE', 'AADHAAR', 'PROFILE_PHOTO'],
      'documents': documents,
      'outstanding': outstanding,
    };
  }

  Map<String, dynamic> docJson({
    required String type,
    String status = 'PENDING',
    String? rejectionReason,
    String? expiresOn,
    bool isRequired = true,
  }) {
    return {
      'id': 'doc-$type',
      'document_type': type,
      'status': status,
      'is_required': isRequired,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      if (expiresOn != null) 'expires_on': expiresOn,
    };
  }

  group('RiderDocumentType', () {
    test('maps every code the database enum can return', () {
      const codes = [
        'DRIVING_LICENCE',
        'AADHAAR',
        'PAN',
        'VEHICLE_RC',
        'INSURANCE',
        'BANK_PASSBOOK',
        'PROFILE_PHOTO',
        'POLICE_VERIFICATION',
      ];

      for (final code in codes) {
        expect(
          RiderDocumentType.tryFromCode(code),
          isNotNull,
          reason: '$code has no Dart counterpart',
        );
      }
    });

    test('falls back to a readable label for an unknown code', () {
      // The enum can gain a value server-side before the app ships. A rider should
      // see "Voter Id", not a crash or a raw enum string.
      expect(RiderDocumentType.tryFromCode('VOTER_ID'), isNull);
      expect(RiderDocumentType.labelFor('VOTER_ID'), 'Voter Id');
    });

    test('only the profile photo uses the front camera', () {
      expect(RiderDocumentType.profilePhoto.isPortrait, isTrue);
      expect(RiderDocumentType.drivingLicence.isPortrait, isFalse);
      expect(RiderDocumentType.aadhaar.isPortrait, isFalse);
    });
  });

  group('RiderDocument', () {
    test('expiry overrides an approved status', () {
      final doc = RiderDocument.fromJson(
        docJson(
          type: 'DRIVING_LICENCE',
          status: 'APPROVED',
          expiresOn: '2020-01-01',
        ),
      );

      expect(doc.status, RiderDocumentStatus.approved);
      expect(doc.isExpired, isTrue);
      // A lapsed licence is not a valid one, whatever the review said last year.
      expect(doc.effectiveStatus, RiderDocumentStatus.expired);
      expect(doc.effectiveStatus.needsAction, isTrue);
    });

    test('a document with no expiry never expires', () {
      final doc = RiderDocument.fromJson(
        docJson(type: 'AADHAAR', status: 'APPROVED'),
      );

      expect(doc.isExpired, isFalse);
      expect(doc.effectiveStatus, RiderDocumentStatus.approved);
    });

    test('an unknown status is read as pending rather than throwing', () {
      final doc = RiderDocument.fromJson(
        docJson(type: 'PAN', status: 'SOMETHING_NEW'),
      );

      expect(doc.status, RiderDocumentStatus.pending);
    });
  });

  group('RiderOnboarding.steps', () {
    test('lists required documents in the order the server gave them', () {
      final onboarding = RiderOnboarding.fromJson(onboardingJson());

      expect(
        onboarding.steps.map((step) => step.documentType),
        ['DRIVING_LICENCE', 'AADHAAR', 'PROFILE_PHOTO'],
      );
      expect(onboarding.steps.every((step) => step.isRequired), isTrue);
      expect(onboarding.steps.every((step) => !step.isUploaded), isTrue);
    });

    test('appends an optional document the rider uploaded anyway', () {
      final onboarding = RiderOnboarding.fromJson(
        onboardingJson(
          documents: [docJson(type: 'PAN', isRequired: false)],
          outstanding: const ['DRIVING_LICENCE', 'AADHAAR', 'PROFILE_PHOTO'],
        ),
      );

      final last = onboarding.steps.last;
      expect(last.documentType, 'PAN');
      expect(last.isRequired, isFalse);
      expect(last.statusLabel, 'Under review');
    });

    test('a rejected required document still needs action', () {
      final onboarding = RiderOnboarding.fromJson(
        onboardingJson(
          status: 'DOCUMENTS_SUBMITTED',
          documents: [
            docJson(
              type: 'DRIVING_LICENCE',
              status: 'REJECTED',
              rejectionReason: 'Too blurred to read the number.',
            ),
            docJson(type: 'AADHAAR', status: 'APPROVED'),
            docJson(type: 'PROFILE_PHOTO', status: 'APPROVED'),
          ],
          outstanding: const ['DRIVING_LICENCE'],
        ),
      );

      expect(onboarding.actionableSteps.length, 1);
      expect(onboarding.actionableSteps.single.documentType, 'DRIVING_LICENCE');
      expect(onboarding.everythingSubmitted, isFalse);
      expect(onboarding.approvedRequiredCount, 2);
      expect(onboarding.requiredCount, 3);
    });

    test('nothing is actionable once everything required is submitted', () {
      final onboarding = RiderOnboarding.fromJson(
        onboardingJson(
          status: 'DOCUMENTS_SUBMITTED',
          documents: [
            docJson(type: 'DRIVING_LICENCE'),
            docJson(type: 'AADHAAR'),
            docJson(type: 'PROFILE_PHOTO'),
          ],
          outstanding: const [],
        ),
      );

      expect(onboarding.actionableSteps, isEmpty);
      expect(onboarding.everythingSubmitted, isTrue);
      // Submitted is not approved: the progress count must not run ahead of the
      // reviewer.
      expect(onboarding.approvedRequiredCount, 0);
    });
  });

  group('RiderOnboarding.headline', () {
    test('tells a new rider how many documents to upload', () {
      final onboarding = RiderOnboarding.fromJson(onboardingJson());
      expect(onboarding.headline, contains('3'));
    });

    test('explains each terminal state without jargon', () {
      for (final (status, fragment) in const [
        ('ACTIVE', 'ready to ride'),
        ('VERIFIED', 'activate'),
        ('DOCUMENTS_SUBMITTED', 'review'),
        ('SUSPENDED', 'on hold'),
        ('REJECTED', 'not approved'),
      ]) {
        final onboarding = RiderOnboarding.fromJson(onboardingJson(status: status));
        expect(
          onboarding.headline.toLowerCase(),
          contains(fragment),
          reason: 'headline for $status',
        );
      }
    });
  });

  group('RiderOnboarding state flags', () {
    test('classifies each onboarding status exactly once', () {
      final active = RiderOnboarding.fromJson(onboardingJson(status: 'ACTIVE'));
      expect([active.isActive, active.isUnderReview, active.isVerified, active.isBlocked],
          [true, false, false, false]);

      final review =
          RiderOnboarding.fromJson(onboardingJson(status: 'DOCUMENTS_SUBMITTED'));
      expect([review.isActive, review.isUnderReview, review.isVerified, review.isBlocked],
          [false, true, false, false]);

      final verified = RiderOnboarding.fromJson(onboardingJson(status: 'VERIFIED'));
      expect(
          [verified.isActive, verified.isUnderReview, verified.isVerified, verified.isBlocked],
          [false, false, true, false]);

      for (final status in const ['SUSPENDED', 'REJECTED']) {
        final blocked = RiderOnboarding.fromJson(onboardingJson(status: status));
        expect(blocked.isBlocked, isTrue, reason: status);
        expect(blocked.isActive, isFalse, reason: status);
      }
    });

    test('the partner code only appears once the rider is active', () {
      expect(RiderOnboarding.fromJson(onboardingJson()).partnerCode, isNull);
      expect(
        RiderOnboarding.fromJson(onboardingJson(status: 'ACTIVE')).partnerCode,
        'BB-BKP01-001',
      );
    });
  });
}
