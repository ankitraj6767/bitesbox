import '../../../shared/json.dart';
import 'cart_models.dart' show CheckoutTotals;

/// Order models, mirroring `app.order_payload()` and `public.my_orders()`.
///
/// Status is never interpreted as a number or reordered client-side: the server
/// owns the state machine, and this file only decides how each status *reads*.

/// Presentation for one order status. Keeping this in one place means the
/// customer, kitchen and rider shells describe an order identically.
class OrderStatusView {
  const OrderStatusView({
    required this.label,
    required this.description,
    required this.step,
    this.isFailure = false,
  });

  final String label;
  final String description;

  /// 0-based position in the five-step customer tracker; -1 when off-track.
  final int step;
  final bool isFailure;

  /// The customer-facing tracker: placed → accepted → preparing → on the way →
  /// delivered. Pickup orders collapse the last two.
  static const trackerSteps = <String>[
    'Placed',
    'Accepted',
    'Preparing',
    'On the way',
    'Delivered',
  ];

  static OrderStatusView of(String status, {bool isPickup = false}) => switch (status) {
        'PENDING_PAYMENT' => const OrderStatusView(
            label: 'Awaiting payment',
            description: 'Finish the payment to send this order to our kitchen.',
            step: -1,
          ),
        'PAYMENT_FAILED' => const OrderStatusView(
            label: 'Payment failed',
            description: 'The payment did not go through. You can retry safely.',
            step: -1,
            isFailure: true,
          ),
        'PAYMENT_CONFIRMED' => const OrderStatusView(
            label: 'Payment confirmed',
            description: 'Payment received. Sending your order to the kitchen.',
            step: 0,
          ),
        'ORDER_PLACED' => const OrderStatusView(
            label: 'Order placed',
            description: 'We have your order. The kitchen is confirming it now.',
            step: 0,
          ),
        'STORE_ACCEPTED' => const OrderStatusView(
            label: 'Order accepted',
            description: 'Our kitchen has accepted your order.',
            step: 1,
          ),
        'PREPARING' => const OrderStatusView(
            label: 'Being prepared',
            description: 'Your food is being cooked fresh.',
            step: 2,
          ),
        'READY_FOR_PICKUP' => OrderStatusView(
            label: isPickup ? 'Ready for pickup' : 'Ready',
            description: isPickup
                ? 'Your order is packed and waiting at the counter.'
                : 'Packed and waiting for a delivery partner.',
            step: isPickup ? 4 : 2,
          ),
        'RIDER_ASSIGNED' => const OrderStatusView(
            label: 'Delivery partner assigned',
            description: 'A delivery partner is on the way to collect your order.',
            step: 3,
          ),
        'RIDER_ARRIVED_STORE' => const OrderStatusView(
            label: 'Partner at the restaurant',
            description: 'Your delivery partner has reached our kitchen.',
            step: 3,
          ),
        'PICKED_UP' => const OrderStatusView(
            label: 'Picked up',
            description: 'Your order has left our kitchen.',
            step: 3,
          ),
        'OUT_FOR_DELIVERY' => const OrderStatusView(
            label: 'On the way',
            description: 'Your food is on its way to you.',
            step: 3,
          ),
        'RIDER_ARRIVED_CUSTOMER' => const OrderStatusView(
            label: 'Partner has arrived',
            description: 'Your delivery partner is outside. Share your OTP to receive the order.',
            step: 3,
          ),
        'DELIVERED' => const OrderStatusView(
            label: 'Delivered',
            description: 'Enjoy your meal.',
            step: 4,
          ),
        'COMPLETED' => const OrderStatusView(
            label: 'Completed',
            description: 'This order is complete.',
            step: 4,
          ),
        'STORE_REJECTED' => const OrderStatusView(
            label: 'Order declined',
            description: 'Our kitchen could not take this order. Any payment is refunded.',
            step: -1,
            isFailure: true,
          ),
        'CUSTOMER_CANCELLED' => const OrderStatusView(
            label: 'Cancelled',
            description: 'You cancelled this order.',
            step: -1,
            isFailure: true,
          ),
        'ADMIN_CANCELLED' => const OrderStatusView(
            label: 'Cancelled',
            description: 'This order was cancelled by our team.',
            step: -1,
            isFailure: true,
          ),
        'DELIVERY_FAILED' => const OrderStatusView(
            label: 'Delivery failed',
            description: 'We could not complete the delivery. Our team will be in touch.',
            step: -1,
            isFailure: true,
          ),
        'REFUND_PENDING' => const OrderStatusView(
            label: 'Refund in progress',
            description: 'Your refund is being processed.',
            step: -1,
          ),
        'PARTIALLY_REFUNDED' => const OrderStatusView(
            label: 'Partially refunded',
            description: 'Part of this order has been refunded.',
            step: -1,
          ),
        'REFUNDED' => const OrderStatusView(
            label: 'Refunded',
            description: 'This order has been fully refunded.',
            step: -1,
          ),
        _ => OrderStatusView(label: status, description: '', step: -1),
      };
}

