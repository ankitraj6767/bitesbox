import '../../../shared/json.dart';
import '../../customer/data/cart_models.dart' show BranchState;

/// Kitchen models, mirroring `public.kitchen_queue()` and
/// `public.kitchen_availability()`.

class KitchenItemModifier {
  const KitchenItemModifier({
    required this.groupName,
    required this.modifierName,
    this.quantity = 1,
  });

  final String groupName;
  final String modifierName;
  final int quantity;

  String get label => quantity > 1 ? '$modifierName ×$quantity' : modifierName;

  factory KitchenItemModifier.fromJson(Map<String, dynamic> json) => KitchenItemModifier(
        groupName: asString(json['group_name']),
        modifierName: asString(json['modifier_name']),
        quantity: asInt(json['quantity'], 1),
      );
}

class KitchenItem {
  const KitchenItem({
    required this.id,
    required this.productName,
    required this.quantity,
    this.variantName,
    this.foodType = 'VEG',
    this.specialInstructions,
    this.isCancelled = false,
    this.modifiers = const [],
  });

  final String id;
  final String productName;
  final int quantity;
  final String? variantName;
  final String foodType;
  final String? specialInstructions;
  final bool isCancelled;
  final List<KitchenItemModifier> modifiers;

  bool get isVeg => foodType == 'VEG' || foodType == 'VEGAN';
  bool get hasInstructions => (specialInstructions ?? '').trim().isNotEmpty;

  /// The add-on line printed under the dish name on the ticket.
  String get modifierLine => modifiers.map((modifier) => modifier.label).join(', ');

  factory KitchenItem.fromJson(Map<String, dynamic> json) => KitchenItem(
        id: asString(json['id']),
        productName: asString(json['product_name']),
        quantity: asInt(json['quantity'], 1),
        variantName: asStringOrNull(json['variant_name']),
        foodType: asString(json['food_type'], 'VEG'),
        specialInstructions: asStringOrNull(json['special_instructions']),
        isCancelled: asBool(json['is_cancelled']),
        modifiers: asList(json['modifiers'], KitchenItemModifier.fromJson),
      );
}

class KitchenRider {
  const KitchenRider({
    required this.name,
    this.phone,
    this.assignmentStatus,
    this.arrivedStoreAt,
  });

  final String name;
  final String? phone;
  final String? assignmentStatus;
  final DateTime? arrivedStoreAt;

  bool get isWaiting => arrivedStoreAt != null && assignmentStatus == 'AT_STORE';

  factory KitchenRider.fromJson(Map<String, dynamic> json) => KitchenRider(
        name: asString(json['name']),
        phone: asStringOrNull(json['phone']),
        assignmentStatus: asStringOrNull(json['assignment_status']),
        arrivedStoreAt: asDate(json['arrived_store_at']),
      );
}

