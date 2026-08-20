import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/states.dart';
import '../data/account_models.dart';
import '../providers/customer_providers.dart';

/// In-app notifications: order updates, offers and support replies.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => _markAllRead(context, ref),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: AsyncValueView<List<AppNotificationItem>>(
        value: notifications,
        onRetry: () => ref.invalidate(notificationsProvider),
        data: (list) {
          if (list.isEmpty) {
            return const AppEmptyState(
              title: 'No notifications',
              message: 'Order updates and offers will appear here.',
              icon: Icons.notifications_none_rounded,
            );
          }

          return RefreshIndicator(
            color: brand.primary,
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              await ref.read(notificationsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: brand.hairline,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) => _NotificationTile(item: list[index]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(accountRepositoryProvider).markNotificationsRead();
      ref.invalidate(notificationsProvider);
    } catch (error) {
      if (context.mounted) AppFeedback.showError(context, error);
    }
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});

  final AppNotificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;

    return InkWell(
      onTap: () => _open(context, ref),
      child: Container(
        color: item.isUnread ? brand.primary.withValues(alpha: 0.035) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: brand.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(_iconFor(item.event), size: 17, color: brand.inkMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: item.isUnread ? FontWeight.w700 : FontWeight.w600,
                      color: brand.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.body,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: brand.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    Fmt.relative(item.createdAt),
                    style: TextStyle(fontSize: 11.5, color: brand.inkMuted),
                  ),
                ],
              ),
            ),
            if (item.isUnread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, left: 8),
                decoration: BoxDecoration(
                  color: brand.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String? event) {
    final value = event ?? '';
    if (value.contains('REFUND')) return Icons.currency_rupee_rounded;
    if (value.contains('DELIVER') || value.contains('RIDER')) {
      return Icons.delivery_dining_rounded;
    }
    if (value.contains('ORDER')) return Icons.receipt_long_rounded;
    if (value.contains('PROMO') || value.contains('CAMPAIGN')) {
      return Icons.local_offer_rounded;
    }
    if (value.contains('SUPPORT')) return Icons.support_agent_rounded;
    return Icons.notifications_rounded;
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (item.isUnread) {
      try {
        await ref
            .read(accountRepositoryProvider)
            .markNotificationsRead(ids: [item.id]);
        ref.invalidate(notificationsProvider);
      } on Exception {
        // Marking read is a convenience; never block navigation on it.
      }
    }

    if (!context.mounted) return;
    if (item.orderId != null) context.push(Routes.order(item.orderId!));
  }
}
