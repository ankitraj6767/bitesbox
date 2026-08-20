import '../../../shared/json.dart';

/// Cart and checkout models.
///
/// Every field here is *read*. The app never computes a price, a discount, a tax
/// or a total — `app.calculate_checkout()` is the single money authority and this
/// is its wire format. If a number is missing from the payload, the screen shows
/// nothing rather than inventing a value.

/// A modifier as priced by the server, including free-selection handling.
class CheckoutLineModifier {
  const CheckoutLineModifier({
    required this.modifierId,
    required this.groupName,
    required this.modifierName,
    required this.unitPrice,
    required this.quantity,
    required this.totalPrice,
    this.listPrice = 0,
    this.isFree = false,
    this.isAvailable = true,
  });

  final String modifierId;
  final String groupName;
  final String modifierName;
  final double unitPrice;
  final int quantity;
  final double totalPrice;
  final double listPrice;

  /// Included by a "first 2 free" group rule.
  final bool isFree;
  final bool isAvailable;

  String get label => quantity > 1 ? '$modifierName ×$quantity' : modifierName;

  factory CheckoutLineModifier.fromJson(Map<String, dynamic> json) => CheckoutLineModifier(
        modifierId: asString(json['modifier_id']),
        groupName: asString(json['group_name']),
        modifierName: asString(json['modifier_name']),
        unitPrice: asDouble(json['unit_price']),
        quantity: asInt(json['quantity'], 1),
        totalPrice: asDouble(json['total_price']),
        listPrice: asDouble(json['list_price']),
        isFree: asBool(json['is_free']),
        isAvailable: asBool(json['is_available'], fallback: true),
      );
}

/// One priced cart line.
class CheckoutLine {
  const CheckoutLine({
    required this.cartItemId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.grossAmount,
    required this.netAmount,
    this.variantId,
    this.variantName,
    this.variantOptionGroup,
    this.categoryId,
    this.categoryName,
    this.foodType = 'VEG',
    this.imagePath,
    this.comparePrice,
    this.modifiersPrice = 0,
    this.allocatedDiscount = 0,
    this.taxAmount = 0,
    this.specialInstructions,
    this.modifiers = const [],
    this.isAvailable = true,
  });

  final String cartItemId;
  final String productId;
  final String productName;
  final int quantity;

  /// Price of one unit before modifiers, as the server priced it.
  final double unitPrice;

  /// (unit + modifiers) × quantity, before any discount.
  final double grossAmount;

  /// Gross minus this line's proportional share of every discount.
  final double netAmount;

  final String? variantId;
  final String? variantName;
  final String? variantOptionGroup;
  final String? categoryId;
  final String? categoryName;
  final String foodType;
  final String? imagePath;
  final double? comparePrice;
  final double modifiersPrice;
  final double allocatedDiscount;
  final double taxAmount;
  final String? specialInstructions;
  final List<CheckoutLineModifier> modifiers;
  final bool isAvailable;

  bool get isVeg => foodType == 'VEG' || foodType == 'VEGAN';

  /// "Full Plate · Extra Raita, Papad"
  String get configurationLabel {
    final parts = <String>[
      if (variantName != null && variantName!.isNotEmpty) variantName!,
      ...modifiers.map((modifier) => modifier.label),
    ];
    return parts.join(' · ');
  }

  factory CheckoutLine.fromJson(Map<String, dynamic> json) => CheckoutLine(
        cartItemId: asString(json['cart_item_id']),
        productId: asString(json['product_id']),
        productName: asString(json['product_name']),
        quantity: asInt(json['quantity'], 1),
        unitPrice: asDouble(json['unit_price']),
        grossAmount: asDouble(json['gross_amount']),
        netAmount: asDouble(json['net_amount']),
        variantId: asStringOrNull(json['variant_id']),
        variantName: asStringOrNull(json['variant_name']),
        variantOptionGroup: asStringOrNull(json['variant_option_group']),
        categoryId: asStringOrNull(json['category_id']),
        categoryName: asStringOrNull(json['category_name']),
        foodType: asString(json['food_type'], 'VEG'),
        imagePath: asStringOrNull(json['image_path']),
        comparePrice: asDoubleOrNull(json['compare_price']),
        modifiersPrice: asDouble(json['modifiers_price']),
        allocatedDiscount: asDouble(json['allocated_discount']),
        taxAmount: asDouble(json['tax_amount']),
        specialInstructions: asStringOrNull(json['special_instructions']),
        modifiers: asList(json['modifiers'], CheckoutLineModifier.fromJson),
        isAvailable: asBool(json['is_available'], fallback: true),
      );
}

