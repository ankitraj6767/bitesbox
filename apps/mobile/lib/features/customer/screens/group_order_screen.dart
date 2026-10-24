import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';
import '../data/group_order_models.dart';
import '../providers/cart_controller.dart';
import '../providers/customer_providers.dart';

class GroupOrderScreen extends ConsumerStatefulWidget {
  const GroupOrderScreen({this.groupOrderId, super.key});

  final String? groupOrderId;

  @override
  ConsumerState<GroupOrderScreen> createState() => _GroupOrderScreenState();
}

class _GroupOrderScreenState extends ConsumerState<GroupOrderScreen> {
  final _codeController = TextEditingController();
  Timer? _refreshTimer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant GroupOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupOrderId != widget.groupOrderId) _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    final groupOrderId = widget.groupOrderId;
    if (groupOrderId == null) return;

    _refreshTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (mounted) ref.invalidate(groupOrderProvider(groupOrderId));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final groupOrderId = await ref
          .read(groupOrderRepositoryProvider)
          .create(branchId: ref.read(activeBranchIdProvider));
      ref.invalidate(currentGroupOrderProvider);
      if (mounted) context.go(Routes.groupOrder(groupOrderId));
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final groupOrderId = await ref
          .read(groupOrderRepositoryProvider)
          .join(_codeController.text);
      ref.invalidate(currentGroupOrderProvider);
      if (mounted) context.go(Routes.groupOrder(groupOrderId));
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Group code copied')));
  }

  Future<void> _leave(GroupOrder group) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this group order?'),
        content: const Text(
          'Your items will stay in your own cart and will not be added to the group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave group'),
          ),
        ],
      ),
    );
    if (shouldLeave != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(groupOrderRepositoryProvider).leave(group.id);
      ref.invalidate(currentGroupOrderProvider);
      if (mounted) context.go(Routes.home);
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close(GroupOrder group) async {
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close this group order?'),
        content: const Text(
          'Everyone will leave the group. Their separate carts will stay untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it open'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close group'),
          ),
        ],
      ),
    );
    if (shouldClose != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(groupOrderRepositoryProvider).close(group.id);
      ref.invalidate(currentGroupOrderProvider);
      if (mounted) context.go(Routes.home);
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _prepareCheckout(GroupOrder group) async {
    setState(() => _busy = true);
    try {
      await ref.read(groupOrderRepositoryProvider).merge(group.id);
      ref.invalidate(currentGroupOrderProvider);
      await ref.read(cartProvider.notifier).refresh();
      if (mounted) context.go(Routes.checkout);
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupOrderId = widget.groupOrderId;
    if (groupOrderId == null) return _buildStartOrJoin();

    final value = ref.watch(groupOrderProvider(groupOrderId));
    return Scaffold(
      appBar: AppBar(title: const Text('Group order')),
      body: AsyncValueView<GroupOrder>(
        value: value,
        onRetry: () => ref.invalidate(groupOrderProvider(groupOrderId)),
        loading: const _GroupOrderSkeleton(),
        data: (group) => _buildGroup(group),
      ),
    );
  }

  Widget _buildStartOrJoin() {
    final brand = context.brand;
    final session = ref.watch(currentSessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Order together')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [brand.primary, brand.primaryDark],
              ),
              borderRadius: BorderRadius.circular(brand.radiusXl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.groups_rounded, color: Colors.white, size: 32),
                const SizedBox(height: 18),
                const Text(
                  'Good food, shared better.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a group, invite your people, and let everyone add their favourites.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.45,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _HowItWorks(),
          const SizedBox(height: 24),
          if (session.isGuest)
            FilledButton.icon(
              onPressed: () => context.push(Routes.signIn),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Sign in to start a group'),
            )
          else ...[
            FilledButton.icon(
              onPressed: _busy ? null : _create,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: const Text('Start a group order'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Divider(color: brand.hairline)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'OR JOIN A GROUP',
                    style: TextStyle(
                      color: brand.inkMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: brand.hairline)),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 32,
              decoration: const InputDecoration(
                labelText: 'Group code',
                hintText: 'Paste the code from your host',
                counterText: '',
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _join,
              icon: const Icon(Icons.group_add_rounded),
              label: const Text('Join group order'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroup(GroupOrder group) {
    final brand = context.brand;
    final isOpen = group.isOpen;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: brand.primary,
            onRefresh: () async => ref.invalidate(groupOrderProvider(group.id)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (!isOpen)
                  AppNotice(
                    tone: NoticeTone.caution,
                    message: group.status == 'EXPIRED'
                        ? 'This group order expired. Start a new group to order together.'
                        : 'This group order has been closed.',
                  )
                else
                  _InviteCard(
                    group: group,
                    onCopy: group.inviteCode == null
                        ? null
                        : () => _copyCode(group.inviteCode!),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your group',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: brand.ink,
                        ),
                      ),
                    ),
                    AppPill(
                      label: '${group.members.length} people',
                      dense: true,
                      background: brand.surfaceMuted,
                      foreground: brand.inkMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (group.itemCount == 0)
                  _EmptyGroupHint(isHost: group.isHost)
                else
                  ...group.members.map((member) => _MemberCard(member: member)),
              ],
            ),
          ),
        ),
        if (isOpen)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: brand.surface,
                border: Border(top: BorderSide(color: brand.hairline)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (group.isHost)
                    FilledButton.icon(
                      onPressed: _busy || group.itemCount == 0
                          ? null
                          : () => _prepareCheckout(group),
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.shopping_bag_rounded),
                      label: Text(
                        group.itemCount == 0
                            ? 'Waiting for items'
                            : 'Review ${group.itemCount} items',
                      ),
                    )
                  else ...[
                    OutlinedButton.icon(
                      onPressed: () => context.go(Routes.menu),
                      icon: const Icon(Icons.restaurant_menu_rounded),
                      label: const Text('Browse the menu'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _leave(group),
                      child: const Text('Leave group'),
                    ),
                  ],
                  if (group.isHost)
                    TextButton(
                      onPressed: _busy ? null : () => context.go(Routes.menu),
                      child: const Text('Add something from the menu'),
                    ),
                  if (group.isHost)
                    TextButton(
                      onPressed: _busy ? null : () => _close(group),
                      child: const Text('Close group'),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    const steps = [
      (Icons.link_rounded, 'Share a code', 'Invite your friends to join.'),
      (
        Icons.restaurant_menu_rounded,
        'Pick your favourites',
        'Everyone adds to their own list.',
      ),
      (
        Icons.receipt_long_rounded,
        'One checkout',
        'The host reviews and places the order.',
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: brand.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: brand.hairline),
                ),
                child: Icon(steps[i].$1, size: 19, color: brand.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps[i].$2,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      steps[i].$3,
                      style: TextStyle(color: brand.inkMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (i < steps.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(width: 1, height: 18, color: brand.hairline),
              ),
            ),
        ],
      ],
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.group, required this.onCopy});

  final GroupOrder group;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final code = group.inviteCode;
    if (code == null) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: brand.surfaceMuted,
          borderRadius: BorderRadius.circular(brand.radiusMd),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: brand.primary),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Ask the host to share the invite code.'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brand.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INVITE YOUR PEOPLE',
            style: TextStyle(
              color: brand.primary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  code,
                  style: TextStyle(
                    color: brand.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: onCopy,
                tooltip: 'Copy group code',
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
          Text(
            'This code stays active for 2 hours.',
            style: TextStyle(color: brand.inkMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});

  final GroupOrderMember member;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              CircleAvatar(
                radius: 17,
                backgroundColor: brand.primary.withValues(alpha: 0.1),
                child: Text(
                  member.name.isEmpty
                      ? '?'
                      : member.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: brand.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  member.isHost ? '${member.name} · Host' : member.name,
                  style: TextStyle(
                    color: brand.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${member.itemCount} items',
                style: TextStyle(color: brand.inkMuted, fontSize: 12),
              ),
            ],
          ),
          if (member.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final item in member.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.quantity} ×',
                      style: TextStyle(
                        color: brand.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        [
                          item.name,
                          if (item.variantName != null) item.variantName!,
                          if (item.modifiers.isNotEmpty)
                            item.modifiers.join(', '),
                        ].join(' · '),
                        style: TextStyle(color: brand.inkMuted, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            const SizedBox(height: 9),
            Text(
              member.isHost
                  ? 'Add something from the menu to get started.'
                  : 'Choosing something tasty…',
              style: TextStyle(color: brand.inkMuted, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyGroupHint extends StatelessWidget {
  const _EmptyGroupHint({required this.isHost});

  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusLg),
        border: Border.all(color: brand.hairline),
      ),
      child: Column(
        children: [
          Icon(Icons.restaurant_rounded, size: 30, color: brand.primary),
          const SizedBox(height: 10),
          Text(
            isHost ? 'Your group is ready' : 'You’re in the group',
            style: TextStyle(color: brand.ink, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            isHost
                ? 'Add a favourite and share the invite code.'
                : 'Browse the menu and add your picks. The host will check out for everyone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: brand.inkMuted, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _GroupOrderSkeleton extends StatelessWidget {
  const _GroupOrderSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SkeletonBox(height: 122, radius: 18),
        SizedBox(height: 18),
        SkeletonBox(width: 160, height: 22),
        SizedBox(height: 14),
        SkeletonBox(height: 96, radius: 16),
        SizedBox(height: 12),
        SkeletonBox(height: 96, radius: 16),
      ],
    );
  }
}
