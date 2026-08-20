import '../../../shared/json.dart';

/// Saved delivery addresses and the serviceability verdict for a location.
///
/// Serviceability is never decided on the device: `public.check_serviceability()`
/// resolves the zone polygon, the distance and the fee, so a spoofed coordinate
/// still cannot unlock an unserviced area.

class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.addressLine1,
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
    this.label = 'HOME',
    this.addressLine2,
    this.landmark,
    this.area,
    this.postalCode,
    this.contactName,
    this.contactPhone,
    this.deliveryInstructions,
    this.formattedAddress,
    this.isDefault = false,
    this.isServiceable = true,
    this.distanceKm,
    this.zoneId,
  });

  final String id;
  final String addressLine1;
  final String city;
  final String state;
  final double latitude;
  final double longitude;
  final String label;
  final String? addressLine2;
  final String? landmark;
  final String? area;
  final String? postalCode;
  final String? contactName;
  final String? contactPhone;
  final String? deliveryInstructions;
  final String? formattedAddress;
  final bool isDefault;
  final bool isServiceable;
  final double? distanceKm;
  final String? zoneId;

  /// HOME / WORK / OTHER, title-cased for display.
  String get labelText => switch (label) {
        'HOME' => 'Home',
        'WORK' => 'Work',
        'HOTEL' => 'Hotel',
        _ => 'Other',
      };

  String get singleLine => [
        addressLine1,
        addressLine2,
        landmark,
        area,
        city,
        postalCode,
      ].where((part) => part != null && part.trim().isNotEmpty).join(', ');

  /// The second line on an address card: everything after the house/street.
  String get secondary => [
        addressLine2,
        landmark,
        area,
        city,
        postalCode,
      ].where((part) => part != null && part.trim().isNotEmpty).join(', ');

  factory CustomerAddress.fromJson(Map<String, dynamic> json) => CustomerAddress(
        id: asString(json['id']),
        addressLine1: asString(json['address_line1']),
        city: asString(json['city']),
        state: asString(json['state']),
        latitude: asDouble(json['latitude']),
        longitude: asDouble(json['longitude']),
        label: asString(json['label'], 'HOME'),
        addressLine2: asStringOrNull(json['address_line2']),
        landmark: asStringOrNull(json['landmark']),
        area: asStringOrNull(json['area']),
        postalCode: asStringOrNull(json['postal_code']),
        contactName: asStringOrNull(json['contact_name']),
        contactPhone: asStringOrNull(json['contact_phone']),
        deliveryInstructions: asStringOrNull(json['delivery_instructions']),
        formattedAddress: asStringOrNull(json['formatted_address']),
        isDefault: asBool(json['is_default']),
        isServiceable: asBool(json['is_serviceable'], fallback: true),
        distanceKm: asDoubleOrNull(json['distance_km']),
        zoneId: asStringOrNull(json['resolved_zone_id']) ?? asStringOrNull(json['zone_id']),
      );
}

/// Whether we deliver to a coordinate, and on what terms.
class Serviceability {
  const Serviceability({
    required this.serviceable,
    this.reasonCode,
    this.message,
    this.branchId,
    this.zoneId,
    this.zoneName,
    this.distanceKm,
    this.maxDistanceKm,
    this.deliveryFee,
    this.minOrderAmount,
    this.freeDeliveryThreshold,
    this.etaMinutes,
    this.codEnabled = true,
    this.maxCodAmount,
    this.pickupAvailable = false,
  });

  final bool serviceable;
  final String? reasonCode;
  final String? message;
  final String? branchId;
  final String? zoneId;
  final String? zoneName;
  final double? distanceKm;
  final double? maxDistanceKm;
  final double? deliveryFee;
  final double? minOrderAmount;
  final double? freeDeliveryThreshold;
  final int? etaMinutes;
  final bool codEnabled;
  final double? maxCodAmount;

  /// Offered as the alternative when delivery is impossible.
  final bool pickupAvailable;

  bool get isTooFar => reasonCode == 'OUTSIDE_MAX_DISTANCE';

  factory Serviceability.fromJson(Map<String, dynamic> json) => Serviceability(
        serviceable: asBool(json['serviceable']),
        reasonCode: asStringOrNull(json['reason_code']),
        message: asStringOrNull(json['message']),
        branchId: asStringOrNull(json['branch_id']),
        zoneId: asStringOrNull(json['zone_id']),
        zoneName: asStringOrNull(json['zone_name']),
        distanceKm: asDoubleOrNull(json['distance_km']),
        maxDistanceKm: asDoubleOrNull(json['max_distance_km']),
        deliveryFee: asDoubleOrNull(json['delivery_fee']),
        minOrderAmount: asDoubleOrNull(json['min_order_amount']),
        freeDeliveryThreshold: asDoubleOrNull(json['free_delivery_threshold']),
        etaMinutes: asIntOrNull(json['eta_minutes']),
        codEnabled: asBool(json['cod_enabled'], fallback: true),
        maxCodAmount: asDoubleOrNull(json['max_cod_amount']),
        pickupAvailable: asBool(json['pickup_available']),
      );
}

/// Result of saving an address: the row plus its serviceability verdict.
class AddressSaveResult {
  const AddressSaveResult({required this.address, required this.serviceability});

  final CustomerAddress address;
  final Serviceability serviceability;

  factory AddressSaveResult.fromJson(Map<String, dynamic> json) => AddressSaveResult(
        address: CustomerAddress.fromJson(asMap(json['address'])),
        serviceability: Serviceability.fromJson(asMap(json['serviceability'])),
      );
}
