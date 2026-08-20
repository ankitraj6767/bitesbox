/// Defensive JSON coercion.
///
/// Postgres returns `numeric` as a JSON number, but PostgREST can serialise very
/// large numerics as strings, and a nullable column arrives as `null`. Every
/// model reads through these helpers so a single unexpected type can never crash
/// a screen mid-order.
library;

double asDouble(Object? value, [double fallback = 0]) => switch (value) {
      num n => n.toDouble(),
      String s => double.tryParse(s) ?? fallback,
      _ => fallback,
    };

double? asDoubleOrNull(Object? value) => switch (value) {
      num n => n.toDouble(),
      String s => double.tryParse(s),
      _ => null,
    };

int asInt(Object? value, [int fallback = 0]) => switch (value) {
      num n => n.toInt(),
      String s => int.tryParse(s) ?? fallback,
      _ => fallback,
    };

int? asIntOrNull(Object? value) => switch (value) {
      num n => n.toInt(),
      String s => int.tryParse(s),
      _ => null,
    };

bool asBool(Object? value, {bool fallback = false}) => switch (value) {
      bool b => b,
      'true' => true,
      'false' => false,
      num n => n != 0,
      _ => fallback,
    };

String asString(Object? value, [String fallback = '']) =>
    value is String ? value : (value?.toString() ?? fallback);

String? asStringOrNull(Object? value) {
  if (value is! String) return null;
  return value.isEmpty ? null : value;
}

DateTime? asDate(Object? value) {
  if (value is DateTime) return value;
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

List<String> asStringList(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

/// A nested object, or an empty map.
Map<String, dynamic> asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

/// A nested object, or null when absent — used where "no rider yet" matters.
Map<String, dynamic>? asMapOrNull(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

/// Maps a JSON array of objects through [build], skipping anything malformed.
List<T> asList<T>(Object? value, T Function(Map<String, dynamic> json) build) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => build(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}
