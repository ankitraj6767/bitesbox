import '../../../core/network/api_client.dart';
import 'taste_passport_models.dart';

class TastePassportRepository {
  const TastePassportRepository(this._api);

  final ApiClient _api;

  Future<TastePassportProfile> profile() async {
    final result = await _api.rpc<dynamic>(
      'my_taste_profile',
      dedupeKey: 'my_taste_profile',
    );
    return TastePassportProfile.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<TastePassportProfile> save({
    required List<String> foodTypes,
    required String? maxSpice,
    required List<String> categoryIds,
    required double? priceCeiling,
  }) async {
    final result = await _api.rpc<dynamic>(
      'save_my_taste_profile',
      params: {
        'p_food_types': foodTypes,
        'p_max_spice': maxSpice,
        'p_category_ids': categoryIds,
        'p_price_ceiling': priceCeiling,
      },
    );
    return TastePassportProfile.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }
}