/// The bill. Presented in this order on the checkout screen.
class CheckoutTotals {
  const CheckoutTotals({
    this.itemsSubtotal = 0,
    this.itemsDiscount = 0,
    this.couponDiscount = 0,
    this.promotionDiscount = 0,
    this.totalDiscount = 0,
    this.taxableAmount = 0,
    this.taxAmount = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.cessAmount = 0,
    this.packagingCharge = 0,
    this.deliveryFee = 0,
    this.deliveryFeeWaived = 0,
    this.serviceFee = 0,
    this.tipAmount = 0,
    this.loyaltyPointsRedeemed = 0,
    this.loyaltyDiscount = 0,
    this.roundOff = 0,
    this.grandTotal = 0,
    this.walletApplied = 0,
    this.walletBalance = 0,
    this.payableAmount = 0,
    this.totalSavings = 0,
  });

  final double itemsSubtotal;
  final double itemsDiscount;
  final double couponDiscount;
  final double promotionDiscount;
  final double totalDiscount;
  final double taxableAmount;
  final double taxAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double cessAmount;
  final double packagingCharge;
  final double deliveryFee;

  /// The fee that *would* have applied, when it was waived. Shown struck through.
  final double deliveryFeeWaived;
  final double serviceFee;
  final double tipAmount;
  final int loyaltyPointsRedeemed;
  final double loyaltyDiscount;
  final double roundOff;
  final double grandTotal;
  final double walletApplied;
  final double walletBalance;

  /// What the customer pays now: grand total minus wallet.
  final double payableAmount;
  final double totalSavings;

  bool get hasDeliveryWaiver => deliveryFeeWaived > 0;
  bool get hasSavings => totalSavings > 0;

  factory CheckoutTotals.fromJson(Map<String, dynamic> json) => CheckoutTotals(
        itemsSubtotal: asDouble(json['items_subtotal']),
        itemsDiscount: asDouble(json['items_discount']),
        couponDiscount: asDouble(json['coupon_discount']),
        promotionDiscount: asDouble(json['promotion_discount']),
        totalDiscount: asDouble(json['total_discount']),
        taxableAmount: asDouble(json['taxable_amount']),
        taxAmount: asDouble(json['tax_amount']),
        cgstAmount: asDouble(json['cgst_amount']),
        sgstAmount: asDouble(json['sgst_amount']),
        igstAmount: asDouble(json['igst_amount']),
        cessAmount: asDouble(json['cess_amount']),
        packagingCharge: asDouble(json['packaging_charge']),
        deliveryFee: asDouble(json['delivery_fee']),
        deliveryFeeWaived: asDouble(json['delivery_fee_waived']),
        serviceFee: asDouble(json['service_fee']),
        tipAmount: asDouble(json['tip_amount']),
        loyaltyPointsRedeemed: asInt(json['loyalty_points_redeemed']),
        loyaltyDiscount: asDouble(json['loyalty_discount']),
        roundOff: asDouble(json['round_off']),
        grandTotal: asDouble(json['grand_total']),
        walletApplied: asDouble(json['wallet_applied']),
        walletBalance: asDouble(json['wallet_balance']),
        payableAmount: asDouble(json['payable_amount']),
        totalSavings: asDouble(json['total_savings']),
      );
}

/// A reason the cart cannot be ordered (BLOCKING) or something the customer
/// should know (WARNING).
class CheckoutIssue {
  const CheckoutIssue({
    required this.code,
    required this.severity,
    required this.message,
    this.cartItemId,
    this.productId,
    this.limit,
  });

  final String code;
  final String severity;
  final String message;
  final String? cartItemId;
  final String? productId;
  final double? limit;

