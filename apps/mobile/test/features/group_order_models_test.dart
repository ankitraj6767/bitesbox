import 'package:bitesbox/features/customer/data/group_order_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses host, members, and configured dishes from the group snapshot', () {
    final group = GroupOrder.fromJson({
      'id': 'group-1',
      'branch_id': 'branch-1',
      'status': 'OPEN',
      'is_host': true,
      'invite_code': 'AABBCCDD00112233445566778899AABB',
      'expires_at': '2026-10-23T12:00:00Z',
      'members': [
        {
          'user_id': 'user-1',
          'name': 'Ankit',
          'is_host': true,
          'item_count': 2,
          'items': [
            {
              'name': 'Chicken Dum Biryani',
              'quantity': 2,
              'variant_name': 'Full plate',
              'modifiers': ['Raita'],
            },
          ],
        },
      ],
    });

    expect(group.isOpen, isTrue);
    expect(group.isHost, isTrue);
    expect(group.inviteCode, 'AABBCCDD00112233445566778899AABB');
    expect(group.itemCount, 2);
    expect(group.members.single.items.single.variantName, 'Full plate');
    expect(group.members.single.items.single.modifiers, ['Raita']);
  });

  test('handles a missing or malformed optional snapshot field safely', () {
    final group = GroupOrder.fromJson({
      'id': 'group-2',
      'branch_id': 'branch-1',
      'members': 'not-a-list',
    });

    expect(group.status, 'OPEN');
    expect(group.isOpen, isTrue);
    expect(group.inviteCode, isNull);
    expect(group.expiresAt, isNull);
    expect(group.members, isEmpty);
  });
}
