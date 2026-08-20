import '../../../core/network/api_client.dart';
import 'address_models.dart';

/// Saved addresses and serviceability checks.
class AddressRepository {
  const AddressRepository(this._api);

  final ApiClient _api;

  /// RLS restricts this to the signed-in customer's own rows.
  Future<List<CustomerAddress>> list() async {
    final rows = await _api.select(
      'addresses',
      columns: '''
        id, label, address_line1, address_line2, landmark, area, city, state,
        postal_code, latitude, longitude, contact_name, contact_phone,
        delivery_instructions, formatted_address, is_default, is_serviceable,
        distance_km, resolved_zone_id
      ''',
    );

    final addresses = rows.map(CustomerAddress.fromJson).toList();

    // Default first, then most recently useful. Sorting here rather than in the
    // query keeps the select simple and the ordering identical everywhere.
    addresses.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      if (a.isServiceable != b.isServiceable) return a.isServiceable ? -1 : 1;
      return a.labelText.compareTo(b.labelText);
    });

    return addresses;
  }

  /// Asks the server whether we deliver to a coordinate, and on what terms.
  Future<Serviceability> check({
    required double latitude,
    required double longitude,
    String? branchId,
    double orderAmount = 0,
  }) async {
    final result = await _api.rpc<dynamic>(
      'check_serviceability',
      params: {
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_order_amount': orderAmount,
        if (branchId != null) 'p_branch_id': branchId,
      },
    );

    return Serviceability.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// Creates or updates an address. Passing [id] edits in place.
  ///
  /// The zone, distance and serviceability flag on the saved row are all decided
  /// server-side from the coordinates.
  Future<AddressSaveResult> save({
    required String addressLine1,
    required String city,
    required String state,
    required double latitude,
    required double longitude,
    String? id,
    String label = 'HOME',
    String? addressLine2,
    String? landmark,
    String? area,
    String? postalCode,
    String? contactName,
    String? contactPhone,
    String? deliveryInstructions,
    String? formattedAddress,
    String locationSource = 'GPS',
    bool isDefault = false,
  }) async {
    final result = await _api.rpc<dynamic>(
      'upsert_address',
      params: {
        'p_address_line1': addressLine1.trim(),
        'p_city': city.trim(),
        'p_state': state.trim(),
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_label': label,
        'p_location_source': locationSource,
        'p_is_default': isDefault,
        if (id != null) 'p_id': id,
        if (_present(addressLine2)) 'p_address_line2': addressLine2!.trim(),
        if (_present(landmark)) 'p_landmark': landmark!.trim(),
        if (_present(area)) 'p_area': area!.trim(),
        if (_present(postalCode)) 'p_postal_code': postalCode!.trim(),
        if (_present(contactName)) 'p_contact_name': contactName!.trim(),
        if (_present(contactPhone)) 'p_contact_phone': contactPhone!.trim(),
        if (_present(deliveryInstructions))
          'p_delivery_instructions': deliveryInstructions!.trim(),
        if (_present(formattedAddress)) 'p_formatted_address': formattedAddress!.trim(),
      },
    );

    return AddressSaveResult.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<void> remove(String id) async {
    await _api.rpc<dynamic>('delete_address', params: {'p_id': id});
  }

  /// Re-resolves the zone for a saved address — used after the operator changes
  /// delivery boundaries.
  Future<Serviceability> refresh(String id) async {
    final result = await _api.rpc<dynamic>(
      'refresh_address_serviceability',
      params: {'p_address_id': id},
    );

    return Serviceability.fromJson(Map<String, dynamic>.from(result as Map));
  }

  static bool _present(String? value) => value != null && value.trim().isNotEmpty;
}
