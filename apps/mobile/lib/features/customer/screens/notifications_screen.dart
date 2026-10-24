import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/customer_copy.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/states.dart';
import '../data/account_models.dart';
import '../providers/customer_providers.dart';

/// In-app notifications: order updates, offers and support replies.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markingAllRead = false;
  final Set<String> _optimisticallyRead = <String>{};

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final notifications = ref.watch(notificationsProvider);
    final unread = notifications.maybeWhen(
      data: (items) => items
          .where(
            (item) => item.isUnread && !_optimisticallyRead.contains(item.id),
          )
          .length,
      orElse: () => 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.customerText("Notifications")),
        actions: [
          if (unread > 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IconButton(
                onPressed: _markingAllRead ? null : _markAllRead,
                icon: _markingAllRead
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all_rounded),
                tooltip: context.customerText("Mark all as read"),
              ),
            ),
        ],
      ),
      body: AsyncValueView<List<AppNotificationItem>>(
        value: notifications,
        onRetry: () => ref.invalidate(notificationsProvider),
        data: (list) {
          if (list.isEmpty) {
            return AppEmptyState(
              title: context.customerText("No notifications"),
              message: context.customerText("Order updates and offers will appear here."),
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
              itemBuilder: (context, index) {
                final item = list[index];
                return _NotificationTile(
                  item: item,
                  isUnread:
                      item.isUnread && !_optimisticallyRead.contains(item.id),
                  onTap: () => _open(item),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _markAllRead() async {
    if (_markingAllRead) return;
    final current = ref
        .read(notificationsProvider)
        .maybeWhen(
          data: (items) => items,
          orElse: () => const <AppNotificationItem>[],
        );
    final ids = current
        .where((item) => item.isUnread)
        .map((item) => item.id)
        .toSet();
    setState(() {
      _markingAllRead = true;
      _optimisticallyRead.addAll(ids);
    });

    try {
      final count = await ref
          .read(accountRepositoryProvider)
          .markNotificationsRead();
      if (!mounted) return;

      // The RPC is authoritative. Refresh the list, but don't undo the
      // optimistic state based on an immediate, potentially stale readback.
      ref.invalidate(notificationsProvider);

      if (mounted) {
        AppFeedback.showSuccess(
          context,
          count == 0
              ? 'All notifications are already read'
              : '$count notification${count == 1 ? '' : 's'} marked as read',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _optimisticallyRead.removeAll(ids));
        ref.invalidate(notificationsProvider);
        AppFeedback.showError(context, error);
      }
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
    }
  }

  Future<void> _open(AppNotificationItem item) async {
    if (item.isUnread && !_optimisticallyRead.contains(item.id)) {
      setState(() => _optimisticallyRead.add(item.id));
      try {
        await ref
            .read(accountRepositoryProvider)
            .markNotificationsRead(ids: [item.id]);
        if (!mounted) return;
        ref.invalidate(notificationsProvider);
      } catch (error) {
        if (mounted) {
          setState(() => _optimisticallyRead.remove(item.id));
          ref.invalidate(notificationsProvider);
          AppFeedback.showError(context, error);
        }
      }
    }

    if (!mounted) return;
    if (item.orderId != null) context.push(Routes.order(item.orderId!));
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.isUnread,
    required this.onTap,
  });

  final AppNotificationItem item;
  final bool isUnread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isUnread ? brand.primary.withValues(alpha: 0.035) : null,
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
              child: Icon(
                _iconFor(item.event),
                size: 17,
                color: brand.inkMuted,
              ),
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
                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
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
            if (isUnread)
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
}
