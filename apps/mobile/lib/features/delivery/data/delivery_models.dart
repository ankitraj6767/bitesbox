import '../../../shared/json.dart';

/// Rider models, mirroring `public.my_deliveries()` and `public.my_earnings()`.

/// Duty state, as the database enum `rider_duty_state`.
enum DutyState {
  offline('OFFLINE', 'Offline'),
  available('AVAILABLE', 'On duty'),
  busy('BUSY', 'Delivering'),
  onBreak('ON_BREAK', 'On break');

  const DutyState(this.code, this.label);

  final String code;
  final String label;

  static DutyState fromCode(String? code) => DutyState.values.firstWhere(
        (state) => state.code == code,
        orElse: () => DutyState.offline,
      );

  /// The rider is reachable by dispatch.
  bool get isWorking => this == available || this == busy;
}

class RiderProfile {
  const RiderProfile({
    required this.id,
    required this.fullName,
    this.photoPath,
    this.phone,
    this.vehicleType,
    this.vehicleNumber,
    this.onboardingStatus = 'PENDING',
    this.dutyState = DutyState.offline,
    this.ratingAverage = 0,
    this.totalDeliveries = 0,
    this.cashInHand = 0,
    this.maxConcurrentOrders = 1,
    this.activeLoad = 0,
  });

  final String id;
  final String fullName;
  final String? photoPath;
  final String? phone;
  final String? vehicleType;
  final String? vehicleNumber;
  final String onboardingStatus;
  final DutyState dutyState;
  final double ratingAverage;
  final int totalDeliveries;
  final double cashInHand;
  final int maxConcurrentOrders;
  final int activeLoad;

  bool get isActive => onboardingStatus == 'ACTIVE';
  bool get atCapacity => activeLoad >= maxConcurrentOrders;

  /// Why the rider cannot go on duty yet, if anything.
  String? get onboardingBlocker => switch (onboardingStatus) {
        'ACTIVE' => null,
        'PENDING' => 'Complete your onboarding to start accepting deliveries.',
        'DOCUMENTS_SUBMITTED' => 'Your documents are under review.',
        'VERIFIED' => 'Your account is verified and awaiting activation.',
        'SUSPENDED' => 'Your account is suspended. Please contact your manager.',
        'REJECTED' => 'Your application was not approved.',
        _ => 'Your account is not active.',
      };

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? 'there' : parts.first;
  }

  factory RiderProfile.fromJson(Map<String, dynamic> json) => RiderProfile(
        id: asString(json['id']),
        fullName: asString(json['full_name']),
        photoPath: asStringOrNull(json['photo_path']),
        phone: asStringOrNull(json['phone']),
        vehicleType: asStringOrNull(json['vehicle_type']),
        vehicleNumber: asStringOrNull(json['vehicle_number']),
        onboardingStatus: asString(json['onboarding_status'], 'PENDING'),
        dutyState: DutyState.fromCode(asStringOrNull(json['duty_state'])),
        ratingAverage: asDouble(json['rating_average']),
        totalDeliveries: asInt(json['total_deliveries']),
        cashInHand: asDouble(json['cash_in_hand']),
        maxConcurrentOrders: asInt(json['max_concurrent_orders'], 1),
        activeLoad: asInt(json['active_load']),
      );
}

class AssignmentItem {
  const AssignmentItem({required this.name, required this.quantity, this.variant});

  final String name;
  final int quantity;
  final String? variant;

  String get label => variant == null ? name : '$name ($variant)';

  factory AssignmentItem.fromJson(Map<String, dynamic> json) => AssignmentItem(
        name: asString(json['name']),
        quantity: asInt(json['quantity'], 1),
        variant: asStringOrNull(json['variant']),
      );
}

