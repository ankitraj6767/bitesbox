import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/feedback.dart';
import '../providers/cart_controller.dart';
import '../providers/customer_providers.dart';
import '../data/growth_repository.dart';

class CustomerOutletPicker extends ConsumerWidget {
  const CustomerOutletPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final outlets =
        ref.watch(outletsProvider).valueOrNull ?? const <OutletSummary>[];
    final branchId = ref.watch(activeBranchIdProvider);
    final selected = outlets
        .where((outlet) => outlet.id == branchId)
        .firstOrNull;
    if (outlets.length < 2) return const SizedBox.shrink();
    final brand = context.brand;
    return InkWell(
      onTap: () => _open(context, ref, outlets),
      borderRadius: BorderRadius.circular(brand.radiusSm),
      child: Padding(
        padding: const EdgeInsets.only(left: 24, top: 1, bottom: 6),
        child: Row(
          children: [
            Icon(Icons.storefront_outlined, size: 14, color: brand.primary),
            const SizedBox(width: 5),
            Text(
              '${l10n.outlet}: ',
              style: TextStyle(fontSize: 11.5, color: brand.inkMuted),
            ),
            Flexible(
              child: Text(
                selected?.name ?? l10n.chooseOutlet,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: brand.ink,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 16, color: brand.inkMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    List<OutletSummary> outlets,
  ) async {
    final address = ref.read(selectedAddressProvider);
    List<OutletOption>? serviceable;
    if (address != null) {
      try {
        serviceable = await ref
            .read(growthRepositoryProvider)
            .serviceableOutlets(
              latitude: address.latitude,
              longitude: address.longitude,
            );
      } catch (error) {
        if (context.mounted) AppFeedback.showError(context, error);
        return;
      }
    }
    if (!context.mounted) return;
    final selectedId = ref.read(activeBranchIdProvider);
    final session = ref.read(currentSessionProvider);
    final quote = ref.read(cartProvider).valueOrNull;
    final brand = context.brand;
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chooseOutlet,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address == null
                    ? l10n.outletPickerBrowsingHint
                    : l10n.outletPickerAddressHint,
                style: TextStyle(fontSize: 13, color: brand.inkMuted),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: outlets.length,
                  itemBuilder: (context, index) {
                    final outlet = outlets[index];
                    final result = serviceable
                        ?.where((option) => option.outlet.id == outlet.id)
                        .firstOrNull;
                    final pickupSupported =
                        outlet.serviceMode == 'PICKUP' ||
                        outlet.serviceMode == 'BOTH';
                    final allowed =
                        (result?.serviceable ?? true) || pickupSupported;
                    final isSelected = outlet.id == selectedId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      enabled: allowed,
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isSelected ? brand.primary : brand.inkMuted,
                      ),
                      title: Text(
                        outlet.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        !allowed
                            ? (result?.reason ?? l10n.unavailableAtOutlet)
                            : '${outlet.city} · ${result?.serviceable == false && pickupSupported ? l10n.pickupOnly : (outlet.acceptingOrders ? l10n.takingOrders : (outlet.reasonCode ?? l10n.currentlyClosed))}',
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: brand.success,
                            )
                          : null,
                      onTap: !allowed
                          ? null
                          : () async {
                              if (isSelected) {
                                Navigator.of(sheetContext).pop();
                                return;
                              }
                              if ((quote?.unitCount ?? 0) > 0) {
                                final confirmed = await showDialog<bool>(
                                  context: sheetContext,
                                  builder: (dialogContext) => AlertDialog(
                                    title: Text(l10n.switchOutletTitle),
                                    content: Text(l10n.outletChanged),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: Text(l10n.stayAtOutlet),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: Text(l10n.switchOutletAction),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                              }
                              try {
                                if (session.authenticated) {
                                  await ref
                                      .read(growthRepositoryProvider)
                                      .setPreferredBranch(outlet.id);
                                  final profile = ref
                                      .read(currentSessionProvider)
                                      .profile;
                                  if (profile != null) {
                                    ref
                                        .read(sessionProvider.notifier)
                                        .updateProfile(
                                          profile.copyWith(
                                            preferredBranchId: outlet.id,
                                          ),
                                        );
                                  }
                                }
                                ref
                                    .read(
                                      selectedOutletOverrideProvider.notifier,
                                    )
                                    .state = outlet
                                    .id;
                                final preferences =
                                    await SharedPreferences.getInstance();
                                await preferences.setString(
                                  'customer_active_branch',
                                  outlet.id,
                                );
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                                if (context.mounted) {
                                  AppFeedback.showSuccess(
                                    context,
                                    l10n.outletChanged,
                                  );
                                }
                              } catch (error) {
                                if (sheetContext.mounted) {
                                  AppFeedback.showError(sheetContext, error);
                                }
                              }
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
