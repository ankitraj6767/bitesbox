import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session.dart';
import '../../../core/notifications/push_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/launcher.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';
import '../data/delivery_models.dart';
import '../providers/delivery_providers.dart';
import 'rider_onboarding_screen.dart' show showRiderContactSheet;
import 'rider_shell.dart';

/// The rider's own record: identity, vehicle, performance and duty control.
///
/// Mostly read-only. A rider can change their alternate number, emergency contact
/// and UPI id — the fields that are theirs and that nothing else depends on.
/// Vehicle number, delivery slots, rating and cash balance are corrected by a
/// manager in the admin dashboard, which audits it: those feed dispatch and COD
/// reconciliation, and a rider was previously able to rewrite all of them through
/// a table policy that has since been removed.
class RiderProfileScreen extends ConsumerWidget {
  const RiderProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final session = ref.watch(currentSessionProvider);
    final dashboard = ref.watch(riderDashboardProvider);
    final config = ref.watch(appConfigProvider).valueOrNull;

    return RiderScaffold(
      title: 'Profile',
      body: AsyncValueView<RiderDashboard>(
        value: dashboard,
        onRetry: () => ref.invalidate(riderDashboardProvider),
        data: (data) {
          final profile = data.profile;

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            children: [
              _IdentityCard(profile: profile, session: session),
              const SizedBox(height: 14),
              _DutySection(profile: profile),
              const SizedBox(height: 14),
              _PerformanceCard(profile: profile),
              const SizedBox(height: 14),
              _DetailsCard(profile: profile),
              const SizedBox(height: 14),
              _SupportCard(supportPhone: config?.supportPhone),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _signOut(context, ref, profile),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  foregroundColor: brand.error,
                  side: BorderSide(color: brand.error.withValues(alpha: 0.4)),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Bites Box · Delivery partner app',
                  style: TextStyle(fontSize: 11.5, color: brand.inkMuted),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref,
    RiderProfile profile,
  ) async {
    // Signing out mid-shift would silently take a rider off dispatch while they
    // are still carrying food, so we spell that out.
    final confirmed = await AppFeedback.confirm(
      context,
      title: 'Sign out?',
      message: profile.activeLoad > 0
          ? 'You still have ${profile.activeLoad} delivery(ies) in progress. '
              'Finish them first — signing out does not cancel them.'
          : 'You will stop receiving deliveries until you sign in again.',
      confirmLabel: 'Sign out',
      destructive: true,
    );

    if (!confirmed) return;
    await ref.read(sessionProvider.notifier).signOut(
          deviceToken: ref.read(pushTokenProvider),
        );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile, required this.session});

  final RiderProfile profile;
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Row(
        children: [
          _Avatar(path: profile.photoPath, initials: profile.firstName),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: brand.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  profile.phone ?? session.profile?.phone ?? '',
                  style: TextStyle(fontSize: 13, color: brand.inkMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AppPill(
                      label: Fmt.humanise(profile.onboardingStatus),
                      dense: true,
                      background: (profile.isActive ? brand.success : brand.warning)
                          .withValues(alpha: 0.1),
                      foreground: profile.isActive ? brand.success : brand.warning,
                    ),
                    if (profile.ratingAverage > 0) ...[
                      const SizedBox(width: 8),
                      RatingChip(rating: profile.ratingAverage, dense: true),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.path, required this.initials});

  final String? path;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final url = FoodImage.resolve(path);

    if (url != null) {
      return FoodImage(path: path, width: 62, height: 62, radius: 31);
    }

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: brand.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials.characters.first.toUpperCase(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: brand.primary,
          ),
        ),
      ),
    );
  }
}

class _DutySection extends ConsumerStatefulWidget {
  const _DutySection({required this.profile});

  final RiderProfile profile;

  @override
  ConsumerState<_DutySection> createState() => _DutySectionState();
}

class _DutySectionState extends ConsumerState<_DutySection> {
  bool _busy = false;

  Future<void> _set(DutyState next) async {
    setState(() => _busy = true);
    try {
      await ref.read(riderDashboardProvider.notifier).setDuty(next);
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

    if (!profile.isActive) {
      // A notice with no way out is a dead end. Onboarding is the one thing a
      // rider in this state can actually do, so it is offered here.
      final canAct = profile.onboardingStatus == 'PENDING' ||
          profile.onboardingStatus == 'DOCUMENTS_SUBMITTED';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppNotice(
            tone: NoticeTone.caution,
            message: profile.onboardingBlocker ?? 'Your account is not active.',
          ),
          if (canAct) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => context.push(Routes.riderOnboarding),
              icon: const Icon(Icons.assignment_turned_in_outlined, size: 18),
              label: Text(
                profile.onboardingStatus == 'PENDING'
                    ? 'Upload your documents'
                    : 'Check your documents',
              ),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ],
        ],
      );
    }

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
          Text(
            'DUTY',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: brand.inkMuted,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [DutyState.available, DutyState.onBreak, DutyState.offline].map(
              (state) {
                final selected = profile.dutyState == state ||
                    (state == DutyState.available &&
                        profile.dutyState == DutyState.busy);

                return ChoiceChip(
                  selected: selected,
                  label: Text(state.label),
                  onSelected: _busy || selected ? null : (_) => _set(state),
                );
              },
            ).toList(),
          ),
          if (profile.dutyState == DutyState.busy) ...[
            const SizedBox(height: 10),
            Text(
              'You are marked busy automatically while a delivery is live. Finish it '
              'to free up your slot.',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: brand.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.profile});

  final RiderProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: RiderStat(
            label: 'Deliveries',
            value: '${profile.totalDeliveries}',
            caption: 'All time',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RiderStat(
            label: 'Rating',
            value: profile.ratingAverage > 0
                ? profile.ratingAverage.toStringAsFixed(1)
                : '—',
            caption: 'Out of 5',
          ),
        ),
      ],
    );
  }
}

class _DetailsCard extends ConsumerWidget {
  const _DetailsCard({required this.profile});

  final RiderProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;

    final rows = <(String, String)>[
      ('Vehicle', Fmt.humanise(profile.vehicleType)),
      if ((profile.vehicleNumber ?? '').isNotEmpty)
        ('Vehicle number', profile.vehicleNumber!),
      ('Delivery slots', '${profile.maxConcurrentOrders}'),
      ('Cash in hand', Fmt.moneySmart(profile.cashInHand)),
    ];

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
              Expanded(
                child: Text(
                  'YOUR DETAILS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: brand.inkMuted,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => showRiderContactSheet(context, ref),
                child: const Text('Edit contact'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.$1,
                      style: TextStyle(fontSize: 13.5, color: brand.inkMuted),
                    ),
                  ),
                  Text(
                    row.$2,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: brand.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You can change your alternate number, emergency contact and UPI id. '
            'Your vehicle, delivery slots and cash balance are corrected by a '
            'manager — those changes are recorded against their name.',
            style: TextStyle(fontSize: 12, height: 1.4, color: brand.inkMuted),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => context.push(Routes.riderOnboarding),
            icon: const Icon(Icons.folder_open_rounded, size: 17),
            label: const Text('My documents'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 36),
              alignment: Alignment.centerLeft,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.supportPhone});

  final String? supportPhone;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    if ((supportPhone ?? '').isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.support_agent_rounded, color: brand.secondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need help on the road?',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: brand.ink,
                  ),
                ),
                Text(
                  'Call the outlet and operations will step in.',
                  style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => Launcher.dial(supportPhone),
            icon: const Icon(Icons.call_rounded, size: 20),
            tooltip: 'Call the outlet',
          ),
        ],
      ),
    );
  }
}