class AssignmentOrder {
  const AssignmentOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.address,
    this.itemCount = 0,
    this.unitCount = 0,
    this.paymentMode = 'ONLINE',
    this.codAmount = 0,
    this.grandTotal = 0,
    this.customerName,
    this.customerPhone,
    this.latitude,
    this.longitude,
    this.instructions,
    this.distanceKm,
    this.promisedAt,
    this.placedAt,
    this.readyAt,
    this.items = const [],
  });

  final String id;
  final String orderNumber;
  final String status;
  final String address;
  final int itemCount;
  final int unitCount;
  final String paymentMode;

  /// Exactly what must be collected in cash. Server-computed; the rider app never
  /// derives it from the total.
  final double codAmount;
  final double grandTotal;
  final String? customerName;
  final String? customerPhone;
  final double? latitude;
  final double? longitude;
  final String? instructions;
  final double? distanceKm;
  final DateTime? promisedAt;
  final DateTime? placedAt;
  final DateTime? readyAt;
  final List<AssignmentItem> items;

  bool get isCod => codAmount > 0;
  bool get hasCoordinates => latitude != null && longitude != null;
  bool get canCall => (customerPhone ?? '').isNotEmpty;

  factory AssignmentOrder.fromJson(Map<String, dynamic> json) => AssignmentOrder(
        id: asString(json['id']),
        orderNumber: asString(json['order_number']),
        status: asString(json['status']),
        address: asString(json['address']),
        itemCount: asInt(json['item_count']),
        unitCount: asInt(json['unit_count']),
        paymentMode: asString(json['payment_mode'], 'ONLINE'),
        codAmount: asDouble(json['cod_amount']),
        grandTotal: asDouble(json['grand_total']),
        customerName: asStringOrNull(json['customer_name']),
        customerPhone: asStringOrNull(json['customer_phone']),
        latitude: asDoubleOrNull(json['latitude']),
        longitude: asDoubleOrNull(json['longitude']),
        instructions: asStringOrNull(json['instructions']),
        distanceKm: asDoubleOrNull(json['distance_km']),
        promisedAt: asDate(json['promised_at']),
        placedAt: asDate(json['placed_at']),
        readyAt: asDate(json['ready_at']),
        items: asList(json['items'], AssignmentItem.fromJson),
      );
}

