import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/customer_copy.dart';

import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/states.dart';
import '../data/address_models.dart';
import '../providers/cart_controller.dart';
import '../providers/customer_providers.dart';

/// Add or edit a delivery address.
///
/// The coordinates are what matter: serviceability, the delivery fee and the ETA
/// are all resolved from them by the server. The customer is shown that verdict
/// before saving, so they never discover at checkout that we do not deliver.
class AddressEditorScreen extends ConsumerStatefulWidget {
  const AddressEditorScreen({this.address, super.key});

  final CustomerAddress? address;

  @override
  ConsumerState<AddressEditorScreen> createState() => _AddressEditorScreenState();
}

class _AddressEditorScreenState extends ConsumerState<AddressEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _landmark = TextEditingController();
  final _area = TextEditingController();
  final _city = TextEditingController(text: 'Bakhtiyarpur');
  final _state = TextEditingController(text: 'Bihar');
  final _postalCode = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  final _instructions = TextEditingController();

  String _label = 'HOME';
  bool _isDefault = false;
  double? _latitude;
  double? _longitude;

  Serviceability? _serviceability;
  bool _locating = false;
  bool _checking = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final existing = widget.address;
    if (existing != null) {
      _line1.text = existing.addressLine1;
      _line2.text = existing.addressLine2 ?? '';
      _landmark.text = existing.landmark ?? '';
      _area.text = existing.area ?? '';
      _city.text = existing.city;
      _state.text = existing.state;
      _postalCode.text = existing.postalCode ?? '';
      _contactName.text = existing.contactName ?? '';
      _contactPhone.text = existing.contactPhone ?? '';
      _instructions.text = existing.deliveryInstructions ?? '';
      _label = existing.label;
      _isDefault = existing.isDefault;
      _latitude = existing.latitude;
      _longitude = existing.longitude;

      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _useCurrentLocation());
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _line1,
      _line2,
      _landmark,
      _area,
      _city,
      _state,
      _postalCode,
      _contactName,
      _contactPhone,
      _instructions,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _hasLocation => _latitude != null && _longitude != null;

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          AppFeedback.showInfo(context, context.customerText("Turn on location services to pin your address."));
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          AppFeedback.showInfo(
            context,
            'Location permission is off. You can still type your address.',
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      await _check();
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _check() async {
    if (!_hasLocation) return;
    setState(() => _checking = true);

    try {
      final result = await ref.read(addressRepositoryProvider).check(
            latitude: _latitude!,
            longitude: _longitude!,
          );

      if (mounted) setState(() => _serviceability = result);
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_hasLocation) {
      AppFeedback.showInfo(
        context,
        'We need to pin your location so the kitchen knows where to send your food.',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final result = await ref.read(addressRepositoryProvider).save(
            id: widget.address?.id,
            addressLine1: _line1.text,
            addressLine2: _line2.text,
            landmark: _landmark.text,
            area: _area.text,
            city: _city.text,
            state: _state.text,
            postalCode: _postalCode.text,
            contactName: _contactName.text,
            contactPhone: _contactPhone.text,
            deliveryInstructions: _instructions.text,
            latitude: _latitude!,
            longitude: _longitude!,
            label: _label,
            isDefault: _isDefault,
          );

      if (!mounted) return;
      ref.invalidate(addressesProvider);

      // Selecting it immediately is almost always what the customer wants next.
      if (result.serviceability.serviceable) {
        ref.read(selectedAddressIdProvider.notifier).state = result.address.id;
        try {
          await ref.read(cartProvider.notifier).setAddress(result.address.id);
        } on Exception {
          // The cart may be empty; saving the address is still a success.
        }
      }

      if (!mounted) return;
      AppFeedback.showSuccess(
        context,
        result.serviceability.serviceable
            ? 'Address saved.'
            : 'Address saved, but we do not deliver there yet.',
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final isEditing = widget.address != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? context.customerText("Edit address") : context.customerText("Add address"))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _LocationCard(
              hasLocation: _hasLocation,
              latitude: _latitude,
              longitude: _longitude,
              locating: _locating,
              onLocate: _useCurrentLocation,
            ),
            if (_checking) ...[
              const SizedBox(height: 12),
              const SkeletonBox(height: 62, radius: 14),
            ] else if (_serviceability != null) ...[
              const SizedBox(height: 12),
              _ServiceabilityCard(serviceability: _serviceability!),
            ],
            const SizedBox(height: 20),
            Text(
              context.customerText('Save this address as'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: brand.ink,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: const [
                ('HOME', 'Home'),
                ('WORK', 'Work'),
                ('HOTEL', 'Hotel'),
                ('OTHER', 'Other'),
              ]
                  .map(
                    (option) => ChoiceChip(
                      label: Text(context.customerText(option.$2)),
                      selected: _label == option.$1,
                      onSelected: (_) => setState(() => _label = option.$1),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _line1,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: context.customerText("House / flat / building *"),
              ),
              validator: (value) => (value ?? '').trim().length < 3
                  ? context.customerText('Please enter the house or building')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _line2,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: context.customerText("Street / road")),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _landmark,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: context.customerText("Landmark"),
                helperText: context.customerText("Helps the delivery partner find you faster"),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _area,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: context.customerText("Area / locality")),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _city,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: context.customerText("City *")),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _postalCode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: context.customerText("PIN code"),
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _state,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: context.customerText("State *")),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            Text(
              context.customerText('Who should we hand the order to?'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: brand.ink,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _contactName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: context.customerText("Contact name"),
                helperText: context.customerText("Leave blank to use your own name"),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactPhone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: context.customerText("Contact number"),
                counterText: '',
                prefixText: '+91 ',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _instructions,
              maxLines: 2,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: context.customerText("Delivery instructions"),
                hintText: context.customerText("Ring the bell twice, leave at the gate…"),
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: _isDefault,
              contentPadding: EdgeInsets.zero,
              title: Text(context.customerText("Make this my default address")),
              onChanged: (value) => setState(() => _isDefault = value),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? context.customerText("Saving…") : context.customerText("Save address")),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.hasLocation,
    required this.latitude,
    required this.longitude,
    required this.locating,
    required this.onLocate,
  });

  final bool hasLocation;
  final double? latitude;
  final double? longitude;
  final bool locating;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Row(
        children: [
          Icon(
            hasLocation ? Icons.my_location_rounded : Icons.location_searching_rounded,
            size: 20,
            color: hasLocation ? brand.success : brand.inkMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.customerText(
                    hasLocation ? 'Location pinned' : 'Pin your location',
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: brand.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasLocation
                      ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
                      : context.customerText(
                          'We use this to check whether we deliver to you.',
                        ),
                  style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: locating ? null : onLocate,
            child: Text(locating ? context.customerText("Locating…") : (hasLocation ? context.customerText("Update") : context.customerText("Use GPS"))),
          ),
        ],
      ),
    );
  }
}

