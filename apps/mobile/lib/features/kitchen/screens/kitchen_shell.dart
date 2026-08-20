import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/push_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../customer/data/cart_models.dart' show BranchState;
import '../data/kitchen_repository.dart';
import '../providers/kitchen_providers.dart';

/// The kitchen tablet frame: store state, a queue/availability switch, and the
/// branch open-close control.
///
/// Designed for a device propped up in a hot, bright room: large targets, high
/// contrast, and the counts always visible.
class KitchenShell extends ConsumerWidget {
  const KitchenShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final session = ref.watch(currentSessionProvider);
    final queue = ref.watch(kitchenQueueProvider).valueOrNull;
    final counts = ref.watch(kitchenCountsProvider);
    final location = GoRouterState.of(context).uri.path;

    final branch = queue?.branch ?? const BranchState();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(branch.name, style: const TextStyle(fontSize: 17)),
            Text(
              session.profile?.fullName ?? session.primaryRole.label,
              style: TextStyle(fontSize: 12, color: brand.inkMuted),
            ),
          ],
        ),
        actions: [
          _StoreStatePill(branch: branch),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _openStatusSheet(context, ref, branch),
            icon: const Icon(Icons.storefront_rounded),
            tooltip: 'Store status',
          ),
          IconButton(
            onPressed: () => _signOut(context, ref),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: brand.hairline)),
            ),
            child: Row(
              children: [
                _NavTab(
                  label: 'Live queue',
                  icon: Icons.receipt_long_rounded,
                  badge: counts.total,
                  alert: counts.delayed > 0,
                  selected: location == Routes.kitchen,
                  onTap: () => context.go(Routes.kitchen),
                ),
                _NavTab(
                  label: 'Availability',
                  icon: Icons.inventory_2_outlined,
                  selected: location == Routes.kitchenAvailability,
                  onTap: () => context.go(Routes.kitchenAvailability),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (!branch.acceptingOrders)
            Container(
              width: double.infinity,
              color: brand.warning,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.pause_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      branch.statusNote ?? 'This outlet is not accepting new orders.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _reopen(context, ref),
                    child: const Text(
                      'REOPEN',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Future<void> _reopen(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(branchStatusControllerProvider.notifier)
          .setStatus(status: 'OPEN');
      if (context.mounted) AppFeedback.showSuccess(context, 'Accepting orders again.');
    } catch (error) {
      if (context.mounted) AppFeedback.showError(context, error);
    }
  }

  Future<void> _openStatusSheet(
    BuildContext context,
    WidgetRef ref,
    BranchState branch,
  ) {
    return AppFeedback.sheet<void>(
      context,
      builder: (_) => _StoreStatusSheet(branch: branch),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppFeedback.confirm(
      context,
      title: 'Sign out of this tablet?',
      message: 'The live queue will stop updating until someone signs back in.',
      confirmLabel: 'Sign out',
      destructive: true,
    );

    if (!confirmed) return;
    // Detach the tablet's push token so the next shift does not receive the
    // previous user's alerts.
    await ref.read(sessionProvider.notifier).signOut(
          deviceToken: ref.read(pushTokenProvider),
        );
  }
}

class _StoreStatePill extends StatelessWidget {
  const _StoreStatePill({required this.branch});

  final BranchState branch;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final open = branch.acceptingOrders;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: (open ? brand.success : brand.error).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: open ? brand.success : brand.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            open ? 'Accepting orders' : 'Paused',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: open ? brand.success : brand.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
    this.alert = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? brand.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? brand.primary : brand.inkMuted,
              ),
              const SizedBox(width: 9),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? brand.primary : brand.ink,
                ),
              ),
              if (badge != null && badge! > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: alert ? brand.error : brand.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pause or reopen the outlet.
///
/// A timed pause is offered first because it is almost always what a busy kitchen
/// wants: the scheduled job reopens the store so nobody has to remember.
class _StoreStatusSheet extends ConsumerStatefulWidget {
  const _StoreStatusSheet({required this.branch});

  final BranchState branch;

  @override
  ConsumerState<_StoreStatusSheet> createState() => _StoreStatusSheetState();
}

class _StoreStatusSheetState extends ConsumerState<_StoreStatusSheet> {
  String _reason = 'TOO_BUSY';
  int? _resumeMinutes = 30;
  final _note = TextEditingController();
  bool _busy = false;

  static const _durations = <int?>[15, 30, 60, 120, null];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _apply(String status) async {
    setState(() => _busy = true);

    try {
      await ref.read(branchStatusControllerProvider.notifier).setStatus(
            status: status,
            reason: status == 'OPEN' ? null : _reason,
            note: status == 'OPEN' ? null : _note.text,
            resumeAfterMinutes: status == 'OPEN' ? null : _resumeMinutes,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(
        context,
        status == 'OPEN' ? 'Accepting orders again.' : 'New orders paused.',
      );
    } catch (error) {
      if (!mounted) return;
      AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(
              title: 'Store status',
              subtitle: widget.branch.acceptingOrders
                  ? 'Currently accepting orders.'
                  : 'Currently paused.',
            ),
            if (widget.branch.acceptingOrders) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Why are you pausing?',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: brand.ink,
                  ),
                ),
              ),
              RadioGroup<String>(
                groupValue: _reason,
                onChanged: (value) => setState(() => _reason = value ?? _reason),
                child: Column(
                  children: KitchenRepository.closureReasons.entries
                      .map(
                        (entry) => RadioListTile<String>(
                          value: entry.key,
                          dense: true,
                          title: Text(entry.value),
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  'Reopen automatically after',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: brand.ink,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Wrap(
                  spacing: 8,
                  children: _durations
                      .map(
                        (minutes) => ChoiceChip(
                          label: Text(
                            minutes == null ? 'Until I reopen' : '$minutes min',
                          ),
                          selected: _resumeMinutes == minutes,
                          onSelected: (_) => setState(() => _resumeMinutes = minutes),
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: TextField(
                  controller: _note,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    hintText: 'Message shown to customers (optional)',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FilledButton(
                  onPressed: _busy ? null : () => _apply('PAUSED'),
                  style: FilledButton.styleFrom(backgroundColor: brand.warning),
                  child: Text(_busy ? 'Pausing…' : 'Pause new orders'),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FilledButton(
                  onPressed: _busy ? null : () => _apply('OPEN'),
                  child: Text(_busy ? 'Reopening…' : 'Start accepting orders'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
