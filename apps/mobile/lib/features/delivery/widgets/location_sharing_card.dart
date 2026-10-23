import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brand_tokens.dart';
import '../../../shared/format.dart';
import '../data/delivery_models.dart';
import '../providers/delivery_providers.dart';

/// Makes location consent, service state and the most recent capture visible to
/// the rider throughout an active delivery.
class LocationSharingCard extends ConsumerWidget {
  const LocationSharingCard({
    required this.assignment,
    required this.enabled,
    required this.canEnable,
    super.key,
  });

  final DeliveryAssignment assignment;
  final bool enabled;
  final bool canEnable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final tracking = ref.watch(riderLocationPublisherProvider);
    final fix = ref.watch(riderLastFixProvider);
    final serverFixAt = ref
        .watch(riderDashboardProvider)
        .valueOrNull
        ?.lastLocationAt;
    final publisher = ref.read(riderLocationPublisherProvider.notifier);
    final status = tracking.status;
    final showSettings =
        status == LocationSharingStatus.permissionDenied ||
        status == LocationSharingStatus.permissionRestricted ||
        status == LocationSharingStatus.locationServicesOff;

    final statusCopy = switch (status) {
      LocationSharingStatus.sharing =>
        'Location is being shared for this delivery.',
      LocationSharingStatus.waitingForFix => tracking.message ??
          'Waiting for a fresh GPS fix. The customer will see your location after the server receives it.',
      LocationSharingStatus.stale =>
        tracking.message ?? 'Waiting for a fresh location update.',
      LocationSharingStatus.permissionDenied ||
      LocationSharingStatus.permissionRestricted ||
      LocationSharingStatus.locationServicesOff =>
        tracking.message ?? 'Location sharing needs attention.',
      LocationSharingStatus.networkUnavailable =>
        tracking.message ?? 'Waiting for network access.',
      LocationSharingStatus.requestingPermission => 'Checking location access…',
      LocationSharingStatus.unavailable =>
        tracking.message ?? 'Location sharing is unavailable.',
      LocationSharingStatus.idle =>
        enabled
            ? 'Checking the active delivery and location access…'
            : 'Your location is shared with this delivery’s customer only after you turn it on. It stops when the delivery ends.',
    };

    final statusColor = switch (status) {
      LocationSharingStatus.sharing => brand.success,
      LocationSharingStatus.permissionDenied ||
      LocationSharingStatus.permissionRestricted ||
      LocationSharingStatus.locationServicesOff ||
      LocationSharingStatus.unavailable => brand.error,
      LocationSharingStatus.stale ||
      LocationSharingStatus.networkUnavailable ||
      LocationSharingStatus.waitingForFix => brand.warning,
      _ => brand.inkMuted,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.my_location_rounded, size: 19, color: statusColor),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  enabled
                      ? 'Delivery location sharing'
                      : 'Share delivery location',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: brand.ink,
                  ),
                ),
              ),
              if (enabled && status == LocationSharingStatus.sharing)
                const Icon(Icons.circle, size: 9, color: Colors.green),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            statusCopy,
            style: TextStyle(fontSize: 12.5, height: 1.4, color: statusColor),
          ),
          if (fix?.recordedAt != null || serverFixAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Last GPS update ${Fmt.relative(fix?.recordedAt ?? serverFixAt)}',
              style: TextStyle(fontSize: 11.5, color: brand.inkMuted),
            ),
          ],
          if (enabled && fix == null && serverFixAt == null) ...[
            const SizedBox(height: 4),
            Text(
              'No location fix has reached the server yet.',
              style: TextStyle(fontSize: 11.5, color: brand.inkMuted),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!enabled && canEnable)
                FilledButton.icon(
                  onPressed:
                      status == LocationSharingStatus.requestingPermission
                      ? null
                      : publisher.startSharing,
                  icon: const Icon(Icons.location_on_outlined, size: 18),
                  label: const Text('Enable sharing'),
                ),
              if (!enabled && !canEnable)
                Text(
                  'Sharing becomes available when this is your current delivery.',
                  style: TextStyle(fontSize: 11.5, color: brand.inkMuted),
                ),
              if (showSettings)
                OutlinedButton.icon(
                  onPressed: status == LocationSharingStatus.locationServicesOff
                      ? publisher.openLocationSettings
                      : publisher.openPermissionSettings,
                  icon: const Icon(Icons.settings_outlined, size: 17),
                  label: const Text('Open settings'),
                ),
              if (enabled)
                TextButton(
                  onPressed: publisher.stopSharing,
                  child: const Text('Stop sharing'),
                ),
            ],
          ),
          if (!enabled && canEnable)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Background tracking runs only during this delivery. Android shows an ongoing notification; iPhone shows its location indicator. GPS access is optional and does not affect pickup, cash collection, delivery completion or failure reporting.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: brand.inkMuted,
                ),
              ),
            ),
          Semantics(
            label: 'Assignment ${assignment.statusLabel}',
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
