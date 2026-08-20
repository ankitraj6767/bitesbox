import '../../../core/network/api_client.dart';
import '../../../shared/json.dart';
import 'account_models.dart';

/// Wallet, notifications and support.
class AccountRepository {
  const AccountRepository(this._api);

  final ApiClient _api;

  Future<WalletSummary> wallet() async {
    final result = await _api.rpc<dynamic>('my_wallet', dedupeKey: 'my_wallet');
    return WalletSummary.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// In-app notifications, newest first. RLS scopes this to the caller.
  Future<List<AppNotificationItem>> notifications({int limit = 50}) async {
    final rows = await _api.select(
      'notifications',
      columns: 'id, event, title, body, order_id, read_at, created_at',
      filter: (query) => query
          .eq('channel', 'IN_APP')
          .order('created_at', ascending: false)
          .limit(limit),
    );

    return rows.map(AppNotificationItem.fromJson).toList();
  }

  /// Marks everything read when [ids] is empty.
  Future<int> markNotificationsRead({List<String> ids = const []}) async {
    final result = await _api.rpc<dynamic>(
      'mark_notifications_read',
      params: {if (ids.isNotEmpty) 'p_ids': ids},
    );

    return asInt(result);
  }

  Future<List<SupportTicket>> tickets() async {
    final rows = await _api.select(
      'support_tickets',
      columns: '''
        id, ticket_number, category, subject, status, priority, order_id,
        created_at, resolved_at, message_count, last_message_at
      ''',
      filter: (query) => query.order('created_at', ascending: false).limit(50),
    );

    return rows.map(SupportTicket.fromJson).toList();
  }

  Future<SupportThread> ticket(String ticketId) async {
    final result = await _api.rpc<dynamic>(
      'support_ticket_detail',
      params: {'p_ticket_id': ticketId},
      dedupeKey: 'support_ticket:$ticketId',
    );

    return SupportThread.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// Opens a ticket. Priority and SLA are set by the server from the category.
  Future<String> createTicket({
    required String category,
    required String subject,
    required String description,
    String? orderId,
  }) async {
    final result = await _api.rpc<dynamic>(
      'create_support_ticket',
      params: {
        'p_category': category,
        'p_subject': subject.trim(),
        'p_description': description.trim(),
        if (orderId != null) 'p_order_id': orderId,
      },
      dedupeKey: 'create_ticket:$category:$orderId',
    );

    final json = asMap(result);
    return asString(json['id']).isNotEmpty
        ? asString(json['id'])
        : asString(json['ticket_id']);
  }

  Future<void> postMessage({required String ticketId, required String body}) async {
    await _api.rpc<dynamic>(
      'post_support_message',
      params: {'p_ticket_id': ticketId, 'p_body': body.trim()},
    );
  }

  /// Profile edits. Only the supplied fields are written.
  Future<void> updateProfile({
    String? fullName,
    String? email,
    String? preferredLanguage,
    bool? marketingOptIn,
    bool? pushEnabled,
    bool? smsEnabled,
    bool? whatsappEnabled,
  }) async {
    await _api.rpc<dynamic>('update_my_profile', params: {
      if (fullName != null) 'p_full_name': fullName.trim(),
      if (email != null && email.trim().isNotEmpty) 'p_email': email.trim(),
      if (preferredLanguage != null) 'p_preferred_language': preferredLanguage,
      if (marketingOptIn != null) 'p_marketing_opt_in': marketingOptIn,
      if (pushEnabled != null) 'p_push_enabled': pushEnabled,
      if (smsEnabled != null) 'p_sms_enabled': smsEnabled,
      if (whatsappEnabled != null) 'p_whatsapp_enabled': whatsappEnabled,
    });
  }
}
