import 'package:bitesbox/features/customer/data/menu_models.dart';
import 'package:bitesbox/features/customer/data/taste_passport_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('taste profile safely parses optional, owner-returned preferences', () {
    final empty = TastePassportProfile.fromJson({});
    expect(empty.foodTypes, isEmpty);
    expect(empty.categoryIds, isEmpty);
    expect(empty.maxSpice, isNull);
    expect(empty.priceCeiling, isNull);
    expect(empty.hasProfile, isFalse);

    final saved = TastePassportProfile.fromJson({
      'food_types': ['VEG', 'VEGAN'],
      'max_spice': 'MILD',
      'category_ids': ['category-1'],
      'price_ceiling': '250.00',
      'has_profile': true,
    });
    expect(saved.foodTypes, ['VEG', 'VEGAN']);
    expect(saved.maxSpice, 'MILD');
    expect(saved.categoryIds, ['category-1']);
    expect(saved.priceCeiling, 250);
    expect(saved.hasProfile, isTrue);
  });

  test('home feed parses taste setup state and stable reason codes', () {
    final section = HomeSection.fromJson({
      'id': 'section-1',
      'key': 'taste-match',
      'kind': 'TASTE_MATCH',
      'taste_state': 'SETUP',
      'products': [
        {
          'id': 'dish-1',
          'category_id': 'category-1',
          'name': 'Litti Chokha',
          'slug': 'litti-chokha',
          'base_price': 180,
          'reason_code': 'POPULAR_AT_OUTLET',
          'is_available': true,
        },
      ],
    });

    expect(section.kind, 'TASTE_MATCH');
    expect(section.tasteState, 'SETUP');
    expect(section.products.single.reasonCode, 'POPULAR_AT_OUTLET');
    expect(section.products.single.isAvailable, isTrue);
  });
}