class OrderItemPreview {
  const OrderItemPreview({
    required this.productName,
    required this.quantity,
    this.variantName,
    this.imagePath,
  });

  final String productName;
  final int quantity;
  final String? variantName;
  final String? imagePath;

  factory OrderItemPreview.fromJson(Map<String, dynamic> json) => OrderItemPreview(
        productName: asString(json['product_name']),
        quantity: asInt(json['quantity'], 1),
        variantName: asStringOrNull(json['variant_name']),
        imagePath: asStringOrNull(json['image_path']),
      );
}

/// A row in "My orders".
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.grandTotal,
    this.isActive = false,
    this.fulfilmentType = 'DELIVERY',
    this.itemCount = 0,
    this.unitCount = 0,
    this.paymentMode = 'ONLINE',
    this.paymentStatus = 'PENDING',
    this.createdAt,
    this.placedAt,
    this.deliveredAt,
    this.promisedAt,
    this.refundedAmount = 0,
    this.hasReview = false,
    this.itemsPreview = const [],
  });

  final String id;
  final String orderNumber;
  final String status;
  final double grandTotal;
  final bool isActive;
  final String fulfilmentType;
  final int itemCount;
  final int unitCount;
  final String paymentMode;
  final String paymentStatus;
  final DateTime? createdAt;
  final DateTime? placedAt;
  final DateTime? deliveredAt;
  final DateTime? promisedAt;
  final double refundedAmount;
  final bool hasReview;
  final List<OrderItemPreview> itemsPreview;

  bool get isPickup => fulfilmentType == 'PICKUP';
  OrderStatusView get statusView => OrderStatusView.of(status, isPickup: isPickup);
  bool get awaitingPayment => status == 'PENDING_PAYMENT' || status == 'PAYMENT_FAILED';
  bool get canReview => (status == 'DELIVERED' || status == 'COMPLETED') && !hasReview;

  /// "Chicken Biryani, Paneer Tikka +2 more"
  String get itemsLabel {
    if (itemsPreview.isEmpty) return '$unitCount item${unitCount == 1 ? '' : 's'}';
    final names = itemsPreview.map((item) => item.productName).toList();
    final extra = itemCount - names.length;
    final joined = names.join(', ');
    return extra > 0 ? '$joined +$extra more' : joined;
  }

  factory OrderSummary.fromJson(Map<String, dynamic> json) => OrderSummary(
        id: asString(json['id']),
        orderNumber: asString(json['order_number']),
        status: asString(json['status']),
        grandTotal: asDouble(json['grand_total']),
        isActive: asBool(json['is_active']),
        fulfilmentType: asString(json['fulfilment_type'], 'DELIVERY'),
        itemCount: asInt(json['item_count']),
        unitCount: asInt(json['unit_count']),
        paymentMode: asString(json['payment_mode'], 'ONLINE'),
        paymentStatus: asString(json['payment_status'], 'PENDING'),
        createdAt: asDate(json['created_at']),
        placedAt: asDate(json['placed_at']),
        deliveredAt: asDate(json['delivered_at']),
        promisedAt: asDate(json['promised_at']),
        refundedAmount: asDouble(json['refunded_amount']),
        hasReview: asBool(json['has_review']),
        itemsPreview: asList(json['items_preview'], OrderItemPreview.fromJson),
      );
}

