import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';
import '../data/delivery_models.dart';
import '../data/delivery_repository.dart';
import '../providers/delivery_providers.dart';
import 'rider_shell.dart';

/// The rider's home: duty state, live offers, work in progress, and what they
/// have already finished today.
///
/// Everything on this screen is server state. The rider app never decides whether
/// it may accept a job, go offline, or count an earning — it asks, and renders the
/// answer.
class RiderHomeScreen extends ConsumerStatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  ConsumerState<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends ConsumerState<RiderHomeScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Only drives the offer countdown; the data itself arrives over realtime.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final dashboard = ref.watch(riderDashboardProvider);

    return RiderScaffold(
      title: 'Deliveries',
      subtitle: ref.watch(riderProfileProvider) == null
          ? null
          : 'Hello, ${ref.watch(riderProfileProvider)!.firstName}',
      actions: [
        IconButton(
          onPressed: () => ref.read(riderDashboardProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
        ),
      ],
      body: AsyncValueView<RiderDashboard>(
        value: dashboard,
        onRetry: () => ref.invalidate(riderDashboardProvider),
        data: (data) => RefreshIndicator(
          color: brand.primary,
          onRefresh: () => ref.read(riderDashboardProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            children: [
              _DutyCard(profile: data.profile),
              if (data.offers.isNotEmpty) ...[
                const SizedBox(height: 18),
                _SectionLabel(
                  label: 'New offers',
                  count: data.offers.length,
                  tone: brand.primary,
                ),
                for (final offer in data.offers) ...[
                  const SizedBox(height: 10),
                  _OfferCard(offer: offer, now: _now),
                ],
              ],
              if (data.inProgress.isNotEmpty) ...[
                const SizedBox(height: 18),
                _SectionLabel(label: 'In progress', count: data.inProgress.length),
                for (final job in data.inProgress) ...[
                  const SizedBox(height: 10),
                  _ActiveJobCard(job: job),
                ],
              ],
              if (data.active.isEmpty) ...[
                const SizedBox(height: 12),
                _NoWorkPanel(profile: data.profile),
              ],
              const SizedBox(height: 20),
              _TodayStrip(profile: data.profile, history: data.history),
              if (data.history.isNotEmpty) ...[
                const SizedBox(height: 18),
                _SectionLabel(label: 'Recent deliveries'),
                const SizedBox(height: 6),
                for (final entry in data.history.take(15)) _HistoryRow(entry: entry),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
// ───────────────────────────── duty toggle ─────────────────────────────

class _DutyCard extends ConsumerStatefulWidget {
  const _DutyCard({required this.profile});

  final RiderProfile profile;

  @override
  ConsumerState<_DutyCard> createState() => _DutyCardState();
}

class _DutyCardState extends ConsumerState<_DutyCard> {
  bool _busy = false;

  Future<void> _setDuty(DutyState next) async {
    setState(() => _busy = true);
    try {
      await ref.read(riderDashboardProvider.notifier).setDuty(next);
      if (mounted) {
        AppFeedback.showSuccess(
          context,
          next == DutyState.offline
              ? 'You are offline. Have a good rest.'
              : 'You are on duty. Dispatch can reach you now.',
        );
      }
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final profile = widget.profile;
    final blocker = profile.onboardingBlocker;

    if (blocker != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: brand.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(brand.radiusMd),
          border: Border.all(color: brand.warning.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pending_actions_rounded, color: brand.warning, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Not ready for deliveries yet',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: brand.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              blocker,
              style: TextStyle(fontSize: 13.5, height: 1.45, color: brand.inkMuted),
            ),
            // The first thing a new rider sees is this card, so it has to lead
            // somewhere. Suspended and rejected accounts do not — those need a
            // manager, and offering an upload button would waste their time.
            if (profile.onboardingStatus == 'PENDING' ||
                profile.onboardingStatus == 'DOCUMENTS_SUBMITTED') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push(Routes.riderOnboarding),
                  icon: const Icon(Icons.assignment_turned_in_outlined, size: 18),
                  label: Text(
                    profile.onboardingStatus == 'PENDING'
                        ? 'Upload your documents'
                        : 'Check your documents',
                  ),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final online = profile.dutyState.isWorking;
    final colour = online ? brand.success : brand.inkMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: colour.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  online ? Icons.two_wheeler_rounded : Icons.bedtime_outlined,
                  color: colour,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      online ? 'You are on duty' : 'You are offline',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: brand.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      online
                          ? '${profile.activeLoad} of ${profile.maxConcurrentOrders} '
                              'delivery slots in use'
                          : 'Go on duty to start receiving deliveries',
                      style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: online ? 'Go offline' : 'Go on duty',
                child: Switch.adaptive(
                  value: online,
                  activeThumbColor: brand.success,
                  onChanged: _busy
                      ? null
                      : (value) =>
                          _setDuty(value ? DutyState.available : DutyState.offline),
                ),
              ),
            ],
          ),
          if (online) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy || profile.dutyState == DutyState.onBreak
                        ? null
                        : () => _setDuty(DutyState.onBreak),
                    icon: const Icon(Icons.pause_rounded, size: 18),
                    label: const Text('Take a break'),
                  ),
                ),
                if (profile.dutyState == DutyState.onBreak) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _setDuty(DutyState.available),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Resume'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
// ───────────────────────────── offers ─────────────────────────────

class _OfferCard extends ConsumerStatefulWidget {
  const _OfferCard({required this.offer, required this.now});

  final DeliveryAssignment offer;
  final DateTime now;

  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await ref.read(riderDashboardProvider.notifier).respond(
            assignmentId: widget.offer.assignmentId,
            accept: true,
          );
      if (mounted) {
        context.push(Routes.riderDelivery(widget.offer.assignmentId));
      }
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    final reason = await showRiderReasonSheet(
      context,
      title: 'Why are you declining?',
      subtitle: 'Operations will see this and reassign the order.',
      reasons: DeliveryRepository.declineReasons,
      confirmLabel: 'Decline delivery',
    );

    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(riderDashboardProvider.notifier).respond(
            assignmentId: widget.offer.assignmentId,
            accept: false,
            reason: reason,
          );
      if (mounted) AppFeedback.showInfo(context, 'Declined. It has gone back to dispatch.');
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final offer = widget.offer;
    final order = offer.order;
    final left = offer.expiresAt?.difference(widget.now);
    final expiring = left != null && left.inSeconds <= 30;

    return Container(
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.primary, width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: brand.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.vertical(top: Radius.circular(brand.radiusMd)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: brand.ink,
                    ),
                  ),
                ),
                if (left != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: expiring ? brand.error : brand.ink,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      left.isNegative
                          ? 'Expired'
                          : Fmt.elapsed(left.inSeconds),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RiderWaypoint(
                  icon: Icons.storefront_rounded,
                  title: offer.branch.name,
                  body: offer.branch.address ?? 'Pick up from the outlet',
                  tone: brand.secondary,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 15),
                  child: Container(width: 2, height: 16, color: brand.hairline),
                ),
                RiderWaypoint(
                  icon: Icons.location_on_rounded,
                  title: order.customerName ?? 'Customer',
                  body: order.address,
                  tone: brand.primary,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppPill(
                      label: Fmt.moneySmart(offer.totalPayout),
                      icon: Icons.payments_rounded,
                      background: brand.success.withValues(alpha: 0.1),
                      foreground: brand.success,
                    ),
                    if (order.distanceKm != null)
                      AppPill(
                        label: Fmt.distance(order.distanceKm),
                        icon: Icons.route_rounded,
                      ),
                    AppPill(
                      label: '${order.unitCount} item'
                          '${order.unitCount == 1 ? '' : 's'}',
                      icon: Icons.shopping_bag_outlined,
                    ),
                    if (order.isCod)
                      AppPill(
                        label: 'Collect ${Fmt.moneySmart(order.codAmount)}',
                        icon: Icons.currency_rupee_rounded,
                        background: brand.warning.withValues(alpha: 0.12),
                        foreground: brand.warning,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                RiderPrimaryButton(
                  label: 'Accept delivery',
                  icon: Icons.check_rounded,
                  busy: _busy,
                  onPressed: _accept,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: TextButton(
                    onPressed: _busy ? null : _decline,
                    style: TextButton.styleFrom(foregroundColor: brand.inkMuted),
                    child: const Text('I cannot take this one'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── active work ─────────────────────────────

class _ActiveJobCard extends StatelessWidget {
  const _ActiveJobCard({required this.job});

  final DeliveryAssignment job;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final order = job.order;
    final headingToStore = job.navigatesToBranch;

    return InkWell(
      onTap: () => context.push(Routes.riderDelivery(job.assignmentId)),
      borderRadius: BorderRadius.circular(brand.radiusMd),
      child: Container(
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
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: brand.ink,
                    ),
                  ),
                ),
                AppPill(
                  label: job.statusLabel,
                  background: brand.secondary.withValues(alpha: 0.1),
                  foreground: brand.secondary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  headingToStore
                      ? Icons.storefront_rounded
                      : Icons.location_on_rounded,
                  size: 17,
                  color: brand.inkMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    headingToStore
                        ? (job.branch.address ?? job.branch.name)
                        : order.address,
                    style: TextStyle(fontSize: 13.5, height: 1.4, color: brand.inkMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.nextActionLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: brand.primary,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, size: 20, color: brand.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoWorkPanel extends StatelessWidget {
  const _NoWorkPanel({required this.profile});

  final RiderProfile profile;

  @override
  Widget build(BuildContext context) {
    if (!profile.isActive) return const SizedBox.shrink();

    return AppEmptyState(
      compact: true,
      icon: profile.dutyState.isWorking
          ? Icons.hourglass_empty_rounded
          : Icons.power_settings_new_rounded,
      title: profile.dutyState.isWorking
          ? 'Waiting for your next delivery'
          : 'You are offline',
      message: profile.dutyState.isWorking
          ? 'We will alert you the moment dispatch assigns an order.'
          : 'Switch on duty above and dispatch will start sending you orders.',
    );
  }
}

// ───────────────────────────── today + history ─────────────────────────────

class _TodayStrip extends ConsumerWidget {
  const _TodayStrip({required this.profile, required this.history});

  final RiderProfile profile;
  final List<DeliveryHistoryEntry> history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnings = ref.watch(riderEarningsProvider).valueOrNull;

    return Row(
      children: [
        Expanded(
          child: RiderStat(
            label: 'Earned today',
            value: Fmt.moneySmart(earnings?.today ?? 0),
            caption: '${earnings?.deliveriesToday ?? 0} deliveries',
            tone: context.brand.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RiderStat(
            label: 'Cash in hand',
            value: Fmt.moneySmart(profile.cashInHand),
            caption: profile.cashInHand > 0 ? 'Hand over at the outlet' : 'All settled',
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final DeliveryHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (entry.succeeded ? brand.success : brand.error)
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              entry.succeeded ? Icons.check_rounded : Icons.close_rounded,
              size: 17,
              color: entry.succeeded ? brand.success : brand.error,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.orderNumber,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: brand.ink,
                  ),
                ),
                Text(
                  [
                    Fmt.smartDateTime(entry.completedAt),
                    if (entry.area != null) entry.area!,
                  ].join(' · '),
                  style: TextStyle(fontSize: 11.5, color: brand.inkMuted),
                ),
              ],
            ),
          ),
          Text(
            Fmt.moneySmart(entry.totalPayout),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: entry.succeeded ? brand.success : brand.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── shared bits ─────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.count, this.tone});

  final String label;
  final int? count;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
            color: tone ?? brand.ink,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 7),
          AppPill(
            label: '$count',
            dense: true,
            background: (tone ?? brand.ink).withValues(alpha: 0.1),
            foreground: tone ?? brand.inkMuted,
          ),
        ],
      ],
    );
  }
}