  bool get isBlocking => severity == 'BLOCKING';

  factory CheckoutIssue.fromJson(Map<String, dynamic> json) => CheckoutIssue(
        code: asString(json['code'], 'CHECKOUT_INVALID'),
        severity: asString(json['severity'], 'WARNING'),
        message: asString(json['message']),
        cartItemId: asStringOrNull(json['cart_item_id']),
        productId: asStringOrNull(json['product_id']),
        limit: asDoubleOrNull(json['limit']),
      );
}

/// The applied (or rejected) coupon, as evaluated server-side.
class CouponEvaluation {
  const CouponEvaluation({
    required this.valid,
    this.couponId,
    this.code,
    this.title,
    this.discountKind,
    this.discountAmount = 0,
    this.freeDelivery = false,
    this.reasonCode,
    this.message,
    this.shortfall,
    this.minOrderAmount,
  });

  final bool valid;
  final String? couponId;
  final String? code;
  final String? title;
  final String? discountKind;
  final double discountAmount;
  final bool freeDelivery;
  final String? reasonCode;
  final String? message;

  /// How much more the basket needs for a minimum-order coupon.
  final double? shortfall;
  final double? minOrderAmount;

  /// A better automatic promotion won, so the coupon was set aside.
  bool get supersededByPromotion => reasonCode == 'BETTER_OFFER_APPLIED';

  factory CouponEvaluation.fromJson(Map<String, dynamic> json) => CouponEvaluation(
        valid: asBool(json['valid']),
        couponId: asStringOrNull(json['coupon_id']),
        code: asStringOrNull(json['code']),
        title: asStringOrNull(json['title']),
        discountKind: asStringOrNull(json['discount_kind']),
        discountAmount: asDouble(json['discount_amount']),
        freeDelivery: asBool(json['free_delivery']),
        reasonCode: asStringOrNull(json['reason_code']),
        message: asStringOrNull(json['message']),
        shortfall: asDoubleOrNull(json['shortfall']),
        minOrderAmount: asDoubleOrNull(json['min_order_amount']),
      );
}

/// An automatic promotion the server chose for this basket.
class PromotionApplied {
  const PromotionApplied({
    required this.applied,
    this.promotionId,
    this.name,
    this.headline,
    this.badgeText,
    this.discountAmount = 0,
    this.freeDelivery = false,
    this.suppressedByCoupon = false,
  });

  final bool applied;
  final String? promotionId;
  final String? name;
  final String? headline;
  final String? badgeText;
  final double discountAmount;
  final bool freeDelivery;
  final bool suppressedByCoupon;

  factory PromotionApplied.fromJson(Map<String, dynamic> json) => PromotionApplied(
        applied: asBool(json['applied']),
        promotionId: asStringOrNull(json['promotion_id']),
        name: asStringOrNull(json['name']),
        headline: asStringOrNull(json['headline']),
        badgeText: asStringOrNull(json['badge_text']),
        discountAmount: asDouble(json['discount_amount']),
        freeDelivery: asBool(json['free_delivery']),
        suppressedByCoupon: asBool(json['suppressed_by_coupon']),
      );
}

/// Zone, distance and thresholds for the chosen address.
class DeliveryQuote {
  const DeliveryQuote({
    this.zoneId,
    this.zoneName,
    this.distanceKm,
    this.minOrderAmount,
    this.freeDeliveryThreshold,
    this.etaMinutes,
  });

  final String? zoneId;
  final String? zoneName;
  final double? distanceKm;
  final double? minOrderAmount;
  final double? freeDeliveryThreshold;
  final int? etaMinutes;

  /// How much more spend unlocks free delivery, or null when not applicable.
  double? shortfallToFreeDelivery(double subtotal) {
    final threshold = freeDeliveryThreshold;
    if (threshold == null || threshold <= 0 || subtotal >= threshold) return null;
    return threshold - subtotal;
  }

  factory DeliveryQuote.fromJson(Map<String, dynamic> json) => DeliveryQuote(
        zoneId: asStringOrNull(json['zone_id']),
        zoneName: asStringOrNull(json['zone_name']),
        distanceKm: asDoubleOrNull(json['distance_km']),
        minOrderAmount: asDoubleOrNull(json['min_order_amount']),
        freeDeliveryThreshold: asDoubleOrNull(json['free_delivery_threshold']),
        etaMinutes: asIntOrNull(json['eta_minutes']),
      );
}