class OrderList {
  const OrderList({required this.orders, this.total = 0, this.hasMore = false});

  final List<OrderSummary> orders;
  final int total;
  final bool hasMore;

  factory OrderList.fromJson(Map<String, dynamic> json) => OrderList(
        orders: asList(json['orders'], OrderSummary.fromJson),
        total: asInt(json['total']),
        hasMore: asBool(json['has_more']),
      );
}

class OrderItemModifier {
  const OrderItemModifier({
    required this.groupName,
    required this.modifierName,
    required this.quantity,
    this.unitPrice = 0,
    this.totalPrice = 0,
  });

  final String groupName;
  final String modifierName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  String get label => quantity > 1 ? '$modifierName ×$quantity' : modifierName;

  factory OrderItemModifier.fromJson(Map<String, dynamic> json) => OrderItemModifier(
        groupName: asString(json['group_name']),
        modifierName: asString(json['modifier_name']),
        quantity: asInt(json['quantity'], 1),
        unitPrice: asDouble(json['unit_price']),
        totalPrice: asDouble(json['total_price']),
      );
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.netAmount,
    this.productId,
    this.variantName,
    this.variantOptionGroup,
    this.categoryName,
    this.foodType = 'VEG',
    this.imagePath,
    this.modifiersPrice = 0,
    this.grossAmount = 0,
    this.allocatedDiscount = 0,
    this.taxAmount = 0,
    this.specialInstructions,
    this.isCancelled = false,
    this.refundedQuantity = 0,
    this.modifiers = const [],
  });

  final String id;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double netAmount;
  final String? productId;
  final String? variantName;
  final String? variantOptionGroup;
  final String? categoryName;
  final String foodType;
  final String? imagePath;
  final double modifiersPrice;
  final double grossAmount;
  final double allocatedDiscount;
  final double taxAmount;
  final String? specialInstructions;
  final bool isCancelled;
  final int refundedQuantity;
  final List<OrderItemModifier> modifiers;

  bool get isVeg => foodType == 'VEG' || foodType == 'VEGAN';

  String get configurationLabel {
    final parts = <String>[
      if (variantName != null && variantName!.isNotEmpty) variantName!,
      ...modifiers.map((modifier) => modifier.label),
    ];
    return parts.join(' · ');
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: asString(json['id']),
        productName: asString(json['product_name']),
        quantity: asInt(json['quantity'], 1),
        unitPrice: asDouble(json['unit_price']),
        netAmount: asDouble(json['net_amount']),
        productId: asStringOrNull(json['product_id']),
        variantName: asStringOrNull(json['variant_name']),
        variantOptionGroup: asStringOrNull(json['variant_option_group']),
        categoryName: asStringOrNull(json['category_name']),
        foodType: asString(json['food_type'], 'VEG'),
        imagePath: asStringOrNull(json['image_path']),
        modifiersPrice: asDouble(json['modifiers_price']),
        grossAmount: asDouble(json['gross_amount']),
        allocatedDiscount: asDouble(json['allocated_discount']),
        taxAmount: asDouble(json['tax_amount']),
        specialInstructions: asStringOrNull(json['special_instructions']),
        isCancelled: asBool(json['is_cancelled']),
        refundedQuantity: asInt(json['refunded_quantity']),
        modifiers: asList(json['modifiers'], OrderItemModifier.fromJson),
      );
}

class TimelineEntry {
  const TimelineEntry({
    required this.toStatus,
    required this.label,
    this.fromStatus,
    this.note,
    this.actorKind,
    this.isOverride = false,
    this.createdAt,
  });

