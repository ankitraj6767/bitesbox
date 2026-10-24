class TastePassportProfile {
  const TastePassportProfile({
    this.foodTypes = const [],
    this.maxSpice,
    this.categoryIds = const [],
    this.priceCeiling,
    this.hasProfile = false,
  });

  final List<String> foodTypes;
  final String? maxSpice;
  final List<String> categoryIds;
  final double? priceCeiling;
  final bool hasProfile;

  factory TastePassportProfile.fromJson(Map<String, dynamic> json) =>
      TastePassportProfile(
        foodTypes: _stringList(json['food_types']),
        maxSpice: json['max_spice'] as String?,
        categoryIds: _stringList(json['category_ids']),
        priceCeiling: _doubleOrNull(json['price_ceiling']),
        hasProfile: json['has_profile'] as bool? ?? false,
      );
}

List<String> _stringList(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

double? _doubleOrNull(Object? value) => switch (value) {
  num number => number.toDouble(),
  String text => double.tryParse(text),
  _ => null,
};
