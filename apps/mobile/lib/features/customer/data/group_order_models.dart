import '../../../shared/json.dart';

class GroupOrderItem {
  const GroupOrderItem({
    required this.name,
    required this.quantity,
    this.variantName,
    this.modifiers = const [],
  });

  final String name;
  final int quantity;
  final String? variantName;
  final List<String> modifiers;

  factory GroupOrderItem.fromJson(Map<String, dynamic> json) => GroupOrderItem(
    name: asString(json['name']),
    quantity: asInt(json['quantity'], 1),
    variantName: asStringOrNull(json['variant_name']),
    modifiers: (json['modifiers'] as List? ?? const [])
        .whereType<String>()
        .toList(growable: false),
  );
}

class GroupOrderMember {
  const GroupOrderMember({
    required this.userId,
    required this.name,
    required this.isHost,
    required this.itemCount,
    required this.items,
  });

  final String userId;
  final String name;
  final bool isHost;
  final int itemCount;
  final List<GroupOrderItem> items;

  factory GroupOrderMember.fromJson(Map<String, dynamic> json) =>
      GroupOrderMember(
        userId: asString(json['user_id']),
        name: asString(json['name'], 'Guest'),
        isHost: asBool(json['is_host']),
        itemCount: asInt(json['item_count']),
        items: asList(json['items'], GroupOrderItem.fromJson),
      );
}

class GroupOrder {
  const GroupOrder({
    required this.id,
    required this.branchId,
    required this.status,
    required this.isHost,
    required this.members,
    this.inviteCode,
    this.expiresAt,
  });

  final String id;
  final String branchId;
  final String status;
  final bool isHost;
  final String? inviteCode;
  final DateTime? expiresAt;
  final List<GroupOrderMember> members;

  int get itemCount =>
      members.fold(0, (total, member) => total + member.itemCount);

  bool get isOpen => status == 'OPEN';

  factory GroupOrder.fromJson(Map<String, dynamic> json) => GroupOrder(
    id: asString(json['id']),
    branchId: asString(json['branch_id']),
    status: asString(json['status'], 'OPEN'),
    isHost: asBool(json['is_host']),
    inviteCode: asStringOrNull(json['invite_code']),
    expiresAt: asDate(json['expires_at']),
    members: asList(json['members'], GroupOrderMember.fromJson),
  );
}