class TimingEstimate {
  const TimingEstimate({
    this.prepMinutes = 20,
    this.deliveryMinutes = 0,
    this.totalMinutes = 20,
    this.promisedAt,
  });

  final int prepMinutes;
  final int deliveryMinutes;
  final int totalMinutes;
  final DateTime? promisedAt;

  factory TimingEstimate.fromJson(Map<String, dynamic> json) => TimingEstimate(
        prepMinutes: asInt(json['prep_minutes'], 20),
        deliveryMinutes: asInt(json['delivery_minutes']),
        totalMinutes: asInt(json['total_minutes'], 20),
        promisedAt: asDate(json['promised_at']),
      );
}

/// Whether the branch is taking orders right now, and why not.
class BranchState {
  const BranchState({
    this.branchId,
    this.name = 'Bites Box',
    this.acceptingOrders = true,
    this.serviceMode = 'BOTH',
    this.reasonCode,
    this.statusNote,
    this.prepMinutes = 20,
    this.opensAt,
  });

  final String? branchId;
  final String name;
  final bool acceptingOrders;
  final String serviceMode;
  final String? reasonCode;
  final String? statusNote;
  final int prepMinutes;
  final DateTime? opensAt;

  bool get deliveryAvailable => serviceMode == 'DELIVERY' || serviceMode == 'BOTH';
  bool get pickupAvailable => serviceMode == 'PICKUP' || serviceMode == 'BOTH';

  /// Scheduling is the useful action when we are merely shut, not broken.
  bool get canSchedule =>
      reasonCode == 'OUTSIDE_TRADING_HOURS' || reasonCode == 'TOO_BUSY';

  factory BranchState.fromJson(Map<String, dynamic> json) => BranchState(
        branchId: asStringOrNull(json['id']) ?? asStringOrNull(json['branch_id']),
        name: asString(json['name'], 'Bites Box'),
        acceptingOrders: asBool(json['accepting_orders'], fallback: true),
        serviceMode: asString(json['service_mode'], 'BOTH'),
        reasonCode: asStringOrNull(json['reason_code']),
        statusNote: asStringOrNull(json['status_note']),
        prepMinutes: asInt(json['prep_minutes'], 20),
        opensAt: asDate(json['opens_at']),
      );
}

/// The complete, authoritative state of the cart at one instant.
///
/// Returned by every cart mutation as well as `calculate_checkout`, so the UI
/// always re-renders from a server truth rather than patching local state.
class CheckoutQuote {
  const CheckoutQuote({
    required this.totals,
    required this.lines,
    required this.issues,
    this.cartId,
    this.branchId,
    this.currencyCode = 'INR',
    this.fulfilmentType = 'DELIVERY',
    this.timing = 'NOW',
    this.scheduledFor,
    this.addressId,
    this.paymentMode,
    this.itemCount = 0,
    this.unitCount = 0,
    this.coupon,
    this.promotion,
    this.delivery = const DeliveryQuote(),
    this.timingEstimate = const TimingEstimate(),
    this.branch = const BranchState(),
    this.isValid = false,
    this.calculatedAt,
    this.skippedItems = const [],
  });

  const CheckoutQuote.empty()
      : totals = const CheckoutTotals(),
        lines = const [],
        issues = const [],
        cartId = null,
        branchId = null,
        currencyCode = 'INR',
        fulfilmentType = 'DELIVERY',
        timing = 'NOW',
        scheduledFor = null,
        addressId = null,
        paymentMode = null,
        itemCount = 0,
        unitCount = 0,
        coupon = null,
        promotion = null,
        delivery = const DeliveryQuote(),
        timingEstimate = const TimingEstimate(),
        branch = const BranchState(),
        isValid = false,
        calculatedAt = null,
        skippedItems = const [];