  final String toStatus;
  final String label;
  final String? fromStatus;
  final String? note;
  final String? actorKind;
  final bool isOverride;
  final DateTime? createdAt;

  factory TimelineEntry.fromJson(Map<String, dynamic> json) {
    final status = asString(json['to_status']);
    return TimelineEntry(
      toStatus: status,
      label: asStringOrNull(json['label']) ?? OrderStatusView.of(status).label,
      fromStatus: asStringOrNull(json['from_status']),
      note: asStringOrNull(json['note']),
      actorKind: asStringOrNull(json['actor_kind']),
      isOverride: asBool(json['is_override']),
      createdAt: asDate(json['created_at']),
    );
  }
}

/// The rider's live position. Only drawn when [isFresh].
class RiderLocation {
  const RiderLocation({
    this.latitude,
    this.longitude,
    this.headingDegrees,
    this.etaMinutes,
    this.distanceKm,
    this.recordedAt,
    this.isFresh = false,
  });

  final double? latitude;
  final double? longitude;
  final double? headingDegrees;
  final int? etaMinutes;
  final double? distanceKm;
  final DateTime? recordedAt;

  /// The server decides freshness (a fix older than two minutes is stale), so a
  /// device with a wrong clock cannot make an old position look live.
  final bool isFresh;

  bool get hasPosition => latitude != null && longitude != null;

  factory RiderLocation.fromJson(Map<String, dynamic> json) => RiderLocation(
        latitude: asDoubleOrNull(json['latitude']),
        longitude: asDoubleOrNull(json['longitude']),
        headingDegrees: asDoubleOrNull(json['heading_degrees']),
        etaMinutes: asIntOrNull(json['eta_minutes']),
        distanceKm: asDoubleOrNull(json['distance_to_destination_km']),
        recordedAt: asDate(json['recorded_at']),
        isFresh: asBool(json['is_fresh']),
      );
}

class RiderInfo {
  const RiderInfo({
    required this.name,
    this.assignmentId,
    this.assignmentStatus,
    this.deliveryPartnerId,
    this.photoPath,
    this.phone,
    this.vehicleType,
    this.vehicleNumber,
    this.ratingAverage = 0,
    this.liveLocation,
  });

  final String name;
  final String? assignmentId;
  final String? assignmentStatus;
  final String? deliveryPartnerId;
  final String? photoPath;
  final String? phone;
  final String? vehicleType;
  final String? vehicleNumber;
  final double ratingAverage;
  final RiderLocation? liveLocation;

  bool get canCall => phone != null && phone!.isNotEmpty;

  factory RiderInfo.fromJson(Map<String, dynamic> json) {
    final location = asMapOrNull(json['live_location']);
    return RiderInfo(
      name: asString(json['name'], 'Delivery partner'),
      assignmentId: asStringOrNull(json['assignment_id']),
      assignmentStatus: asStringOrNull(json['assignment_status']),
      deliveryPartnerId: asStringOrNull(json['delivery_partner_id']),
      photoPath: asStringOrNull(json['photo_path']),
      phone: asStringOrNull(json['phone']),
      vehicleType: asStringOrNull(json['vehicle_type']),
      vehicleNumber: asStringOrNull(json['vehicle_number']),
      ratingAverage: asDouble(json['rating_average']),
      liveLocation: location == null ? null : RiderLocation.fromJson(location),
    );
  }
}

class OrderTotals {
  const OrderTotals({
    this.currencyCode = 'INR',
    this.itemsSubtotal = 0,
    this.itemsDiscount = 0,
    this.couponCode,
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
    this.roundOff = 0,
    this.walletApplied = 0,
    this.loyaltyDiscount = 0,
    this.loyaltyPointsRedeemed = 0,
    this.grandTotal = 0,
    this.payableAmount = 0,
    this.refundedAmount = 0,
    this.cancellationFee = 0,
  });

