import '../../../shared/json.dart';
import 'order_models.dart' show OrderDetail;

/// Wallet, loyalty, notifications and support — everything on the account tab.

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.kind,
    required this.amount,
    required this.description,
    this.balanceAfter = 0,
    this.orderId,
    this.createdAt,
  });

  final String id;
  final String kind;
  final double amount;
  final String description;
  final double balanceAfter;
  final String? orderId;
  final DateTime? createdAt;

  /// A debit reduces the balance; the sign comes from the ledger, not the UI.
  bool get isDebit => amount < 0;

  String get kindLabel => switch (kind) {
        'REFUND_CREDIT' => 'Refund',
        'ORDER_PAYMENT' => 'Order payment',
        'CASHBACK' => 'Cashback',
        'GOODWILL_CREDIT' => 'Goodwill credit',
        'TOPUP' => 'Top-up',
        'EXPIRY' => 'Expired',
        'ADJUSTMENT' => 'Adjustment',
        _ => kind,
      };

  factory WalletTransaction.fromJson(Map<String, dynamic> json) => WalletTransaction(
        id: asString(json['id']),
        kind: asString(json['kind']),
        amount: asDouble(json['amount']),
        description: asString(json['description']),
        balanceAfter: asDouble(json['balance_after']),
        orderId: asStringOrNull(json['order_id']),
        createdAt: asDate(json['created_at']),
      );
}

class WalletSummary {
  const WalletSummary({
    this.enabled = false,
    this.balance = 0,
    this.isFrozen = false,
    this.transactions = const [],
  });

  final bool enabled;
  final double balance;

  /// Frozen by the back office; the customer can see it but not spend it.
  final bool isFrozen;
  final List<WalletTransaction> transactions;

  bool get isSpendable => enabled && !isFrozen && balance > 0;

  factory WalletSummary.fromJson(Map<String, dynamic> json) => WalletSummary(
        enabled: asBool(json['enabled']),
        balance: asDouble(json['balance']),
        isFrozen: asBool(json['is_frozen']),
        transactions: asList(json['transactions'], WalletTransaction.fromJson),
      );
}

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.event,
    this.orderId,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String? event;
  final String? orderId;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isUnread => readAt == null;

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) => AppNotificationItem(
        id: asString(json['id']),
        title: asString(json['title']),
        body: asString(json['body']),
        event: asStringOrNull(json['event']),
        orderId: asStringOrNull(json['order_id']),
        readAt: asDate(json['read_at']),
        createdAt: asDate(json['created_at']),
      );
}

/// A support conversation summary, read straight from `support_tickets` under RLS.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.ticketNumber,
    required this.category,
    required this.subject,
    required this.status,
    this.priority = 'NORMAL',
    this.orderId,
    this.createdAt,
    this.resolvedAt,
    this.messageCount = 0,
    this.lastMessageAt,
  });

  final String id;
  final String ticketNumber;
  final String category;
  final String subject;
  final String status;
  final String priority;
  final String? orderId;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final int messageCount;
  final DateTime? lastMessageAt;

  bool get isOpen => status != 'RESOLVED' && status != 'CLOSED';

  String get statusLabel => switch (status) {
        'OPEN' => 'Open',
        'IN_PROGRESS' => 'In progress',
        'WAITING_ON_CUSTOMER' => 'Waiting on you',
        'ESCALATED' => 'Escalated',
        'RESOLVED' => 'Resolved',
        'CLOSED' => 'Closed',
        _ => status,
      };

  /// Customer-facing labels for `public.ticket_category`.
  static const categoryLabels = <String, String>{
    'ORDER_DELAYED': 'My order is late',
    'MISSING_ITEM': 'Something is missing',
    'WRONG_ITEM': 'I got the wrong item',
    'FOOD_QUALITY': 'Problem with the food',
    'PAYMENT_PROBLEM': 'Payment problem',
    'REFUND': 'Refund question',
    'DELIVERY_ISSUE': 'Delivery problem',
    'CANCELLATION': 'Cancellation help',
    'APP_ISSUE': 'Problem with the app',
    'OTHER': 'Something else',
  };

  String get categoryLabel => categoryLabels[category] ?? category;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: asString(json['id']),
        ticketNumber: asString(json['ticket_number']),
        category: asString(json['category'], 'OTHER'),
        subject: asString(json['subject']),
        status: asString(json['status'], 'OPEN'),
        priority: asString(json['priority'], 'NORMAL'),
        orderId: asStringOrNull(json['order_id']),
        createdAt: asDate(json['created_at']),
        resolvedAt: asDate(json['resolved_at']),
        messageCount: asInt(json['message_count']),
        lastMessageAt: asDate(json['last_message_at']),
      );
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.body,
    required this.authorKind,
    this.authorName,
    this.isInternal = false,
    this.createdAt,
  });

  final String id;
  final String body;
  final String authorKind;
  final String? authorName;
  final bool isInternal;
  final DateTime? createdAt;

  bool get isFromCustomer => authorKind == 'CUSTOMER';

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
        id: asString(json['id']),
        body: asString(json['body']),
        authorKind: asString(json['author_kind'], 'AGENT'),
        authorName: asStringOrNull(json['author_name']),
        isInternal: asBool(json['is_internal']),
        createdAt: asDate(json['created_at']),
      );
}

class SupportThread {
  const SupportThread({
    required this.ticket,
    required this.messages,
    this.order,
  });

  final SupportTicket ticket;
  final List<SupportMessage> messages;

  /// Present when the ticket was raised against an order.
  final OrderDetail? order;

  factory SupportThread.fromJson(Map<String, dynamic> json) {
    final orderJson = asMapOrNull(json['order']);
    return SupportThread(
      ticket: SupportTicket.fromJson(asMap(json['ticket'])),
      messages: asList(json['messages'], SupportMessage.fromJson),
      order: orderJson == null ? null : OrderDetail.fromJson(orderJson),
    );
  }
}