class _ServiceabilityCard extends StatelessWidget {
  const _ServiceabilityCard({required this.serviceability});

  final Serviceability serviceability;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    if (!serviceability.serviceable) {
      return AppNotice(
        tone: NoticeTone.critical,
        icon: Icons.location_off_rounded,
        message: serviceability.message ??
            'We do not deliver to this location yet. You can still order for self pickup.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.success.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.success.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 18, color: brand.success),
              const SizedBox(width: 8),
              Text(
                context.customerText('We deliver here'),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: brand.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              if (serviceability.zoneName != null)
                _Fact(label: context.customerText("Zone"), value: serviceability.zoneName!),
              if (serviceability.distanceKm != null)
                _Fact(
                  label: context.customerText("Distance"),
                  value: Fmt.distance(serviceability.distanceKm),
                ),
              if (serviceability.etaMinutes != null)
                _Fact(
                  label: context.customerText("Typical time"),
                  value: Fmt.duration(serviceability.etaMinutes!),
                ),
              if (serviceability.deliveryFee != null)
                _Fact(
                  label: context.customerText("Delivery fee"),
                  value: serviceability.deliveryFee == 0
                      ? context.customerText("Free")
                      : Fmt.moneySmart(serviceability.deliveryFee),
                ),
              if (serviceability.minOrderAmount != null &&
                  serviceability.minOrderAmount! > 0)
                _Fact(
                  label: context.customerText("Minimum order"),
                  value: Fmt.moneySmart(serviceability.minOrderAmount),
                ),
            ],
          ),
          if (!serviceability.codEnabled) ...[
            const SizedBox(height: 8),
            Text(
              'Cash on delivery is not available in this area.',
              style: TextStyle(fontSize: 12.5, color: brand.warning),
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: brand.inkMuted)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: brand.ink,
          ),
        ),
      ],
    );
  }
}