  final String currencyCode;
  final double itemsSubtotal;
  final double itemsDiscount;
  final String? couponCode;
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
  final double deliveryFeeWaived;
  final double serviceFee;
  final double tipAmount;
  final double roundOff;
  final double walletApplied;
  final double loyaltyDiscount;
  final int loyaltyPointsRedeemed;
  final double grandTotal;
  final double payableAmount;
  final double refundedAmount;
  final double cancellationFee;

  /// Presents a placed order's stored totals through the same shape the cart
  /// uses, so one bill widget renders both. Nothing is recomputed: these are the
  /// exact figures written when the order was created.
  CheckoutTotals asCheckoutTotals() => CheckoutTotals(
        itemsSubtotal: itemsSubtotal,
        itemsDiscount: itemsDiscount,
        couponDiscount: couponDiscount,
        promotionDiscount: promotionDiscount,
        totalDiscount: totalDiscount,
        taxableAmount: taxableAmount,
        taxAmount: taxAmount,
        cgstAmount: cgstAmount,
        sgstAmount: sgstAmount,
        igstAmount: igstAmount,
        cessAmount: cessAmount,
        packagingCharge: packagingCharge,
        deliveryFee: deliveryFee,
        deliveryFeeWaived: deliveryFeeWaived,
        serviceFee: serviceFee,
        tipAmount: tipAmount,
        loyaltyPointsRedeemed: loyaltyPointsRedeemed,
        loyaltyDiscount: loyaltyDiscount,
        roundOff: roundOff,
        grandTotal: grandTotal,
        walletApplied: walletApplied,
        payableAmount: payableAmount,
        totalSavings: totalDiscount + deliveryFeeWaived + loyaltyDiscount,
      );

  factory OrderTotals.fromJson(Map<String, dynamic> json) => OrderTotals(
        currencyCode: asString(json['currency_code'], 'INR'),
        itemsSubtotal: asDouble(json['items_subtotal']),
        itemsDiscount: asDouble(json['items_discount']),
        couponCode: asStringOrNull(json['coupon_code']),
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
        roundOff: asDouble(json['round_off']),
        walletApplied: asDouble(json['wallet_applied']),
        loyaltyDiscount: asDouble(json['loyalty_discount']),
        loyaltyPointsRedeemed: asInt(json['loyalty_points_redeemed']),
        grandTotal: asDouble(json['grand_total']),
        payableAmount: asDouble(json['payable_amount']),
        refundedAmount: asDouble(json['refunded_amount']),
        cancellationFee: asDouble(json['cancellation_fee']),
      );
}

class OrderPayment {
  const OrderPayment({
    this.mode = 'ONLINE',
    this.status = 'PENDING',
    this.codStatus,
    this.method,
    this.paidAt,
  });

  final String mode;
  final String status;
  final String? codStatus;
  final String? method;
  final DateTime? paidAt;

  bool get isCod => mode == 'COD' || mode == 'SPLIT_WALLET_COD';
  bool get isPaid => status == 'CAPTURED';

  String get label => switch (mode) {
        'COD' => 'Cash on delivery',
        'SPLIT_WALLET_COD' => 'Wallet + cash',
        'WALLET' => 'Bites Box wallet',
        'PAY_AT_STORE' => 'Pay at store',
        _ => method == null ? 'Paid online' : 'Paid via ${method!.toLowerCase()}',
      };

  factory OrderPayment.fromJson(Map<String, dynamic> json) => OrderPayment(
        mode: asString(json['mode'], 'ONLINE'),
        status: asString(json['status'], 'PENDING'),
        codStatus: asStringOrNull(json['cod_status']),
        method: asStringOrNull(json['method']),
        paidAt: asDate(json['paid_at']),
      );
}

class OrderDeliveryInfo {
  const OrderDeliveryInfo({
    this.addressLine1,
    this.addressLine2,
    this.landmark,
    this.area,
    this.city,
    this.state,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.instructions,
    this.contactName,
    this.contactPhone,
    this.zoneName,
    this.distanceKm,
  });

