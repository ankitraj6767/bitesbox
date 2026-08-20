import '../../../core/network/api_client.dart';
import '../../../shared/json.dart';

/// Order placement and payment.
///
/// All three calls are Edge Functions holding the service role, because each one
/// must do something the client is not trusted with: recalculate the bill, talk
/// to Razorpay with the secret key, or verify a payment signature.

/// What `create-order` returned.
class PlacedOrder {
  const PlacedOrder({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.paymentMode,
    required this.payableAmount,
    required this.requiresPayment,
    this.paymentStatus = 'PENDING',
    this.grandTotal = 0,
    this.currencyCode = 'INR',
    this.promisedAt,
    this.replayed = false,
  });

  final String orderId;
  final String orderNumber;
  final String status;
  final String paymentMode;
  final double payableAmount;

  /// True when an online payment must be collected before the kitchen sees it.
  final bool requiresPayment;
  final String paymentStatus;
  final double grandTotal;
  final String currencyCode;
  final DateTime? promisedAt;

  /// The idempotency key matched an existing order, so nothing new was created.
  final bool replayed;

  factory PlacedOrder.fromJson(Map<String, dynamic> json) => PlacedOrder(
        orderId: asString(json['order_id']),
        orderNumber: asString(json['order_number']),
        status: asString(json['status']),
        paymentMode: asString(json['payment_mode'], 'ONLINE'),
        payableAmount: asDouble(json['payable_amount']),
        requiresPayment: asBool(json['requires_payment']),
        paymentStatus: asString(json['payment_status'], 'PENDING'),
        grandTotal: asDouble(json['grand_total']),
        currencyCode: asString(json['currency_code'], 'INR'),
        promisedAt: asDate(json['promised_at']),
        replayed: asBool(json['replayed']),
      );
}

/// Everything the Razorpay checkout sheet needs. The amount is in paise and comes
/// from `orders.payable_amount`; the app never supplies it.
class PaymentSession {
  const PaymentSession({
    required this.paymentId,
    required this.orderId,
    required this.providerOrderId,
    required this.amountPaise,
    required this.amountRupees,
    required this.keyId,
    this.currency = 'INR',
    this.name = 'Bites Box',
    this.description = '',
    this.themeColor = '#C1121F',
    this.prefillName = '',
    this.prefillContact = '',
    this.prefillEmail = '',
    this.reused = false,
  });

  final String paymentId;
  final String orderId;
  final String providerOrderId;
  final int amountPaise;
  final double amountRupees;
  final String keyId;
  final String currency;
  final String name;
  final String description;
  final String themeColor;
  final String prefillName;
  final String prefillContact;
  final String prefillEmail;

  /// An existing gateway order was handed back, so a retry cannot double charge.
  final bool reused;

  /// Options map for the Razorpay checkout SDK.
  Map<String, dynamic> toCheckoutOptions() => {
        'key': keyId,
        'order_id': providerOrderId,
        'amount': amountPaise,
        'currency': currency,
        'name': name,
        'description': description,
        'theme': {'color': themeColor},
        'prefill': {
          'name': prefillName,
          'contact': prefillContact,
          'email': prefillEmail,
        },
        'retry': {'enabled': false},
        'send_sms_hash': true,
      };

  factory PaymentSession.fromJson(Map<String, dynamic> json) {
    final payment = asMap(json['payment']);
    final checkout = asMap(json['checkout']);
    final prefill = asMap(checkout['prefill']);

    return PaymentSession(
      paymentId: asString(payment['payment_id']),
      orderId: asString(payment['order_id']),
      providerOrderId: asString(payment['provider_order_id']),
      amountPaise: asInt(payment['amount']),
      amountRupees: asDouble(payment['amount_rupees']),
      keyId: asString(checkout['key_id']),
      currency: asString(payment['currency'], 'INR'),
      name: asString(checkout['name'], 'Bites Box'),
      description: asString(checkout['description']),
      themeColor: asString(checkout['theme_color'], '#C1121F'),
      prefillName: asString(prefill['name']),
      prefillContact: asString(prefill['contact']),
      prefillEmail: asString(prefill['email']),
      reused: asBool(payment['reused']),
    );
  }
}

class PaymentVerification {
  const PaymentVerification({
    required this.verified,
    required this.status,
    this.amountCaptured = 0,
    this.method,
    this.alreadyCaptured = false,
    this.fullyReconciled = false,
    this.orderStatus,
  });

  final bool verified;
  final String status;
  final double amountCaptured;
  final String? method;
  final bool alreadyCaptured;
  final bool fullyReconciled;
  final String? orderStatus;

  factory PaymentVerification.fromJson(Map<String, dynamic> json) {
    final payment = asMap(json['payment']);
    final order = asMap(json['order']);

    return PaymentVerification(
      verified: asBool(json['verified']),
      status: asString(payment['status']),
      amountCaptured: asDouble(payment['amount_captured']),
      method: asStringOrNull(payment['method']),
      alreadyCaptured: asBool(payment['already_captured']),
      fullyReconciled: asBool(payment['fully_reconciled']),
      orderStatus: asStringOrNull(order['status']),
    );
  }
}

class PaymentRepository {
  const PaymentRepository(this._api);

  final ApiClient _api;

  /// Places the order. The server recalculates the entire bill from the cart, so
  /// whatever the checkout screen was showing is only ever a preview.
  ///
  /// [idempotencyKey] must be stable for one checkout attempt: retrying after a
  /// dropped connection then returns the same order instead of a duplicate.
  Future<PlacedOrder> createOrder({
    required String idempotencyKey,
    required String paymentMode,
    String? cartId,
    String? branchId,
    double tipAmount = 0,
    int loyaltyPoints = 0,
    String? appVersion,
    String? devicePlatform,
  }) async {
    final response = await _api.invoke('create-order', body: {
      'idempotency_key': idempotencyKey,
      'payment_mode': paymentMode,
      'tip_amount': tipAmount,
      'loyalty_points': loyaltyPoints,
      if (cartId != null) 'cart_id': cartId,
      if (branchId != null) 'branch_id': branchId,
      if (appVersion != null) 'app_version': appVersion,
      if (devicePlatform != null) 'device_platform': devicePlatform,
    });

    return PlacedOrder.fromJson(asMap(response['order']));
  }

  /// Creates (or reuses) the Razorpay order for an unpaid Bites Box order.
  Future<PaymentSession> createPaymentSession(String orderId) async {
    final response = await _api.invoke('create-payment', body: {'order_id': orderId});
    return PaymentSession.fromJson(response);
  }

  /// Verifies the gateway signature server-side and captures the payment.
  ///
  /// The app treats its own "success" callback as a hint only: until this returns
  /// verified, the order is not paid.
  Future<PaymentVerification> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final response = await _api.invoke('verify-payment', body: {
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    });

    return PaymentVerification.fromJson(response);
  }
}
