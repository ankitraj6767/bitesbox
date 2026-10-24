import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';
import '../data/address_models.dart';
import '../providers/cart_controller.dart';
import '../providers/customer_providers.dart';

/// Saved addresses.
///
/// An address outside our delivery area stays in the list, clearly marked. Deleting
/// it would only make the customer re-enter it and get the same answer.
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final addresses = ref.watch(addressesProvider);
    final selectedId = ref.watch(cartQuoteProvider).addressId;

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery addresses')),
      body: AsyncValueView<List<CustomerAddress>>(
        value: addresses,
        onRetry: () => ref.invalidate(addressesProvider),
        data: (list) {
          if (list.isEmpty) {
            return AppEmptyState(
              title: 'No saved addresses',
              message: 'Add where you would like your food delivered.',
              icon: Icons.location_off_outlined,
              action: FilledButton.icon(
                onPressed: () => context.push(Routes.addressEditor),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add an address'),
              ),
            );
          }

          return RefreshIndicator(
            color: brand.primary,
            onRefresh: () async {
              ref.invalidate(addressesProvider);
              await ref.read(addressesProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _AddressCard(
                address: list[index],
                isSelected: list[index].id == selectedId,
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.addressEditor),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add address'),
      ),
    );
  }
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard({required this.address, required this.isSelected});

  final CustomerAddress address;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final usable = address.isServiceable;

    return Container(
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(
          color: isSelected ? brand.primary : brand.hairline,
          width: isSelected ? 1.6 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: usable ? () => _select(context, ref) : null,
            borderRadius: BorderRadius.vertical(top: Radius.circular(brand.radiusMd)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _iconFor(address.label),
                    size: 20,
                    color: usable ? brand.primary : brand.inkMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              address.labelText,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: brand.ink,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (address.isDefault)
                              AppPill(
                                label: 'Default',
                                dense: true,
                                background: brand.surfaceMuted,
                              ),
                            if (isSelected) ...[
                              const SizedBox(width: 6),
                              AppPill(
                                label: 'Selected',
                                dense: true,
                                background: brand.primary.withValues(alpha: 0.12),
                                foreground: brand.primary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          address.singleLine,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: brand.inkMuted,
                          ),
                        ),
                        if (address.distanceKm != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            '${Fmt.distance(address.distanceKm)} from our kitchen',
                            style: TextStyle(fontSize: 12, color: brand.inkMuted),
                          ),
                        ],
                        if (!usable) ...[
                          const SizedBox(height: 8),
                          AppNotice(
                            tone: NoticeTone.caution,
                            message: 'We do not deliver here yet. Self pickup is still available.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: brand.hairline),
          Row(
            children: [
              Expanded(
                child: _Action(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onTap: () => context.push(Routes.addressEditor, extra: address),
                ),
              ),
              Container(width: 1, height: 42, color: brand.hairline),
              Expanded(
                child: _Action(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  destructive: true,
                  onTap: () => _delete(context, ref),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String label) => switch (label) {
        'HOME' => Icons.home_outlined,
        'WORK' => Icons.work_outline_rounded,
        'HOTEL' => Icons.hotel_outlined,
        _ => Icons.location_on_outlined,
      };

  /// Selecting an address re-prices the cart: the zone decides the fee, the ETA
  /// and whether cash on delivery is even allowed.
  Future<void> _select(BuildContext context, WidgetRef ref) async {
    ref.read(selectedAddressIdProvider.notifier).state = address.id;

    try {
      await ref.read(cartProvider.notifier).setAddress(address.id);
      if (!context.mounted) return;
      AppFeedback.showSuccess(context, 'Delivering to ${address.labelText}.');
      context.pop();
    } catch (error) {
      if (context.mounted) AppFeedback.showError(context, error);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppFeedback.confirm(
      context,
      title: 'Delete this address?',
      message: address.singleLine,
      confirmLabel: 'Delete',
      destructive: true,
    );

    if (!confirmed) return;

    try {
      await ref.read(addressRepositoryProvider).remove(address.id);
      ref.invalidate(addressesProvider);
      if (context.mounted) AppFeedback.showSuccess(context, 'Address deleted.');
    } catch (error) {
      if (context.mounted) AppFeedback.showError(context, error);
    }
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final colour = destructive ? brand.error : brand.ink;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: colour),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: colour,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