  final String? addressLine1;
  final String? addressLine2;
  final String? landmark;
  final String? area;
  final String? city;
  final String? state;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final String? instructions;
  final String? contactName;
  final String? contactPhone;
  final String? zoneName;
  final double? distanceKm;

  String get formatted => [
        addressLine1,
        addressLine2,
        landmark,
        area,
        city,
        postalCode,
      ].where((part) => part != null && part.trim().isNotEmpty).join(', ');

  bool get hasAddress => (addressLine1 ?? '').trim().isNotEmpty;

  factory OrderDeliveryInfo.fromJson(Map<String, dynamic> json) => OrderDeliveryInfo(
        addressLine1: asStringOrNull(json['address_line1']),
        addressLine2: asStringOrNull(json['address_line2']),
        landmark: asStringOrNull(json['landmark']),
        area: asStringOrNull(json['area']),
        city: asStringOrNull(json['city']),
        state: asStringOrNull(json['state']),
        postalCode: asStringOrNull(json['postal_code']),
        latitude: asDoubleOrNull(json['latitude']),
        longitude: asDoubleOrNull(json['longitude']),
        instructions: asStringOrNull(json['instructions']),
        contactName: asStringOrNull(json['contact_name']),
        contactPhone: asStringOrNull(json['contact_phone']),
        zoneName: asStringOrNull(json['zone_name']),
        distanceKm: asDoubleOrNull(json['distance_km']),
      );
}

class OrderTiming {
  const OrderTiming({
    this.placedAt,
    this.acceptedAt,
    this.preparingAt,
    this.readyAt,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.cancelledAt,
    this.promisedAt,
    this.prepMinutesEstimate,
    this.deliveryMinutesEstimate,
    this.isDelayed = false,
    this.createdAt,
  });

  final DateTime? placedAt;
  final DateTime? acceptedAt;
  final DateTime? preparingAt;
  final DateTime? readyAt;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final DateTime? promisedAt;
  final int? prepMinutesEstimate;
  final int? deliveryMinutesEstimate;
  final bool isDelayed;
  final DateTime? createdAt;

  factory OrderTiming.fromJson(Map<String, dynamic> json) => OrderTiming(
        placedAt: asDate(json['placed_at']),
        acceptedAt: asDate(json['accepted_at']),
        preparingAt: asDate(json['preparing_at']),
        readyAt: asDate(json['ready_at']),
        assignedAt: asDate(json['assigned_at']),
        pickedUpAt: asDate(json['picked_up_at']),
        deliveredAt: asDate(json['delivered_at']),
        cancelledAt: asDate(json['cancelled_at']),
        promisedAt: asDate(json['promised_at']),
        prepMinutesEstimate: asIntOrNull(json['prep_minutes_estimate']),
        deliveryMinutesEstimate: asIntOrNull(json['delivery_minutes_estimate']),
        isDelayed: asBool(json['is_delayed']),
        createdAt: asDate(json['created_at']),
      );
}

class OrderRefund {
  const OrderRefund({
    required this.id,
    required this.status,
    required this.amount,
    this.kind,
    this.amountProcessed = 0,
    this.destination,
    this.reason,
    this.createdAt,
    this.completedAt,
  });

  final String id;
  final String status;
  final double amount;
  final String? kind;
  final double amountProcessed;
  final String? destination;
  final String? reason;
  final DateTime? createdAt;
  final DateTime? completedAt;

  String get statusLabel => switch (status) {
        'REQUESTED' => 'Refund requested',
        'APPROVED' => 'Refund approved',
        'PROCESSING' => 'Refund processing',
        'COMPLETED' => 'Refunded',
        'REJECTED' => 'Refund declined',
        'FAILED' => 'Refund failed',
        _ => status,
      };

