import 'package:bitesbox/features/customer/data/growth_repository.dart';
import 'package:bitesbox/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

void main() {
  group('customer growth models', () {
    test('outlet payload exposes ordering and service mode safely', () {
      final outlet = OutletSummary.fromJson({
        'id': 'branch-1',
        'name': 'Bites Box Patna',
        'city': 'Patna',
        'service_mode': 'PICKUP',
        'ordering': {'accepting_orders': false, 'reason_code': 'OUTSIDE_HOURS'},
      });

      expect(outlet.acceptingOrders, isFalse);
      expect(outlet.serviceMode, 'PICKUP');
      expect(outlet.reasonCode, 'OUTSIDE_HOURS');
    });

    test('favorites preserve unavailable and discontinued state', () {
      final unavailable = FavoriteDish.fromJson({
        'id': 'dish-1', 'name': 'Litti Chokha', 'base_price': '180',
        'is_active': true, 'is_available': false, 'slug': 'litti-chokha',
      });
      final discontinued = FavoriteDish.fromJson({
        'id': 'dish-2', 'name': 'Seasonal Dish', 'base_price': 90,
        'is_active': false, 'is_available': false,
      });

      expect(unavailable.isActive, isTrue);
      expect(unavailable.isAvailable, isFalse);
      expect(discontinued.isActive, isFalse);
      expect(discontinued.isAvailable, isFalse);
    });

    test('referral summary safely parses server-owned status', () {
      final summary = ReferralSummary.fromJson({
        'code': 'BB9X3QK4P7', 'share_path': '/r/BB9X3QK4P7',
        'program_active': false, 'attributed_count': 2, 'rewarded_count': 0,
      });

      expect(summary.code, 'BB9X3QK4P7');
      expect(summary.programActive, isFalse);
      expect(summary.attributedCount, 2);
      expect(summary.rewardedCount, 0);
    });

    test('active referral summary exposes configured terms and invite progress', () {
      final summary = ReferralSummary.fromJson({
        'code': 'BB9X3QK4P7',
        'share_path': '/r/BB9X3QK4P7',
        'program_active': true,
        'attributed_count': 1,
        'qualified_count': 0,
        'rewarded_count': 0,
        'terms': {
          'referrer_reward': 25,
          'referred_reward': 30,
          'minimum_order_amount': 300,
          'reward_expiry_days': 90,
        },
        'referrals': [
          {
            'status': 'ATTRIBUTED',
            'attributed_at': '2026-10-23T08:00:00.000Z',
            'qualified_at': null,
            'rewarded_at': null,
            'reward_amount': 0,
          },
        ],
      });

      expect(summary.programActive, isTrue);
      expect(summary.terms?.referrerReward, 25);
      expect(summary.terms?.referredReward, 30);
      expect(summary.terms?.minimumOrderAmount, 300);
      expect(summary.terms?.rewardExpiryDays, 90);
      expect(summary.referrals.single.status, 'ATTRIBUTED');
    });
  });

  test('English and Hindi generated localization expose critical checkout copy', () async {
    const delegate = AppLocalizations.delegate;
    final english = await delegate.load(const Locale('en'));
    final hindi = await delegate.load(const Locale('hi'));

    expect(english.checkout, 'Checkout');
    expect(hindi.checkout, isNot(english.checkout));
    expect(hindi.orderCriticalMessages, contains('ज़रूरी'));
    expect(english.outletPickerAddressHint, contains('delivery address'));
    expect(hindi.outletPickerAddressHint, contains('डिलीवरी पते'));
    expect(hindi.switchOutletTitle, 'आउटलेट बदलें?');
  });
}
