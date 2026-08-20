import '../../../core/network/api_client.dart';
import 'cart_models.dart';
import 'menu_models.dart' show CustomerCoupon;

/// Cart and checkout.
///
/// Every method returns the complete, re-priced [CheckoutQuote]. The app holds no
/// derived cart state at all: it sends an intent and renders whatever the server
/// says the cart now is. That is what makes a tampered client harmless.
class CartRepository {
  const CartRepository(this._api);

  final ApiClient _api;

  Future<CheckoutQuote> quote({
    String? cartId,
    String? branchId,
    String? paymentMode,
    double tipAmount = 0,
    int loyaltyPoints = 0,
  }) async {
    final result = await _api.rpc<dynamic>(
      'calculate_checkout',
      params: {
        if (cartId != null) 'p_cart_id': cartId,
        if (branchId != null) 'p_branch_id': branchId,
        if (paymentMode != null) 'p_payment_mode': paymentMode,
        'p_tip_amount': tipAmount,
        'p_loyalty_points': loyaltyPoints,
      },
    );

    return _parse(result);
  }

  Future<CheckoutQuote> addItem({
    required String productId,
    String? variantId,
    int quantity = 1,
    List<ModifierSelection> modifiers = const [],
    String? specialInstructions,
    String? branchId,
    bool replaceQuantity = false,
  }) async {
    final result = await _api.rpc<dynamic>(
      'cart_add_item',
      params: {
        'p_product_id': productId,
        'p_quantity': quantity,
        'p_modifiers': modifiers.map((modifier) => modifier.toJson()).toList(),
        'p_replace_quantity': replaceQuantity,
        if (variantId != null) 'p_variant_id': variantId,
        if (specialInstructions != null && specialInstructions.trim().isNotEmpty)
          'p_special_instructions': specialInstructions.trim(),
        if (branchId != null) 'p_branch_id': branchId,
      },
      // A double tap on "Add" must not add twice.
      dedupeKey: 'cart_add:$productId:$variantId:${modifiers.length}',
    );

    return _parse(result);
  }

  Future<CheckoutQuote> updateQuantity({
    required String cartItemId,
    required int quantity,
  }) async {
    final result = await _api.rpc<dynamic>(
      'cart_update_item',
      params: {'p_cart_item_id': cartItemId, 'p_quantity': quantity},
      dedupeKey: 'cart_update:$cartItemId:$quantity',
    );

    return _parse(result);
  }

  Future<CheckoutQuote> removeItem(String cartItemId) async {
    final result = await _api.rpc<dynamic>(
      'cart_remove_item',
      params: {'p_cart_item_id': cartItemId},
      dedupeKey: 'cart_remove:$cartItemId',
    );

    return _parse(result);
  }

  Future<CheckoutQuote> clear({String? branchId}) async {
    final result = await _api.rpc<dynamic>(
      'cart_clear',
      params: {if (branchId != null) 'p_branch_id': branchId},
    );

    return _parse(result);
  }

  /// Fulfilment, address, timing, wallet — anything that changes the price.
  ///
  /// Only the keys present in the request are written, so the checkout screen can
  /// change one option without echoing the rest back.
  Future<CheckoutQuote> setOptions({
    String? branchId,
    String? fulfilmentType,
    String? addressId,
    String? timing,
    DateTime? scheduledFor,
    String? deliveryInstructions,
    String? cookingInstructions,
    bool? useWallet,
    bool clearCoupon = false,
  }) async {
    final result = await _api.rpc<dynamic>(
      'cart_set_options',
      params: {
        'p_clear_coupon': clearCoupon,
        if (branchId != null) 'p_branch_id': branchId,
        if (fulfilmentType != null) 'p_fulfilment_type': fulfilmentType,
        if (addressId != null) 'p_address_id': addressId,
        if (timing != null) 'p_timing': timing,
        if (scheduledFor != null) 'p_scheduled_for': scheduledFor.toUtc().toIso8601String(),
        if (deliveryInstructions != null) 'p_delivery_instructions': deliveryInstructions,
        if (cookingInstructions != null) 'p_cooking_instructions': cookingInstructions,
        if (useWallet != null) 'p_use_wallet': useWallet,
      },
    );

    return _parse(result);
  }

  /// Applies a coupon. A rejected code throws with a specific reason
  /// (expired, min order, first order only…) which the sheet shows verbatim.
  Future<CheckoutQuote> applyCoupon(String code, {String? cartId, String? branchId}) async {
    final result = await _api.rpc<dynamic>(
      'apply_coupon',
      params: {
        'p_code': code.trim().toUpperCase(),
        if (cartId != null) 'p_cart_id': cartId,
        if (branchId != null) 'p_branch_id': branchId,
      },
    );

    return _parse(result);
  }

  Future<CheckoutQuote> removeCoupon({String? branchId}) async {
    final result = await _api.rpc<dynamic>(
      'remove_coupon',
      params: {if (branchId != null) 'p_branch_id': branchId},
    );

    return _parse(result);
  }

  /// Every visible coupon, each annotated with whether it applies to this cart.
  Future<List<CustomerCoupon>> availableCoupons({String? branchId}) async {
    final result = await _api.rpc<dynamic>(
      'available_coupons',
      params: {if (branchId != null) 'p_branch_id': branchId},
      dedupeKey: 'available_coupons:$branchId',
    );

    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => CustomerCoupon.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Rebuilds the cart from a past order, reporting the lines it could not restore.
  Future<CheckoutQuote> reorder(String orderId) async {
    final result = await _api.rpc<dynamic>(
      'reorder',
      params: {'p_order_id': orderId},
      dedupeKey: 'reorder:$orderId',
    );

    return _parse(result);
  }

  static CheckoutQuote _parse(dynamic result) {
    if (result is! Map) return const CheckoutQuote.empty();
    return CheckoutQuote.fromJson(Map<String, dynamic>.from(result));
  }
}