  factory OrderRefund.fromJson(Map<String, dynamic> json) => OrderRefund(
        id: asString(json['id']),
        status: asString(json['status']),
        amount: asDouble(json['amount']),
        kind: asStringOrNull(json['kind']),
        amountProcessed: asDouble(json['amount_processed']),
        destination: asStringOrNull(json['destination']),
        reason: asStringOrNull(json['reason']),
        createdAt: asDate(json['created_at']),
        completedAt: asDate(json['completed_at']),
      );
}

class OrderCancellation {
  const OrderCancellation({
    this.actor,
    this.reason,
    this.note,
    this.cancelledAt,
    this.fee = 0,
  });

  final String? actor;
  final String? reason;
  final String? note;
  final DateTime? cancelledAt;
  final double fee;

  factory OrderCancellation.fromJson(Map<String, dynamic> json) => OrderCancellation(
        actor: asStringOrNull(json['actor']),
        reason: asStringOrNull(json['reason']),
        note: asStringOrNull(json['note']),
        cancelledAt: asDate(json['cancelled_at']),
        fee: asDouble(json['fee']),
      );
}

class OrderReview {
  const OrderReview({
    required this.id,
    required this.overallRating,
    this.foodRating,
    this.deliveryRating,
    this.comment,
    this.createdAt,
  });

  final String id;
  final int overallRating;
  final int? foodRating;
  final int? deliveryRating;
  final String? comment;
  final DateTime? createdAt;

  factory OrderReview.fromJson(Map<String, dynamic> json) => OrderReview(
        id: asString(json['id']),
        overallRating: asInt(json['overall_rating']),
        foodRating: asIntOrNull(json['food_rating']),
        deliveryRating: asIntOrNull(json['delivery_rating']),
        comment: asStringOrNull(json['comment']),
        createdAt: asDate(json['created_at']),
      );
}

/// The full order, as returned by `public.order_detail()`.
class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totals,
    required this.items,
    required this.timeline,
    this.branchId,
    this.statusChangedAt,
    this.isActive = false,
    this.fulfilmentType = 'DELIVERY',
    this.timingMode = 'NOW',
    this.scheduledFor,
    this.itemCount = 0,
    this.unitCount = 0,
    this.customerNote,
    this.customerName,
    this.delivery = const OrderDeliveryInfo(),
    this.payment = const OrderPayment(),
    this.timing = const OrderTiming(),
    this.rider,
    this.cancellation,
    this.refunds = const [],
    this.review,
    this.canCancel = false,
    this.canReview = false,
    this.canReorder = false,
  });

  final String id;
  final String orderNumber;
  final String status;
  final OrderTotals totals;
  final List<OrderItem> items;
  final List<TimelineEntry> timeline;
  final String? branchId;
  final DateTime? statusChangedAt;
  final bool isActive;
  final String fulfilmentType;
  final String timingMode;
  final DateTime? scheduledFor;
  final int itemCount;
  final int unitCount;
  final String? customerNote;
  final String? customerName;
  final OrderDeliveryInfo delivery;
  final OrderPayment payment;
  final OrderTiming timing;
  final RiderInfo? rider;
  final OrderCancellation? cancellation;
  final List<OrderRefund> refunds;
  final OrderReview? review;
  final bool canCancel;
  final bool canReview;
  final bool canReorder;

  bool get isPickup => fulfilmentType == 'PICKUP';
  bool get isScheduled => timingMode == 'SCHEDULED';
  OrderStatusView get statusView => OrderStatusView.of(status, isPickup: isPickup);
  bool get awaitingPayment => status == 'PENDING_PAYMENT' || status == 'PAYMENT_FAILED';

  /// The customer needs their OTP visible from the moment the rider sets off.
  bool get shouldShowDeliveryOtp =>
      !isPickup &&
      (status == 'OUT_FOR_DELIVERY' ||
          status == 'PICKED_UP' ||
          status == 'RIDER_ARRIVED_CUSTOMER');

  bool get isTrackable => isActive && !awaitingPayment;

  /// Live ETA from the rider's own device, falling back to the promise time.
  int? get etaMinutes {
    final live = rider?.liveLocation;
    if (live != null && live.isFresh && live.etaMinutes != null) return live.etaMinutes;
    final promised = timing.promisedAt;
    if (promised == null) return null;
    final minutes = promised.difference(DateTime.now()).inMinutes;
    return minutes < 0 ? 0 : minutes;
  }

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final customer = asMap(json['customer']);
    final riderJson = asMapOrNull(json['rider']);
    final cancellationJson = asMapOrNull(json['cancellation']);
    final reviewJson = asMapOrNull(json['review']);

    return OrderDetail(
      id: asString(json['id']),
      orderNumber: asString(json['order_number']),
      status: asString(json['status']),
      totals: OrderTotals.fromJson(asMap(json['totals'])),
      items: asList(json['items'], OrderItem.fromJson),
      timeline: asList(json['timeline'], TimelineEntry.fromJson),
      branchId: asStringOrNull(json['branch_id']),
      statusChangedAt: asDate(json['status_changed_at']),
      isActive: asBool(json['is_active']),
      fulfilmentType: asString(json['fulfilment_type'], 'DELIVERY'),
      timingMode: asString(json['timing'], 'NOW'),
      scheduledFor: asDate(json['scheduled_for']),
      itemCount: asInt(json['item_count']),
      unitCount: asInt(json['unit_count']),
      customerNote: asStringOrNull(json['customer_note']),
      customerName: asStringOrNull(customer['name']),
      delivery: OrderDeliveryInfo.fromJson(asMap(json['delivery'])),
      payment: OrderPayment.fromJson(asMap(json['payment'])),
      timing: OrderTiming.fromJson(asMap(json['timing'])),
      rider: riderJson == null ? null : RiderInfo.fromJson(riderJson),
      cancellation:
          cancellationJson == null ? null : OrderCancellation.fromJson(cancellationJson),
      refunds: asList(json['refunds'], OrderRefund.fromJson),
      review: reviewJson == null ? null : OrderReview.fromJson(reviewJson),
      canCancel: asBool(json['can_cancel']),
      canReview: asBool(json['can_review']),
      canReorder: asBool(json['can_reorder']),
    );
  }
}