/// One ticket on the kitchen tablet.
class KitchenOrder {
  const KitchenOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.items,
    this.fulfilmentType = 'DELIVERY',
    this.timing = 'NOW',
    this.scheduledFor,
    this.paymentMode = 'ONLINE',
    this.paymentStatus = 'PENDING',
    this.isPaid = false,
    this.customerNote,
    this.itemCount = 0,
    this.unitCount = 0,
    this.grandTotal = 0,
    this.placedAt,
    this.acceptedAt,
    this.preparingAt,
    this.readyAt,
    this.promisedAt,
    this.prepMinutesEstimate,
    this.elapsedSeconds = 0,
    this.isDelayed = false,
    this.isLateInStage = false,
    this.isFirstOrder = false,
    this.rider,
  });

  final String id;
  final String orderNumber;
  final String status;
  final List<KitchenItem> items;
  final String fulfilmentType;
  final String timing;
  final DateTime? scheduledFor;
  final String paymentMode;
  final String paymentStatus;
  final bool isPaid;
  final String? customerNote;
  final int itemCount;
  final int unitCount;
  final double grandTotal;
  final DateTime? placedAt;
  final DateTime? acceptedAt;
  final DateTime? preparingAt;
  final DateTime? readyAt;
  final DateTime? promisedAt;
  final int? prepMinutesEstimate;

  /// Seconds since the order was placed, computed by the server so every tablet
  /// agrees regardless of its own clock.
  final int elapsedSeconds;
  final bool isDelayed;

  /// Sitting in the current stage longer than the configured threshold.
  final bool isLateInStage;
  final bool isFirstOrder;
  final KitchenRider? rider;

  bool get isPickup => fulfilmentType == 'PICKUP';
  bool get isScheduled => timing == 'SCHEDULED';
  bool get isCod => paymentMode == 'COD' || paymentMode == 'SPLIT_WALLET_COD';
  bool get needsAttention => isDelayed || isLateInStage;

  bool get hasSpecialInstructions =>
      (customerNote ?? '').trim().isNotEmpty || items.any((item) => item.hasInstructions);

  /// The kitchen column this ticket belongs in.
  KitchenStage get stage => switch (status) {
        'ORDER_PLACED' => KitchenStage.newOrders,
        'STORE_ACCEPTED' => KitchenStage.accepted,
        'PREPARING' => KitchenStage.preparing,
        'READY_FOR_PICKUP' => KitchenStage.ready,
        _ => KitchenStage.newOrders,
      };

  /// Elapsed seconds ticked forward locally between refreshes, so the timer moves
  /// smoothly without hammering the server.
  int elapsedSecondsAt(DateTime now) {
    final placed = placedAt;
    if (placed == null) return elapsedSeconds;
    final measured = now.difference(placed).inSeconds;
    return measured < elapsedSeconds ? elapsedSeconds : measured;
  }

  factory KitchenOrder.fromJson(Map<String, dynamic> json) {
    final riderJson = asMapOrNull(json['rider']);
    return KitchenOrder(
      id: asString(json['id']),
      orderNumber: asString(json['order_number']),
      status: asString(json['status']),
      items: asList(json['items'], KitchenItem.fromJson),
      fulfilmentType: asString(json['fulfilment_type'], 'DELIVERY'),
      timing: asString(json['timing'], 'NOW'),
      scheduledFor: asDate(json['scheduled_for']),
      paymentMode: asString(json['payment_mode'], 'ONLINE'),
      paymentStatus: asString(json['payment_status'], 'PENDING'),
      isPaid: asBool(json['is_paid']),
      customerNote: asStringOrNull(json['customer_note']),
      itemCount: asInt(json['item_count']),
      unitCount: asInt(json['unit_count']),
      grandTotal: asDouble(json['grand_total']),
      placedAt: asDate(json['placed_at']),
      acceptedAt: asDate(json['accepted_at']),
      preparingAt: asDate(json['preparing_at']),
      readyAt: asDate(json['ready_at']),
      promisedAt: asDate(json['promised_at']),
      prepMinutesEstimate: asIntOrNull(json['prep_minutes_estimate']),
      elapsedSeconds: asInt(json['elapsed_seconds']),
      isDelayed: asBool(json['is_delayed']),
      isLateInStage: asBool(json['is_late_in_stage']),
      isFirstOrder: asBool(json['is_first_order']),
      rider: riderJson == null ? null : KitchenRider.fromJson(riderJson),
    );
  }
}

enum KitchenStage {
  newOrders('New'),
  accepted('Accepted'),
  preparing('Preparing'),
  ready('Ready');

  const KitchenStage(this.label);

  final String label;
}

class KitchenCounts {
  const KitchenCounts({
    this.newOrders = 0,
    this.accepted = 0,
    this.preparing = 0,
    this.ready = 0,
    this.delayed = 0,
  });

  final int newOrders;
  final int accepted;
  final int preparing;
  final int ready;
  final int delayed;

  int forStage(KitchenStage stage) => switch (stage) {
        KitchenStage.newOrders => newOrders,
        KitchenStage.accepted => accepted,
        KitchenStage.preparing => preparing,
        KitchenStage.ready => ready,
      };

  int get total => newOrders + accepted + preparing + ready;

  factory KitchenCounts.fromJson(Map<String, dynamic> json) => KitchenCounts(
        newOrders: asInt(json['new']),
        accepted: asInt(json['accepted']),
        preparing: asInt(json['preparing']),
        ready: asInt(json['ready']),
        delayed: asInt(json['delayed']),
      );
}

class CompletedTicket {
  const CompletedTicket({
    required this.id,
    required this.orderNumber,
    required this.status,
    this.unitCount = 0,
    this.pickedUpAt,
    this.deliveredAt,
  });

  final String id;
  final String orderNumber;
  final String status;
  final int unitCount;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;

  factory CompletedTicket.fromJson(Map<String, dynamic> json) => CompletedTicket(
        id: asString(json['id']),
        orderNumber: asString(json['order_number']),
        status: asString(json['status']),
        unitCount: asInt(json['unit_count']),
        pickedUpAt: asDate(json['picked_up_at']),
        deliveredAt: asDate(json['delivered_at']),
      );
}

class KitchenQueue {
  const KitchenQueue({
    required this.branch,
    required this.orders,
    required this.counts,
    this.recentlyCompleted = const [],
    this.generatedAt,
  });

  final BranchState branch;
  final List<KitchenOrder> orders;
  final KitchenCounts counts;
  final List<CompletedTicket> recentlyCompleted;
  final DateTime? generatedAt;

