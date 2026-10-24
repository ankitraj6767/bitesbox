import '../../../core/network/api_client.dart';
import '../../../shared/json.dart';

class OutletSummary {
  const OutletSummary({
    required this.id,
    required this.name,
    required this.city,
    required this.acceptingOrders,
    this.serviceMode = 'BOTH',
    this.reasonCode,
  });

  final String id;
  final String name;
  final String city;
  final bool acceptingOrders;
  final String serviceMode;
  final String? reasonCode;

  factory OutletSummary.fromJson(Map<String, dynamic> json) {
    final ordering = asMap(json['ordering']);
    return OutletSummary(
      id: asString(json['id']),
      name: asString(json['name']),
      city: asString(json['city']),
      acceptingOrders: asBool(ordering['accepting_orders']),
      serviceMode: asString(json['service_mode'], 'BOTH'),
      reasonCode: asStringOrNull(ordering['reason_code']),
    );
  }
}

class OutletOption {
  const OutletOption({required this.outlet, this.serviceable, this.reason});
  final OutletSummary outlet;
  final bool? serviceable;
  final String? reason;
}

class FavoriteDish {
  const FavoriteDish({
    required this.id,
    required this.name,
    required this.price,
    required this.isActive,
    required this.isAvailable,
    this.slug = '',
    this.imagePath,
  });

  final String id;
  final String name;
  final double price;
  final bool isActive;
  final bool isAvailable;
  final String slug;
  final String? imagePath;

  factory FavoriteDish.fromJson(Map<String, dynamic> json) => FavoriteDish(
    id: asString(json['id']),
    name: asString(json['name']),
    price: asDouble(json['base_price']),
    isActive: asBool(json['is_active']),
    isAvailable: asBool(json['is_available']),
    slug: asString(json['slug']),
    imagePath: asStringOrNull(json['thumbnail_path']),
  );
}

class ReferralSummary {
  const ReferralSummary({
    required this.code,
    required this.sharePath,
    required this.programActive,
    required this.attributedCount,
    required this.qualifiedCount,
    required this.rewardedCount,
    required this.referrals,
    this.terms,
  });

  final String code;
  final String sharePath;
  final bool programActive;
  final int attributedCount;
  final int qualifiedCount;
  final int rewardedCount;
  final ReferralRewardTerms? terms;
  final List<ReferralActivity> referrals;

  factory ReferralSummary.fromJson(Map<String, dynamic> json) =>
      ReferralSummary(
        code: asString(json['code']),
        sharePath: asString(json['share_path']),
        programActive: asBool(json['program_active']),
        attributedCount: asInt(json['attributed_count']),
        qualifiedCount: asInt(json['qualified_count']),
        rewardedCount: asInt(json['rewarded_count']),
        terms: asMapOrNull(json['terms']) == null
            ? null
            : ReferralRewardTerms.fromJson(asMap(json['terms'])),
        referrals: asList(json['referrals'], ReferralActivity.fromJson),
      );
}

class ReferralRewardTerms {
  const ReferralRewardTerms({
    required this.referrerReward,
    required this.referredReward,
    required this.minimumOrderAmount,
    this.rewardExpiryDays,
  });

  final double referrerReward;
  final double referredReward;
  final double minimumOrderAmount;
  final int? rewardExpiryDays;

  factory ReferralRewardTerms.fromJson(Map<String, dynamic> json) =>
      ReferralRewardTerms(
        referrerReward: asDouble(json['referrer_reward']),
        referredReward: asDouble(json['referred_reward']),
        minimumOrderAmount: asDouble(json['minimum_order_amount']),
        rewardExpiryDays: asIntOrNull(json['reward_expiry_days']),
      );
}

class ReferralActivity {
  const ReferralActivity({
    required this.status,
    required this.attributedAt,
    required this.referrerReward,
    this.qualifiedAt,
    this.rewardedAt,
  });

  final String status;
  final DateTime? attributedAt;
  final DateTime? qualifiedAt;
  final DateTime? rewardedAt;
  final double referrerReward;

  factory ReferralActivity.fromJson(Map<String, dynamic> json) =>
      ReferralActivity(
        status: asString(json['status']),
        attributedAt: asDate(json['attributed_at']),
        qualifiedAt: asDate(json['qualified_at']),
        rewardedAt: asDate(json['rewarded_at']),
        referrerReward: asDouble(json['reward_amount']),
      );
}

class GrowthRepository {
  const GrowthRepository(this._api);

  final ApiClient _api;

  Future<List<OutletSummary>> outlets() async {
    final result = await _api.rpc<dynamic>(
      'public_outlets',
      dedupeKey: 'public_outlets',
    );
    return (result as List)
        .whereType<Map>()
        .map((row) => OutletSummary.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<OutletOption>> serviceableOutlets({
    required double latitude,
    required double longitude,
  }) async {
    final result = await _api.rpc<dynamic>(
      'serviceable_outlets',
      params: {'p_latitude': latitude, 'p_longitude': longitude},
    );
    return (result as List).whereType<Map>().map((raw) {
      final row = Map<String, dynamic>.from(raw);
      final serviceability = asMap(row['serviceability']);
      final outlet = OutletSummary.fromJson({
        ...row,
        'ordering': asMap(serviceability['branch']),
      });
      return OutletOption(
        outlet: outlet,
        serviceable: asBool(serviceability['serviceable']),
        reason: asStringOrNull(serviceability['message']),
      );
    }).toList();
  }

  Future<void> setPreferredBranch(String branchId) async {
    await _api.rpc<dynamic>(
      'set_preferred_branch',
      params: {'p_branch_id': branchId},
    );
  }

  Future<List<FavoriteDish>> favorites({
    required String? branchId,
    required String locale,
  }) async {
    final result = await _api.rpc<dynamic>(
      'my_favorites',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
        'p_locale': locale,
      },
      dedupeKey: 'my_favorites:$branchId:$locale',
    );
    return (result as List)
        .whereType<Map>()
        .map((row) => FavoriteDish.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> setFavorite(String productId, bool favorite) async {
    await _api.rpc<dynamic>(
      'set_my_favorite',
      params: {'p_product_id': productId, 'p_favorite': favorite},
    );
  }

  Future<ReferralSummary> referralSummary() async {
    final result = await _api.rpc<dynamic>(
      'my_referral_summary',
      dedupeKey: 'my_referral_summary',
    );
    return ReferralSummary.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<void> attributeReferral(String code) async {
    await _api.rpc<dynamic>(
      'attribute_referral',
      params: {'p_code': code.trim()},
    );
  }
}
