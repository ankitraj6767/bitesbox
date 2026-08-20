import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/customer/providers/customer_providers.dart';
import '../../features/delivery/providers/delivery_providers.dart';
import '../../shared/widgets/states.dart';
import '../providers/core_providers.dart';
import '../routing/app_router.dart';
import '../theme/brand_tokens.dart';
import 'push_providers.dart';
import 'push_service.dart';

/// Connects push notifications to the running app.
///
/// Wrapped around the router so it is mounted for the whole session. It does
/// three things and no more:
///
///  1. keeps this device registered for the signed-in user;
///  2. shows a tappable in-app banner for a notification that lands while the app
///     is on screen (Android never displays those itself);
///  3. refreshes whatever the notification was about, rather than trusting the
///     payload — a push is a hint that server state moved, not the state itself.
class PushGateway extends ConsumerStatefulWidget {
  const PushGateway({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PushGateway> createState() => _PushGatewayState();
}

class _PushGatewayState extends ConsumerState<PushGateway> {
  @override
  Widget build(BuildContext context) {
    // Owns registration for as long as a user is signed in.
    ref.watch(pushRegistrarProvider);

    ref.listen(pushForegroundProvider, (_, next) {
      final payload = next.valueOrNull;
      if (payload == null) return;

      _refreshFor(payload);
      _showBanner(payload);
    });

    ref.listen(pushOpenedProvider, (_, next) {
      final payload = next.valueOrNull;
      if (payload == null) return;

      _refreshFor(payload);
      _open(payload);
    });

    return widget.child;
  }

  /// Re-reads the affected surfaces so the screen matches the database, not the
  /// notification body.
  void _refreshFor(PushPayload payload) {
    ref.invalidate(notificationsProvider);

    final orderId = payload.orderId;
    if (orderId != null) {
      ref.invalidate(orderDetailProvider(orderId));
      ref.invalidate(activeOrdersProvider);
    }

    // A rider's new-assignment push is the one case where the list itself changed.
    if (payload.event == 'NEW_ASSIGNMENT_RIDER') {
      ref.invalidate(riderDashboardProvider);
    }
  }

  void _showBanner(PushPayload payload) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final brand = context.brand;
    final link = payload.deepLink;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          backgroundColor: brand.ink,
          content: Row(
            children: [
              Icon(_iconFor(payload.event), size: 20, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (payload.title.isNotEmpty)
                      Text(
                        payload.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (payload.body.isNotEmpty)
                      Text(
                        payload.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          action: link == null
              ? null
              : SnackBarAction(
                  label: 'View',
                  textColor: Colors.white,
                  onPressed: () => _open(payload),
                ),
        ),
      );
  }

  void _open(PushPayload payload) {
    final link = payload.deepLink;
    if (link == null) return;

    final session = ref.read(currentSessionProvider);
    // Riders and kitchen staff are locked to their own shells by the router;
    // pushing a customer route would only bounce them back.
    if (session.isRider) return;

    ref.read(goRouterProvider).push(link);
  }

  static IconData _iconFor(String? event) => switch (event) {
        'ORDER_PLACED' || 'ORDER_ACCEPTED' => Icons.receipt_long_rounded,
        'ORDER_PREPARING' => Icons.soup_kitchen_rounded,
        'ORDER_READY' => Icons.shopping_bag_rounded,
        'RIDER_ASSIGNED' || 'NEW_ASSIGNMENT_RIDER' => Icons.two_wheeler_rounded,
        'RIDER_NEARBY' => Icons.near_me_rounded,
        'ORDER_DELIVERED' => Icons.check_circle_rounded,
        'ORDER_CANCELLED' => Icons.cancel_rounded,
        'REFUND_INITIATED' || 'REFUND_COMPLETED' => Icons.currency_rupee_rounded,
        'PROMOTION' || 'OFFER' => Icons.local_offer_rounded,
        _ => Icons.notifications_rounded,
      };
}

/// Shown on the notifications screen when push is switched off at the OS level,
/// so a customer understands why their phone stays quiet.
class PushDisabledNotice extends ConsumerWidget {
  const PushDisabledNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registered = ref.watch(pushRegistrarProvider).valueOrNull != null;
    if (registered) return const SizedBox.shrink();

    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: AppNotice(
        tone: NoticeTone.info,
        icon: Icons.notifications_off_outlined,
        message: 'Push notifications are switched off for this app. Order updates '
            'still appear here and on the tracking screen.',
      ),
    );
  }
}
