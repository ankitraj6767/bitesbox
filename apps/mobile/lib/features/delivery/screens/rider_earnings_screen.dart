import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brand_tokens.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/states.dart';
import '../data/delivery_models.dart';
import '../providers/delivery_providers.dart';
import 'rider_shell.dart';

/// What the rider has earned, and what cash they still owe the outlet.
///
/// Every figure is summed in Postgres from the append-only `delivery_earnings`
/// ledger, so the app cannot show a number that the finance team would dispute.
class RiderEarningsScreen extends ConsumerWidget {
  const RiderEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final earnings = ref.watch(riderEarningsProvider);

    return RiderScaffold(
      title: 'Earnings',
      subtitle: 'Last 30 days',
      actions: [
        IconButton(
          onPressed: () => ref.invalidate(riderEarningsProvider),
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
        ),
      ],
      body: AsyncValueView<RiderEarnings>(
        value: earnings,
        onRetry: () => ref.invalidate(riderEarningsProvider),
        data: (data) => RefreshIndicator(
          color: brand.primary,
          onRefresh: () async {
            ref.invalidate(riderEarningsProvider);
            await ref.read(riderEarningsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            children: [
              _Headline(data: data),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RiderStat(
                      label: 'This week',
                      value: Fmt.moneySmart(data.thisWeek),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RiderStat(
                      label: 'This month',
                      value: Fmt.moneySmart(data.thisMonth),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: RiderStat(
                      label: 'Lifetime',
                      value: Fmt.moneySmart(data.lifetime),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RiderStat(
                      label: 'Cash in hand',
                      value: Fmt.moneySmart(data.cashInHand),
                      caption: data.cashInHand > 0 ? 'Owed to the outlet' : 'All settled',
                      tone: data.cashInHand > 0 ? brand.warning : null,
                    ),
                  ),
                ],
              ),
              if (data.unsettledCash > 0) ...[
                const SizedBox(height: 12),
                AppNotice(
                  tone: NoticeTone.caution,
                  icon: Icons.account_balance_wallet_outlined,
                  message:
                      'You are carrying ${Fmt.moneySmart(data.unsettledCash)} in COD '
                      'cash. Hand it to the outlet at the end of your shift — a '
                      'manager settles it and it clears from here.',
                ),
              ],
              const SizedBox(height: 20),
              _DailyChart(days: data.daily),
              const SizedBox(height: 20),
              Text(
                'Every entry',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: brand.ink,
                ),
              ),
              const SizedBox(height: 4),
              if (data.entries.isEmpty)
                const AppEmptyState(
                  compact: true,
                  icon: Icons.receipt_long_outlined,
                  title: 'Nothing yet',
                  message: 'Your payouts appear here as soon as you finish a delivery.',
                )
              else
                ...data.entries.map((entry) => _EntryRow(entry: entry)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.data});

  final RiderEarnings data;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: brand.primary,
        borderRadius: BorderRadius.circular(brand.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EARNED TODAY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            Fmt.moneySmart(data.today),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${data.deliveriesToday} '
            'deliver${data.deliveriesToday == 1 ? 'y' : 'ies'} completed today',
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

/// Last fourteen days as simple bars. Deliberately not a charting library: this
/// screen has to open instantly on a mid-range phone.
class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.days});

  final List<EarningsDay> days;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    if (days.isEmpty) return const SizedBox.shrink();

    // `daily` arrives newest first; show the last fortnight oldest to newest.
    final window = days.take(14).toList().reversed.toList();
    final peak = window.fold<double>(
      0,
      (highest, day) => day.amount > highest ? day.amount : highest,
    );

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
            'Last two weeks',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: brand.ink,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: window.map((day) {
                final ratio = peak <= 0 ? 0.0 : day.amount / peak;
                final today = day.date != null && _isToday(day.date!);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: (76 * ratio).clamp(3, 76).toDouble(),
                          decoration: BoxDecoration(
                            color: today
                                ? brand.primary
                                : brand.primary.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          day.date == null ? '' : '${day.date!.toLocal().day}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: today ? FontWeight.w800 : FontWeight.w500,
                            color: today ? brand.primary : brand.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static bool _isToday(DateTime value) {
    final now = DateTime.now();
    final local = value.toLocal();
    return local.year == now.year && local.month == now.month && local.day == now.day;
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final EarningsEntry entry;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final deduction = entry.isDeduction;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (deduction ? brand.error : brand.success).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              switch (entry.entryType) {
                'TIP' => Icons.volunteer_activism_rounded,
                'PENALTY' => Icons.remove_circle_outline_rounded,
                'INCENTIVE' => Icons.emoji_events_outlined,
                'ADJUSTMENT' => Icons.tune_rounded,
                'CASH_SHORTFALL' => Icons.money_off_rounded,
                _ => Icons.two_wheeler_rounded,
              },
              size: 17,
              color: deduction ? brand.error : brand.success,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.typeLabel,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: brand.ink,
                  ),
                ),
                Text(
                  entry.description ?? Fmt.day(entry.earnedOn),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: brand.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${deduction ? '−' : '+'}${Fmt.moneySmart(entry.amount.abs())}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: deduction ? brand.error : brand.success,
                ),
              ),
              Text(
                Fmt.day(entry.earnedOn),
                style: TextStyle(fontSize: 11, color: brand.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
