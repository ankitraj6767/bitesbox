import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/states.dart';
import '../data/account_models.dart';
import '../providers/customer_providers.dart';

/// Wallet balance and ledger.
///
/// The balance is a server-maintained ledger total, not a sum of the rows shown
/// here — only the last fifty transactions are fetched, and the balance stays
/// correct regardless.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bites Box wallet')),
      body: AsyncValueView<WalletSummary>(
        value: wallet,
        onRetry: () => ref.invalidate(walletProvider),
        data: (data) {
          if (!data.enabled) {
            return const AppEmptyState(
              title: 'Wallet is not available',
              message: 'This feature is currently switched off.',
              icon: Icons.account_balance_wallet_outlined,
            );
          }

          return RefreshIndicator(
            color: brand.primary,
            onRefresh: () async {
              ref.invalidate(walletProvider);
              await ref.read(walletProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [brand.secondary, brand.secondary.withValues(alpha: 0.82)],
                    ),
                    borderRadius: BorderRadius.circular(brand.radiusLg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available balance',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        Fmt.moneyPrecise(data.balance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        data.isFrozen
                            ? 'Your wallet is on hold. Please contact support.'
                            : 'Applied to your order total automatically at checkout.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (data.isFrozen) ...[
                  const SizedBox(height: 14),
                  AppNotice(
                    tone: NoticeTone.caution,
                    message: 'While your wallet is on hold you can still pay by card, UPI or cash.',
                    action: TextButton(
                      onPressed: () => context.push(Routes.support),
                      child: const Text('Contact us'),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Transactions',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: brand.ink,
                  ),
                ),
                const SizedBox(height: 10),
                if (data.transactions.isEmpty)
                  const AppEmptyState(
                    title: 'Nothing here yet',
                    message: 'Refunds and cashback will show up here.',
                    icon: Icons.receipt_outlined,
                    compact: true,
                  )
                else
                  ...data.transactions.map(
                    (transaction) => _TransactionTile(transaction: transaction),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final debit = transaction.isDebit;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (debit ? brand.error : brand.success).withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              debit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 17,
              color: debit ? brand.error : brand.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: brand.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${transaction.kindLabel} · ${Fmt.smartDateTime(transaction.createdAt)}',
                  style: TextStyle(fontSize: 12, color: brand.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${debit ? '' : '+'}${Fmt.moneyPrecise(transaction.amount)}',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: debit ? brand.ink : brand.success,
                ),
              ),
              Text(
                'bal ${Fmt.moneySmart(transaction.balanceAfter)}',
                style: TextStyle(fontSize: 11.5, color: brand.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
