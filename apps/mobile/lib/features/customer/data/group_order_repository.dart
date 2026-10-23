import '../../../core/network/api_client.dart';
import 'group_order_models.dart';

class GroupOrderRepository {
  const GroupOrderRepository(this._api);

  final ApiClient _api;

  Future<String> create({String? branchId}) async {
    final result = await _api.rpc<dynamic>(
      'group_order_create',
      params: {if (branchId != null) 'p_branch_id': branchId},
      retries: 0,
    );
    return _actionId(result);
  }

  Future<String> join(String inviteCode) async {
    final result = await _api.rpc<dynamic>(
      'group_order_join',
      params: {'p_invite_code': inviteCode.trim().toUpperCase()},
      retries: 0,
    );
    return _actionId(result);
  }

  Future<GroupOrder?> current() async {
    final result = await _api.rpc<dynamic>('group_order_current');
    if (result is! Map) return null;
    return GroupOrder.fromJson(Map<String, dynamic>.from(result));
  }

  Future<GroupOrder> detail(String groupOrderId) async {
    final result = await _api.rpc<dynamic>(
      'group_order_detail',
      params: {'p_group_order_id': groupOrderId},
      dedupeKey: 'group_order:$groupOrderId',
    );
    if (result is! Map) {
      throw StateError('The group order could not be loaded.');
    }
    return GroupOrder.fromJson(Map<String, dynamic>.from(result));
  }

  Future<void> leave(String groupOrderId) async {
    await _api.rpc<dynamic>(
      'group_order_leave',
      params: {'p_group_order_id': groupOrderId},
      retries: 0,
    );
  }

  Future<void> close(String groupOrderId) async {
    await _api.rpc<dynamic>(
      'group_order_close',
      params: {'p_group_order_id': groupOrderId},
      retries: 0,
    );
  }

  Future<void> merge(String groupOrderId) async {
    await _api.rpc<dynamic>(
      'group_order_merge',
      params: {'p_group_order_id': groupOrderId},
      retries: 0,
      dedupeKey: 'group_order_merge:$groupOrderId',
    );
  }

  static String _actionId(dynamic result) {
    if (result is Map && result['group_order_id'] is String) {
      return result['group_order_id'] as String;
    }
    throw StateError('The group order could not be started.');
  }
}