  List<KitchenOrder> forStage(KitchenStage stage) =>
      orders.where((order) => order.stage == stage).toList();

  /// Ticket ids currently awaiting acceptance — drives the new-order chime.
  Set<String> get newOrderIds => orders
      .where((order) => order.stage == KitchenStage.newOrders)
      .map((order) => order.id)
      .toSet();

  factory KitchenQueue.fromJson(Map<String, dynamic> json) => KitchenQueue(
        branch: BranchState.fromJson(asMap(json['branch'])),
        orders: asList(json['orders'], KitchenOrder.fromJson),
        counts: KitchenCounts.fromJson(asMap(json['counts'])),
        recentlyCompleted: asList(json['recently_completed'], CompletedTicket.fromJson),
        generatedAt: asDate(json['generated_at']),
      );
}

// ── Availability ───────────────────────────────────────────────────────────
class AvailabilityVariant {
  const AvailabilityVariant({
    required this.id,
    required this.name,
    required this.price,
    this.optionGroup,
    this.availability = 'AVAILABLE',
  });

  final String id;
  final String name;
  final double price;
  final String? optionGroup;
  final String availability;

  bool get isAvailable => availability == 'AVAILABLE';

  factory AvailabilityVariant.fromJson(Map<String, dynamic> json) => AvailabilityVariant(
        id: asString(json['id']),
        name: asString(json['name']),
        price: asDouble(json['price']),
        optionGroup: asStringOrNull(json['option_group']),
        availability: asString(json['availability'], 'AVAILABLE'),
      );
}

class AvailabilityProduct {
  const AvailabilityProduct({
    required this.id,
    required this.name,
    required this.state,
    this.thumbnailPath,
    this.foodType = 'VEG',
    this.basePrice = 0,
    this.remainingQuantity,
    this.outOfStockUntil,
    this.outOfStockReason,
    this.changedAt,
    this.isOrderable = true,
    this.variants = const [],
  });

  final String id;
  final String name;

  /// `availability_state`: AVAILABLE / OUT_OF_STOCK / TEMPORARILY_UNAVAILABLE
  final String state;
  final String? thumbnailPath;
  final String foodType;
  final double basePrice;
  final int? remainingQuantity;
  final DateTime? outOfStockUntil;
  final String? outOfStockReason;
  final DateTime? changedAt;
  final bool isOrderable;
  final List<AvailabilityVariant> variants;

  bool get isAvailable => state == 'AVAILABLE';

  String get stateLabel => switch (state) {
        'AVAILABLE' => 'Available',
        'OUT_OF_STOCK' => 'Out of stock',
        'TEMPORARILY_UNAVAILABLE' => 'Paused',
        _ => state,
      };

  /// "Back at 8:30 PM" when the pause auto-expires.
  bool get autoResumes => outOfStockUntil != null;

  factory AvailabilityProduct.fromJson(Map<String, dynamic> json) => AvailabilityProduct(
        id: asString(json['id']),
        name: asString(json['name']),
        state: asString(json['state'], 'AVAILABLE'),
        thumbnailPath: asStringOrNull(json['thumbnail_path']),
        foodType: asString(json['food_type'], 'VEG'),
        basePrice: asDouble(json['base_price']),
        remainingQuantity: asIntOrNull(json['remaining_quantity']),
        outOfStockUntil: asDate(json['out_of_stock_until']),
        outOfStockReason: asStringOrNull(json['out_of_stock_reason']),
        changedAt: asDate(json['changed_at']),
        isOrderable: asBool(json['is_orderable'], fallback: true),
        variants: asList(json['variants'], AvailabilityVariant.fromJson),
      );
}

class AvailabilityCategory {
  const AvailabilityCategory({
    required this.id,
    required this.name,
    required this.products,
  });

  final String id;
  final String name;
  final List<AvailabilityProduct> products;

  int get outOfStockCount =>
      products.where((product) => !product.isAvailable).length;

  factory AvailabilityCategory.fromJson(Map<String, dynamic> json) => AvailabilityCategory(
        id: asString(json['id']),
        name: asString(json['name']),
        products: asList(json['products'], AvailabilityProduct.fromJson),
      );
}

class KitchenAvailability {
  const KitchenAvailability({required this.categories, this.outOfStockCount = 0});

  final List<AvailabilityCategory> categories;
  final int outOfStockCount;

  /// Flat list, used by the search filter on the availability screen.
  List<AvailabilityProduct> get allProducts =>
      categories.expand((category) => category.products).toList();

  factory KitchenAvailability.fromJson(Map<String, dynamic> json) => KitchenAvailability(
        categories: asList(json['categories'], AvailabilityCategory.fromJson),
        outOfStockCount: asInt(json['out_of_stock_count']),
      );
}