  final CheckoutTotals totals;
  final List<CheckoutLine> lines;
  final List<CheckoutIssue> issues;
  final String? cartId;
  final String? branchId;
  final String currencyCode;
  final String fulfilmentType;
  final String timing;
  final DateTime? scheduledFor;
  final String? addressId;
  final String? paymentMode;
  final int itemCount;
  final int unitCount;
  final CouponEvaluation? coupon;
  final PromotionApplied? promotion;
  final DeliveryQuote delivery;
  final TimingEstimate timingEstimate;
  final BranchState branch;

  /// True when nothing blocks placing this order.
  final bool isValid;
  final DateTime? calculatedAt;

  /// Lines a reorder could not restore.
  final List<SkippedItem> skippedItems;

  bool get isEmpty => lines.isEmpty;
  bool get isDelivery => fulfilmentType == 'DELIVERY';

  /// Self pickup. `fulfilment_type` is only ever DELIVERY or PICKUP, so this is
  /// the exact complement of [isDelivery].
  bool get isPickup => !isDelivery;
  bool get isScheduled => timing == 'SCHEDULED';

  List<CheckoutIssue> get blockingIssues =>
      issues.where((issue) => issue.isBlocking).toList();

  List<CheckoutIssue> get warnings =>
      issues.where((issue) => !issue.isBlocking).toList();

  CheckoutIssue? issueWithCode(String code) {
    for (final issue in issues) {
      if (issue.code == code) return issue;
    }
    return null;
  }

  /// The one message to surface on the primary checkout button.
  String? get blockingMessage {
    final blocking = blockingIssues;
    return blocking.isEmpty ? null : blocking.first.message;
  }

  bool get hasUnavailableLines => lines.any((line) => !line.isAvailable);

  String? get appliedCouponCode => coupon?.valid == true ? coupon?.code : null;

  factory CheckoutQuote.fromJson(Map<String, dynamic> json) {
    final couponJson = asMapOrNull(json['coupon']);
    final promotionJson = asMapOrNull(json['promotion']);

    return CheckoutQuote(
      totals: CheckoutTotals.fromJson(asMap(json['totals'])),
      lines: asList(json['lines'], CheckoutLine.fromJson),
      issues: asList(json['issues'], CheckoutIssue.fromJson),
      cartId: asStringOrNull(json['cart_id']),
      branchId: asStringOrNull(json['branch_id']),
      currencyCode: asString(json['currency_code'], 'INR'),
      fulfilmentType: asString(json['fulfilment_type'], 'DELIVERY'),
      timing: asString(json['timing'], 'NOW'),
      scheduledFor: asDate(json['scheduled_for']),
      addressId: asStringOrNull(json['address_id']),
      paymentMode: asStringOrNull(json['payment_mode']),
      itemCount: asInt(json['item_count']),
      unitCount: asInt(json['unit_count']),
      coupon: couponJson == null ? null : CouponEvaluation.fromJson(couponJson),
      promotion: promotionJson == null ? null : PromotionApplied.fromJson(promotionJson),
      delivery: DeliveryQuote.fromJson(asMap(json['delivery'])),
      timingEstimate: TimingEstimate.fromJson(asMap(json['timing_estimate'])),
      branch: BranchState.fromJson(asMap(json['branch'])),
      isValid: asBool(json['is_valid']),
      calculatedAt: asDate(json['calculated_at']),
      skippedItems: asList(json['skipped_items'], SkippedItem.fromJson),
    );
  }
}

/// A reorder line that could not be added back.
class SkippedItem {
  const SkippedItem({required this.productName, this.variantName, required this.reason});

  final String productName;
  final String? variantName;
  final String reason;

  String get label =>
      variantName == null ? productName : '$productName ($variantName)';

  factory SkippedItem.fromJson(Map<String, dynamic> json) => SkippedItem(
        productName: asString(json['product_name']),
        variantName: asStringOrNull(json['variant_name']),
        reason: asString(json['reason'], 'Unavailable'),
      );
}

/// A modifier selection on its way to the server.
class ModifierSelection {
  const ModifierSelection({required this.modifierId, this.quantity = 1});

  final String modifierId;
  final int quantity;

  Map<String, dynamic> toJson() => {'modifier_id': modifierId, 'quantity': quantity};
}