class PickupBranch {
  const PickupBranch({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String? phone;
  final String? address;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory PickupBranch.fromJson(Map<String, dynamic> json) => PickupBranch(
        id: asString(json['id']),
        name: asString(json['name'], 'Bites Box'),
        phone: asStringOrNull(json['phone']),
        address: asStringOrNull(json['address']),
        latitude: asDoubleOrNull(json['latitude']),
        longitude: asDoubleOrNull(json['longitude']),
      );
}

/// One live job for the rider.
class DeliveryAssignment {
  const DeliveryAssignment({
    required this.assignmentId,
    required this.status,
    required this.order,
    required this.branch,
    this.offeredAt,
    this.expiresAt,
    this.acceptedAt,
    this.arrivedStoreAt,
    this.pickedUpAt,
    this.totalPayout = 0,
  });

  final String assignmentId;
  final String status;
  final AssignmentOrder order;
  final PickupBranch branch;
  final DateTime? offeredAt;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedStoreAt;
  final DateTime? pickedUpAt;
  final double totalPayout;

  bool get isOffer => status == 'OFFERED';
  bool get isHeadedToStore => status == 'ACCEPTED';
  bool get isAtStore => status == 'AT_STORE';
  bool get isCarrying => status == 'PICKED_UP' || status == 'AT_CUSTOMER';
  bool get isAtCustomer => status == 'AT_CUSTOMER';

  /// Before pickup the rider navigates to the kitchen; after, to the customer.
  bool get navigatesToBranch => isOffer || isHeadedToStore || isAtStore;

  Duration? get offerTimeLeft {
    final expiry = expiresAt;
    if (expiry == null) return null;
    final left = expiry.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// The single next action, so the rider screen only ever shows one big button.
  String get nextActionLabel => switch (status) {
        'OFFERED' => 'Accept delivery',
        'ACCEPTED' => 'I have reached the restaurant',
        'AT_STORE' => 'Verify pickup code',
        'PICKED_UP' => 'I have reached the customer',
        'AT_CUSTOMER' => 'Complete delivery',
        _ => 'Continue',
      };

  String get statusLabel => switch (status) {
        'OFFERED' => 'New offer',
        'ACCEPTED' => 'Head to restaurant',
        'AT_STORE' => 'At restaurant',
        'PICKED_UP' => 'Delivering',
        'AT_CUSTOMER' => 'At customer',
        _ => status,
      };

  factory DeliveryAssignment.fromJson(Map<String, dynamic> json) => DeliveryAssignment(
        assignmentId: asString(json['assignment_id']),
        status: asString(json['status']),
        order: AssignmentOrder.fromJson(asMap(json['order'])),
        branch: PickupBranch.fromJson(asMap(json['branch'])),
        offeredAt: asDate(json['offered_at']),
        expiresAt: asDate(json['expires_at']),
        acceptedAt: asDate(json['accepted_at']),
        arrivedStoreAt: asDate(json['arrived_store_at']),
        pickedUpAt: asDate(json['picked_up_at']),
        totalPayout: asDouble(json['total_payout']),
      );
}

class DeliveryHistoryEntry {
  const DeliveryHistoryEntry({
    required this.assignmentId,
    required this.status,
    required this.orderNumber,
    this.completedAt,
    this.totalPayout = 0,
    this.cashCollected = 0,
    this.distanceKm,
    this.area,
  });

  final String assignmentId;
  final String status;
  final String orderNumber;
  final DateTime? completedAt;
  final double totalPayout;
  final double cashCollected;
  final double? distanceKm;
  final String? area;

  bool get succeeded => status == 'COMPLETED';

  factory DeliveryHistoryEntry.fromJson(Map<String, dynamic> json) => DeliveryHistoryEntry(
        assignmentId: asString(json['assignment_id']),
        status: asString(json['status']),
        orderNumber: asString(json['order_number']),
        completedAt: asDate(json['completed_at']),
        totalPayout: asDouble(json['total_payout']),
        cashCollected: asDouble(json['cash_collected']),
        distanceKm: asDoubleOrNull(json['distance_km']),
        area: asStringOrNull(json['area']),
      );
}

/// The rider home payload: who they are, what is live, what is done.
class RiderDashboard {
  const RiderDashboard({
    required this.profile,
    required this.active,
    this.history = const [],
  });

  final RiderProfile profile;
  final List<DeliveryAssignment> active;
  final List<DeliveryHistoryEntry> history;

  List<DeliveryAssignment> get offers =>
      active.where((assignment) => assignment.isOffer).toList();

  List<DeliveryAssignment> get inProgress =>
      active.where((assignment) => !assignment.isOffer).toList();

  /// The job the rider is actually working on, if any.
  DeliveryAssignment? get current {
    for (final status in const ['AT_CUSTOMER', 'PICKED_UP', 'AT_STORE', 'ACCEPTED']) {
      for (final assignment in active) {
        if (assignment.status == status) return assignment;
      }
    }
    return null;
  }

  /// GPS publishing only makes sense while a job is live.
  bool get shouldPublishLocation => current != null;

  factory RiderDashboard.fromJson(Map<String, dynamic> json) => RiderDashboard(
        profile: RiderProfile.fromJson(asMap(json['partner'])),
        active: asList(json['active'], DeliveryAssignment.fromJson),
        history: asList(json['history'], DeliveryHistoryEntry.fromJson),
      );
}

class EarningsEntry {
  const EarningsEntry({
    required this.id,
    required this.entryType,
    required this.amount,
    this.description,
    this.earnedOn,
    this.createdAt,
  });

  final String id;
  final String entryType;
  final double amount;
  final String? description;
  final DateTime? earnedOn;
  final DateTime? createdAt;

  String get typeLabel => switch (entryType) {
        'DELIVERY_PAYOUT' => 'Delivery',
        'TIP' => 'Tip',
        'INCENTIVE' => 'Incentive',
        'BONUS' => 'Bonus',
        'PENALTY' => 'Penalty',
        'ADJUSTMENT' => 'Adjustment',
        _ => entryType,
      };

  bool get isDeduction => amount < 0;

  factory EarningsEntry.fromJson(Map<String, dynamic> json) => EarningsEntry(
        id: asString(json['id']),
        entryType: asString(json['entry_type']),
        amount: asDouble(json['amount']),
        description: asStringOrNull(json['description']),
        earnedOn: asDate(json['earned_on']),
        createdAt: asDate(json['created_at']),
      );
}

class EarningsDay {
  const EarningsDay({required this.date, required this.amount, this.deliveries = 0});

  final DateTime? date;
  final double amount;
  final int deliveries;

  factory EarningsDay.fromJson(Map<String, dynamic> json) => EarningsDay(
        date: asDate(json['date']),
        amount: asDouble(json['amount']),
        deliveries: asInt(json['deliveries']),
      );
}

class RiderEarnings {
  const RiderEarnings({
    this.today = 0,
    this.thisWeek = 0,
    this.thisMonth = 0,
    this.lifetime = 0,
    this.cashInHand = 0,
    this.unsettledCash = 0,
    this.deliveriesToday = 0,
    this.daily = const [],
    this.entries = const [],
  });

  final double today;
  final double thisWeek;
  final double thisMonth;
  final double lifetime;
  final double cashInHand;

  /// Cash collected but not yet handed to the branch.
  final double unsettledCash;
  final int deliveriesToday;
  final List<EarningsDay> daily;
  final List<EarningsEntry> entries;

  factory RiderEarnings.fromJson(Map<String, dynamic> json) => RiderEarnings(
        today: asDouble(json['today']),
        thisWeek: asDouble(json['this_week']),
        thisMonth: asDouble(json['this_month']),
        lifetime: asDouble(json['lifetime']),
        cashInHand: asDouble(json['cash_in_hand']),
        unsettledCash: asDouble(json['unsettled_cash']),
        deliveriesToday: asInt(json['deliveries_today']),
        daily: asList(json['daily'], EarningsDay.fromJson),
        entries: asList(json['entries'], EarningsEntry.fromJson),
      );
}

/// Where to go and how much to collect, returned by `verify_pickup`.
class PickupResult {
  const PickupResult({
    required this.assignmentId,
    required this.verified,
    this.orderId,
    this.codAmount = 0,
    this.destinationAddress,
    this.destinationLatitude,
    this.destinationLongitude,
    this.contactName,
    this.contactPhone,
    this.instructions,
  });

  final String assignmentId;
  final bool verified;
  final String? orderId;
  final double codAmount;
  final String? destinationAddress;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? contactName;
  final String? contactPhone;
  final String? instructions;

  factory PickupResult.fromJson(Map<String, dynamic> json) {
    final destination = asMap(json['destination']);
    return PickupResult(
      assignmentId: asString(json['assignment_id']),
      verified: asBool(json['verified']),
      orderId: asStringOrNull(json['order_id']),
      codAmount: asDouble(json['cod_amount']),
      destinationAddress: asStringOrNull(destination['address']),
      destinationLatitude: asDoubleOrNull(destination['latitude']),
      destinationLongitude: asDoubleOrNull(destination['longitude']),
      contactName: asStringOrNull(destination['contact_name']),
      contactPhone: asStringOrNull(destination['contact_phone']),
      instructions: asStringOrNull(destination['instructions']),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ONBOARDING
//
// Mirrors `public.my_rider_onboarding()`. The required-document list comes from
// the server (`settings['rider.required_documents']`) rather than being hard-coded
// here, because a bicycle rider has no vehicle RC and what an outlet demands
// changes with local rules.
// ═══════════════════════════════════════════════════════════════════════════

/// One onboarding document type, as the database enum `rider_document_type`.
enum RiderDocumentType {
  drivingLicence('DRIVING_LICENCE', 'Driving licence', 'Front side, number readable'),
  aadhaar('AADHAAR', 'Aadhaar card', 'Any side showing your name'),
  pan('PAN', 'PAN card', 'For tax records'),
  vehicleRc('VEHICLE_RC', 'Vehicle RC', 'Registration certificate'),
  insurance('INSURANCE', 'Vehicle insurance', 'Must be currently valid'),
  bankPassbook('BANK_PASSBOOK', 'Bank passbook', 'First page with account details'),
  profilePhoto('PROFILE_PHOTO', 'Profile photo', 'A clear photo of your face'),
  policeVerification('POLICE_VERIFICATION', 'Police verification', 'If your outlet asks for it');

  const RiderDocumentType(this.code, this.label, this.hint);

  final String code;
  final String label;
  final String hint;

  /// Unknown codes fall back to a readable label rather than crashing: the enum
  /// can gain a value server-side before the app is updated.
  static RiderDocumentType? tryFromCode(String? code) {
    for (final type in RiderDocumentType.values) {
      if (type.code == code) return type;
    }
    return null;
  }

  static String labelFor(String code) => tryFromCode(code)?.label ?? humaniseCode(code);

  static String humaniseCode(String code) => code
      .split('_')
      .map((word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join(' ');

  /// A face photo should be a selfie; everything else is a document held up to
  /// the rear camera.
  bool get isPortrait => this == profilePhoto;
}

/// Review state, as the database enum `document_status`.
enum RiderDocumentStatus {
  pending('PENDING', 'Under review'),
  approved('APPROVED', 'Approved'),
  rejected('REJECTED', 'Needs re-upload'),
  expired('EXPIRED', 'Expired');

  const RiderDocumentStatus(this.code, this.label);

  final String code;
  final String label;

  static RiderDocumentStatus fromCode(String? code) =>
      RiderDocumentStatus.values.firstWhere(
        (status) => status.code == code,
        orElse: () => RiderDocumentStatus.pending,
      );

  /// The rider needs to do something about it.
  bool get needsAction => this == rejected || this == expired;
}

class RiderDocument {
  const RiderDocument({
    required this.id,
    required this.documentType,
    required this.status,
    this.documentNumber,
    this.issuedOn,
    this.expiresOn,
    this.rejectionReason,
    this.reviewedAt,
    this.isRequired = false,
  });

  final String id;
  final String documentType;
  final RiderDocumentStatus status;
  final String? documentNumber;
  final DateTime? issuedOn;
  final DateTime? expiresOn;
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final bool isRequired;

  String get label => RiderDocumentType.labelFor(documentType);

  RiderDocumentType? get type => RiderDocumentType.tryFromCode(documentType);

  bool get isExpired {
    final expiry = expiresOn;
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now());
  }

  /// Expiry is a fact about the document, not a review decision, so it wins over
  /// a stale APPROVED.
  RiderDocumentStatus get effectiveStatus =>
      isExpired ? RiderDocumentStatus.expired : status;

  factory RiderDocument.fromJson(Map<String, dynamic> json) => RiderDocument(
        id: asString(json['id']),
        documentType: asString(json['document_type']),
        status: RiderDocumentStatus.fromCode(asStringOrNull(json['status'])),
        documentNumber: asStringOrNull(json['document_number']),
        issuedOn: asDate(json['issued_on']),
        expiresOn: asDate(json['expires_on']),
        rejectionReason: asStringOrNull(json['rejection_reason']),
        reviewedAt: asDate(json['reviewed_at']),
        isRequired: asBool(json['is_required']),
      );
}

/// One row in the rider's checklist: a required or submitted document type, and
/// whatever has been uploaded against it.
class OnboardingStep {
  const OnboardingStep({
    required this.documentType,
    required this.isRequired,
    this.document,
  });

  final String documentType;
  final bool isRequired;
  final RiderDocument? document;

  String get label => RiderDocumentType.labelFor(documentType);
  RiderDocumentType? get type => RiderDocumentType.tryFromCode(documentType);

  bool get isUploaded => document != null;
  bool get isApproved =>
      document?.effectiveStatus == RiderDocumentStatus.approved;
  bool get needsAction =>
      document == null || document!.effectiveStatus.needsAction;

  String get statusLabel =>
      document?.effectiveStatus.label ?? (isRequired ? 'Not uploaded' : 'Optional');
}

class RiderOnboarding {
  const RiderOnboarding({
    required this.deliveryPartnerId,
    required this.onboardingStatus,
    this.partnerCode,
    this.rejectionReason,
    this.suspendedReason,
    this.suspendedUntil,
    this.requiredDocuments = const [],
    this.documents = const [],
    this.outstanding = const [],
  });

  final String deliveryPartnerId;
  final String onboardingStatus;
  final String? partnerCode;
  final String? rejectionReason;
  final String? suspendedReason;
  final DateTime? suspendedUntil;
  final List<String> requiredDocuments;
  final List<RiderDocument> documents;

  /// Required types with nothing usable on file. Server-computed.
  final List<String> outstanding;

  bool get isActive => onboardingStatus == 'ACTIVE';
  bool get isUnderReview => onboardingStatus == 'DOCUMENTS_SUBMITTED';
  bool get isVerified => onboardingStatus == 'VERIFIED';
  bool get isBlocked =>
      onboardingStatus == 'SUSPENDED' || onboardingStatus == 'REJECTED';

  /// Anything the rider must still do. Outstanding is the server's answer; a
  /// rejected document is added because it needs re-uploading even though the
  /// server does not count it as missing until it is replaced.
  List<OnboardingStep> get steps {
    final byType = {for (final doc in documents) doc.documentType: doc};

    // Required first, in the server's order, then anything extra they uploaded.
    final ordered = <String>[
      ...requiredDocuments,
      ...documents
          .map((doc) => doc.documentType)
          .where((type) => !requiredDocuments.contains(type)),
    ];

    return [
      for (final type in ordered)
        OnboardingStep(
          documentType: type,
          isRequired: requiredDocuments.contains(type),
          document: byType[type],
        ),
    ];
  }

  List<OnboardingStep> get actionableSteps =>
      steps.where((step) => step.isRequired && step.needsAction).toList();

  int get approvedRequiredCount =>
      steps.where((step) => step.isRequired && step.isApproved).length;

  int get requiredCount => requiredDocuments.length;

  /// Everything required is uploaded and awaiting or past review.
  bool get everythingSubmitted => actionableSteps.isEmpty;

  /// A single sentence explaining where they are, for the top of the screen.
  String get headline => switch (onboardingStatus) {
        'ACTIVE' => 'You are approved and ready to ride.',
        'VERIFIED' => 'Your documents are approved. A manager will activate you shortly.',
        'DOCUMENTS_SUBMITTED' => 'Your documents are with the team for review.',
        'SUSPENDED' => 'Your account is on hold.',
        'REJECTED' => 'Your application was not approved.',
        _ => actionableSteps.isEmpty
            ? 'Almost there — submit your documents to finish.'
            : 'Upload ${actionableSteps.length} document(s) to get started.',
      };

  factory RiderOnboarding.fromJson(Map<String, dynamic> json) => RiderOnboarding(
        deliveryPartnerId: asString(json['delivery_partner_id']),
        onboardingStatus: asString(json['onboarding_status'], 'PENDING'),
        partnerCode: asStringOrNull(json['partner_code']),
        rejectionReason: asStringOrNull(json['rejection_reason']),
        suspendedReason: asStringOrNull(json['suspended_reason']),
        suspendedUntil: asDate(json['suspended_until']),
        requiredDocuments: asStringList(json['required_documents']),
        documents: asList(json['documents'], RiderDocument.fromJson),
        outstanding: asStringList(json['outstanding']),
      );
}
