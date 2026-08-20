import 'package:bitesbox/core/auth/session.dart';
import 'package:flutter_test/flutter_test.dart';

/// The session decides which of the three shells a signed-in user loads and what
/// each screen is allowed to offer. It is parsed from `public.my_session()`, so
/// these tests pin the JSON contract as much as the logic.
void main() {
  group('AppRole', () {
    test('maps every database code', () {
      expect(AppRole.fromCode('CUSTOMER'), AppRole.customer);
      expect(AppRole.fromCode('DELIVERY_PARTNER'), AppRole.deliveryPartner);
      expect(AppRole.fromCode('KITCHEN_STAFF'), AppRole.kitchenStaff);
      expect(AppRole.fromCode('MANAGER'), AppRole.manager);
      expect(AppRole.fromCode('OPERATIONS'), AppRole.operations);
      expect(AppRole.fromCode('FINANCE'), AppRole.finance);
      expect(AppRole.fromCode('SUPPORT'), AppRole.support);
      expect(AppRole.fromCode('MARKETING'), AppRole.marketing);
      expect(AppRole.fromCode('ADMIN'), AppRole.admin);
      expect(AppRole.fromCode('OWNER'), AppRole.owner);
    });

    // An unrecognised role must fall back to the least privileged shell, never to
    // a staff one. A future role added server-side reaches an older build as null.
    test('falls back to customer for anything unknown', () {
      expect(AppRole.fromCode('SOMETHING_NEW'), AppRole.customer);
      expect(AppRole.fromCode(null), AppRole.customer);
      expect(AppRole.fromCode(''), AppRole.customer);
    });

    test('classifies which shell a role belongs to', () {
      expect(AppRole.deliveryPartner.isDelivery, isTrue);
      expect(AppRole.kitchenStaff.isKitchen, isTrue);
      expect(AppRole.customer.isDelivery, isFalse);
      expect(AppRole.customer.isKitchen, isFalse);
      expect(AppRole.customer.isManagement, isFalse);
    });

    test('treats manager, operations, admin and owner as management', () {
      for (final role in [
        AppRole.manager,
        AppRole.operations,
        AppRole.admin,
        AppRole.owner,
      ]) {
        expect(role.isManagement, isTrue, reason: role.code);
      }

      // Finance, support and marketing work in the admin dashboard, not on a tablet.
      for (final role in [AppRole.finance, AppRole.support, AppRole.marketing]) {
        expect(role.isManagement, isFalse, reason: role.code);
      }
    });

    test('gives every role a human label', () {
      for (final role in AppRole.values) {
        expect(role.label.trim(), isNotEmpty);
      }
    });
  });

  group('AppSession.guest', () {
    const guest = AppSession.guest();

    test('is not authenticated and holds nothing', () {
      expect(guest.isGuest, isTrue);
      expect(guest.userId, isNull);
      expect(guest.profile, isNull);
      expect(guest.permissions, isEmpty);
      expect(guest.branches, isEmpty);
    });

    test('grants no permission', () {
      expect(guest.can('order.create'), isFalse);
      expect(guest.canAny(['order.create', 'menu.view']), isFalse);
    });

    test('is not asked to complete a profile it does not have', () {
      expect(guest.needsProfileSetup, isFalse);
    });
  });

  group('AppSession.fromJson', () {
    test('an unauthenticated payload is a guest whatever else it contains', () {
      final session = AppSession.fromJson({
        'authenticated': false,
        'user_id': 'ignored',
        'permissions': ['settings.update'],
      });

      expect(session.isGuest, isTrue);
      expect(session.can('settings.update'), isFalse);
    });

    test('reads a customer', () {
      final session = AppSession.fromJson({
        'authenticated': true,
        'user_id': '91000000-0000-0000-0000-000000000001',
        'primary_role': 'CUSTOMER',
        'profile': {
          'id': '91000000-0000-0000-0000-000000000001',
          'full_name': 'Aarav Kumar',
          'phone': '+919900000001',
          'onboarding_completed': true,
          'total_orders': 4,
        },
        'roles': [
          {'role': 'CUSTOMER', 'label': 'Customer', 'is_primary': true},
        ],
        'permissions': ['menu.view', 'order.create'],
        'branches': [
          {'id': 'branch-1', 'code': 'BKP-01', 'name': 'Bakhtiyarpur', 'status': 'OPEN'},
        ],
        'account_active': true,
      });

      expect(session.isGuest, isFalse);
      expect(session.isCustomer, isTrue);
      expect(session.isRider, isFalse);
      expect(session.isKitchen, isFalse);
      expect(session.prefersKitchenShell, isFalse);
      expect(session.profile?.firstName, 'Aarav');
      expect(session.branchId, 'branch-1');
      expect(session.can('order.create'), isTrue);
      expect(session.can('settings.update'), isFalse);
      expect(session.needsProfileSetup, isFalse);
    });

    test('tolerates a payload with only the required fields', () {
      final session = AppSession.fromJson({'authenticated': true});

      expect(session.isGuest, isFalse);
      expect(session.primaryRole, AppRole.customer);
      expect(session.permissions, isEmpty);
      expect(session.branches, isEmpty);
      // No profile means the name has not been collected yet.
      expect(session.needsProfileSetup, isTrue);
    });

    test('ignores malformed entries rather than throwing', () {
      final session = AppSession.fromJson({
        'authenticated': true,
        'roles': ['not-an-object', 42],
        'permissions': ['menu.view', 7, null],
        'branches': ['nope'],
      });

      expect(session.roles, isEmpty);
      expect(session.permissions, {'menu.view'});
      expect(session.branches, isEmpty);
    });
  });

  group('shell selection', () {
    AppSession sessionWith(List<String> roleCodes, {String primary = 'CUSTOMER'}) {
      return AppSession.fromJson({
        'authenticated': true,
        'primary_role': primary,
        'profile': {'id': 'u1', 'full_name': 'Test User', 'onboarding_completed': true},
        'roles': [
          for (final code in roleCodes) {'role': code, 'label': code},
        ],
      });
    }

    test('a delivery grant loads the rider shell', () {
      final session = sessionWith(['DELIVERY_PARTNER'], primary: 'DELIVERY_PARTNER');
      expect(session.isRider, isTrue);
      expect(session.isCustomer, isFalse);
    });

    // Role membership comes from the grant list, not from primary_role: a rider
    // whose primary role was left as CUSTOMER must still reach the rider shell,
    // otherwise they would be shown a cart they cannot use.
    test('a delivery grant wins even when the primary role says customer', () {
      final session = sessionWith(['CUSTOMER', 'DELIVERY_PARTNER']);
      expect(session.isRider, isTrue);
    });

    test('kitchen staff prefer the kitchen shell', () {
      final session = sessionWith(['KITCHEN_STAFF'], primary: 'KITCHEN_STAFF');
      expect(session.isKitchen, isTrue);
      expect(session.prefersKitchenShell, isTrue);
      expect(session.isRider, isFalse);
    });

    test('a manager gets the kitchen shell on a tablet', () {
      final session = sessionWith(['MANAGER'], primary: 'MANAGER');
      expect(session.isKitchen, isFalse);
      expect(session.isManagement, isTrue);
      expect(session.prefersKitchenShell, isTrue);
    });

    test('a plain customer prefers neither operations shell', () {
      final session = sessionWith(['CUSTOMER']);
      expect(session.prefersKitchenShell, isFalse);
      expect(session.isRider, isFalse);
    });
  });

  group('needsProfileSetup', () {
    AppSession customer({String? name, bool completed = true}) {
      return AppSession.fromJson({
        'authenticated': true,
        'primary_role': 'CUSTOMER',
        'profile': {
          'id': 'u1',
          if (name != null) 'full_name': name,
          'onboarding_completed': completed,
        },
      });
    }

    // The name reaches the kitchen ticket and the rider at the door, so checkout is
    // blocked until it exists.
    test('is true without a name', () {
      expect(customer(name: null).needsProfileSetup, isTrue);
      expect(customer(name: '').needsProfileSetup, isTrue);
      expect(customer(name: '   ').needsProfileSetup, isTrue);
    });

    test('is true when onboarding was never completed', () {
      expect(customer(name: 'Aarav', completed: false).needsProfileSetup, isTrue);
    });

    test('is false once both are satisfied', () {
      expect(customer(name: 'Aarav').needsProfileSetup, isFalse);
    });

    // Staff and riders are created by an operator, so they are never sent through
    // the customer profile form.
    test('never applies to a rider or kitchen account', () {
      final rider = AppSession.fromJson({
        'authenticated': true,
        'primary_role': 'DELIVERY_PARTNER',
        'profile': {'id': 'u1', 'onboarding_completed': false},
        'roles': [
          {'role': 'DELIVERY_PARTNER', 'label': 'Rider'},
        ],
      });

      expect(rider.needsProfileSetup, isFalse);
    });
  });

  group('UserProfile', () {
    test('reads the account lifecycle', () {
      final blocked = UserProfile.fromJson({'id': 'u1', 'status': 'BLOCKED'});
      expect(blocked.isBlocked, isTrue);
      expect(blocked.isActive, isFalse);

      final active = UserProfile.fromJson({'id': 'u1', 'status': 'ACTIVE'});
      expect(active.isActive, isTrue);
    });

    test('falls back to a friendly greeting with no name', () {
      expect(UserProfile.fromJson({'id': 'u1'}).firstName, 'there');
      expect(UserProfile.fromJson({'id': 'u1', 'full_name': '  '}).firstName, 'there');
    });

    test('takes the first word as the first name', () {
      expect(
        UserProfile.fromJson({'id': 'u1', 'full_name': 'Aarav Kumar Singh'}).firstName,
        'Aarav',
      );
    });
  });
}
