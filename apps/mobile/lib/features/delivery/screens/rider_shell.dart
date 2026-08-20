import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/launcher.dart';
import '../data/delivery_models.dart';
import '../providers/delivery_providers.dart';

/// Chrome shared by the rider screens.
///
/// Designed for one-handed use on a phone that is often in a mount: three
/// destinations, large touch targets, and the duty state always visible so a
/// rider never has to guess whether dispatch can reach them.
class RiderScaffold extends ConsumerWidget {
  const RiderScaffold({
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const <Widget>[],
    this.bottom,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final profile = ref.watch(riderProfileProvider);

    // Arming the publisher here means GPS follows the rider through every screen
    // of the shell and stops the moment the server says nothing is live.
    ref.watch(riderLocationPublisherProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: brand.inkMuted,
                ),
              ),
          ],
        ),
        actions: [
          if (profile != null) DutyStatePill(state: profile.dutyState),
          const SizedBox(width: 8),
          ...actions,
        ],
      ),
      body: body,
      bottomNavigationBar: const _RiderNavBar(),
      bottomSheet: bottom,
    );
  }
}

/// Compact, always-visible duty indicator.
class DutyStatePill extends StatelessWidget {
  const DutyStatePill({required this.state, super.key});

  final DutyState state;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    final colour = switch (state) {
      DutyState.available => brand.success,
      DutyState.busy => brand.secondary,
      DutyState.onBreak => brand.warning,
      DutyState.offline => brand.inkMuted,
    };

    return Semantics(
      label: 'Duty state: ${state.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colour.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              state.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colour,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiderNavBar extends ConsumerWidget {
  const _RiderNavBar();

  static const _destinations = <(String, String, IconData, IconData)>[
    (Routes.rider, 'Deliveries', Icons.moving_rounded, Icons.moving_rounded),
    (
      Routes.riderEarnings,
      'Earnings',
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
    ),
    (
      Routes.riderProfile,
      'Profile',
      Icons.person_outline_rounded,
      Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final location = GoRouterState.of(context).uri.path;
    final liveJobs = ref.watch(riderDashboardProvider).valueOrNull?.active.length ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: brand.surface,
        border: Border(top: BorderSide(color: brand.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: _destinations.map((destination) {
            final (path, label, icon, activeIcon) = destination;
            final selected = location == path;

            return Expanded(
              child: InkWell(
                onTap: selected ? null : () => context.go(path),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Badge(
                        isLabelVisible: path == Routes.rider && liveJobs > 0,
                        label: Text('$liveJobs'),
                        backgroundColor: brand.primary,
                        child: Icon(
                          selected ? activeIcon : icon,
                          size: 26,
                          color: selected ? brand.primary : brand.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? brand.primary : brand.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Full-width primary action. The rider screens deliberately show exactly one at
/// a time, so the next step is never ambiguous while riding.
class RiderPrimaryButton extends StatelessWidget {
  const RiderPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.colour,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return SizedBox(
      width: double.infinity,
      height: 60,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colour ?? brand.primary,
          textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 21),
                    const SizedBox(width: 10),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

/// A stop on the trip: the outlet, then the customer.
class RiderWaypoint extends StatelessWidget {
  const RiderWaypoint({
    required this.icon,
    required this.title,
    required this.body,
    required this.tone,
    this.onNavigate,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color tone;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: tone),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: brand.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(fontSize: 13, height: 1.4, color: brand.inkMuted),
              ),
            ],
          ),
        ),
        if (onNavigate != null)
          IconButton.filledTonal(
            onPressed: onNavigate,
            icon: const Icon(Icons.navigation_rounded, size: 19),
            tooltip: 'Navigate',
          ),
      ],
    );
  }
}

/// Hands off to the phone's own navigation app, and says so when it cannot.
Future<void> riderNavigate(
  BuildContext context, {
  required double? latitude,
  required double? longitude,
  String? label,
}) async {
  if (latitude == null || longitude == null) {
    AppFeedback.showInfo(context, 'No map location was saved for this stop.');
    return;
  }

  final opened = await Launcher.navigate(
    latitude: latitude,
    longitude: longitude,
    label: label,
  );

  if (!opened && context.mounted) {
    AppFeedback.showInfo(context, 'No maps app is available on this phone.');
  }
}

/// Single-select reason sheet, shared by declining an offer and reporting a
/// failed delivery. Free text is offered because real problems are rarely on a list.
Future<String?> showRiderReasonSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<String> reasons,
  String confirmLabel = 'Confirm',
}) {
  return AppFeedback.sheet<String>(
    context,
    builder: (_) => _ReasonSheet(
      title: title,
      subtitle: subtitle,
      reasons: reasons,
      confirmLabel: confirmLabel,
    ),
  );
}

class _ReasonSheet extends StatefulWidget {
  const _ReasonSheet({
    required this.title,
    required this.subtitle,
    required this.reasons,
    required this.confirmLabel,
  });

  final String title;
  final String subtitle;
  final List<String> reasons;
  final String confirmLabel;

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  static const _otherKey = '__other__';

  String? _selected;
  final _other = TextEditingController();

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  String? get _value {
    if (_selected == _otherKey) {
      final text = _other.text.trim();
      return text.isEmpty ? null : text;
    }
    return _selected;
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final options = [...widget.reasons, _otherKey];

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            SheetHeader(title: widget.title, subtitle: widget.subtitle),
            ...options.map((option) {
              final selected = _selected == option;
              final label = option == _otherKey ? 'Something else' : option;

              return InkWell(
                onTap: () => setState(() => _selected = option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 22,
                        color: selected ? brand.primary : brand.inkMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: brand.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (_selected == _otherKey)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  controller: _other,
                  autofocus: true,
                  maxLength: 180,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Tell operations what happened',
                    counterText: '',
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
              child: RiderPrimaryButton(
                label: widget.confirmLabel,
                colour: brand.error,
                onPressed:
                    _value == null ? null : () => Navigator.of(context).pop(_value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled metric used on the home and earnings screens.
class RiderStat extends StatelessWidget {
  const RiderStat({
    required this.label,
    required this.value,
    this.caption,
    this.tone,
    super.key,
  });

  final String label;
  final String value;
  final String? caption;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

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
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: brand.inkMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: tone ?? brand.ink,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              style: TextStyle(fontSize: 11.5, color: brand.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}