/// What the customer is told before confirming a cancellation, including the
/// exact refund the server will honour.
class CancellationOptions {
  const CancellationOptions({
    required this.canCancel,
    required this.message,
    this.requiresApproval = false,
    this.refundAmount = 0,
    this.cancellationFee = 0,
    this.refundPercentage = 100,
    this.gracePeriodSeconds = 0,
    this.withinGracePeriod = false,
    this.reasonCode,
  });

  final bool canCancel;
  final String message;
  final bool requiresApproval;
  final double refundAmount;
  final double cancellationFee;
  final double refundPercentage;
  final int gracePeriodSeconds;
  final bool withinGracePeriod;
  final String? reasonCode;

  bool get hasFee => cancellationFee > 0;

  /// Reasons offered to the customer, mapped to `public.cancellation_reason`.
  static const customerReasons = <String, String>{
    'CUSTOMER_CHANGED_MIND': 'I changed my mind',
    'ORDERED_BY_MISTAKE': 'I ordered by mistake',
    'DELIVERY_TOO_LONG': 'It is taking too long',
    'ADDRESS_WRONG': 'The delivery address is wrong',
    'DUPLICATE_ORDER': 'I ordered this twice',
    'OTHER': 'Another reason',
  };

  factory CancellationOptions.fromJson(Map<String, dynamic> json) => CancellationOptions(
        canCancel: asBool(json['can_cancel']),
        message: asString(json['message']),
        requiresApproval: asBool(json['requires_approval']),
        refundAmount: asDouble(json['refund_amount']),
        cancellationFee: asDouble(json['cancellation_fee']),
        refundPercentage: asDouble(json['refund_percentage'], 100),
        gracePeriodSeconds: asInt(json['grace_period_seconds']),
        withinGracePeriod: asBool(json['within_grace_period']),
        reasonCode: asStringOrNull(json['reason_code']),
      );
}
