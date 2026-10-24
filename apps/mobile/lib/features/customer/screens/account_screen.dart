import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/push_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/launcher.dart';
import '../../../shared/widgets/states.dart';
import '../providers/customer_providers.dart';

/// The account tab: identity, wallet, addresses, support and sign-out.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(currentSessionProvider);
    final config = ref.watch(appConfigProvider).valueOrNull;

    if (session.isGuest) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.account)),
        body: AppEmptyState(
          title: 'Sign in to Bites Box',
          message: 'Save addresses, track orders and collect rewards.',
          icon: Icons.person_outline_rounded,
          action: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: () => context.push(Routes.signIn),
                child: const Text('Sign in'),
              ),
              TextButton(
                onPressed: () => context.push(Routes.riderSignup),
                child: const Text('Apply as a delivery partner'),
              ),
            ],
          ),
        ),
      );
    }

    final profile = session.profile;
    final wallet = ref.watch(walletProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.account)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: () => context.push(Routes.profile),
              borderRadius: BorderRadius.circular(brand.radiusMd),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      brand.secondary,
                      Color.lerp(brand.secondary, brand.ink, 0.34)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(brand.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: brand.secondary.withValues(alpha: 0.14),
                      blurRadius: 22,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      child: Text(
                        _initials(profile?.fullName),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.fullName ?? 'Bites Box customer',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            profile?.phone ?? profile?.email ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.76),
                            ),
                          ),
                          if ((profile?.totalOrders ?? 0) > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${profile!.totalOrders} order${profile.totalOrders == 1 ? '' : 's'} with us',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: brand.accent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          wallet.when(
            loading: () => config == null || config.flag('wallet')
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _WalletBalanceCard(
                      brand: brand,
                      loading: true,
                      onTap: () => context.push(Routes.wallet),
                    ),
                  )
                : const SizedBox.shrink(),
            error: (_, __) => config?.flag('wallet') == true
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _WalletBalanceCard(
                      brand: brand,
                      error: true,
                      onTap: () => ref.invalidate(walletProvider),
                    ),
                  )
                : const SizedBox.shrink(),
            data: (summary) => summary.enabled
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _WalletBalanceCard(
                      brand: brand,
                      balance: summary.balance,
                      onTap: () => context.push(Routes.wallet),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          _Group(
            title: 'Ordering',
            tiles: [
              _Tile(
                icon: Icons.favorite_border_rounded,
                label: l10n.favorites,
                onTap: () => context.push(Routes.favorites),
              ),
              _Tile(
                icon: Icons.card_giftcard_rounded,
                label: l10n.referrals,
                onTap: () => context.push(Routes.referrals),
              ),
              _Tile(
                icon: Icons.location_on_outlined,
                label: 'Delivery addresses',
                onTap: () => context.push(Routes.addresses),
              ),
              _Tile(
                icon: Icons.local_offer_outlined,
                label: 'Offers and coupons',
                onTap: () => context.push(Routes.offers),
              ),
              _Tile(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                badge: unread > 0 ? '$unread' : null,
                onTap: () => context.push(Routes.notifications),
              ),
            ],
          ),
          _Group(
            title: 'Help',
            tiles: [
              _Tile(
                icon: Icons.support_agent_rounded,
                label: 'Help and support',
                onTap: () => context.push(Routes.support),
              ),
              if (config?.supportPhone != null)
                _Tile(
                  icon: Icons.call_outlined,
                  label: 'Call the restaurant',
                  subtitle: config!.supportPhone,
                  onTap: () => Launcher.dial(config.supportPhone),
                ),
              if (config?.whatsappPhone != null)
                _Tile(
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp us',
                  onTap: () => Launcher.whatsapp(config!.whatsappPhone),
                ),
            ],
          ),
          _Group(
            title: 'Information',
            tiles: [
              _Tile(
                icon: Icons.description_outlined,
                label: 'Policies and terms',
                onTap: () => context.push(Routes.policies),
              ),
              _Tile(
                icon: Icons.help_outline_rounded,
                label: 'Frequently asked questions',
                onTap: () => context.push(Routes.faqs),
              ),
            ],
          ),
          if (session.isManagement || session.isKitchen || session.isRider)
            _Group(
              title: 'Staff',
              tiles: [
                if (session.isKitchen || session.isManagement)
                  _Tile(
                    icon: Icons.soup_kitchen_outlined,
                    label: 'Open the kitchen board',
                    onTap: () => context.go(Routes.kitchen),
                  ),
                if (session.isRider)
                  _Tile(
                    icon: Icons.two_wheeler_outlined,
                    label: 'Open my deliveries',
                    onTap: () => context.go(Routes.rider),
                  ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: OutlinedButton.icon(
              onPressed: () => _signOut(context, ref),
              icon: Icon(Icons.logout_rounded, size: 18, color: brand.error),
              label: Text('Sign out', style: TextStyle(color: brand.error)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: brand.error.withValues(alpha: 0.35)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              '${config?.branchName ?? 'Bites Box'} · ${ref.watch(environmentProvider)}',
              style: TextStyle(fontSize: 11.5, color: brand.inkMuted),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String? name) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return 'BB';

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppFeedback.confirm(
      context,
      title: 'Sign out?',
      message: 'You will need your mobile number to sign back in.',
      confirmLabel: 'Sign out',
      destructive: true,
    );

    if (!confirmed) return;
    await ref
        .read(sessionProvider.notifier)
        .signOut(deviceToken: ref.read(pushTokenProvider));
  }
}

class _WalletBalanceCard extends StatelessWidget {
  const _WalletBalanceCard({
    required this.brand,
    required this.onTap,
    this.balance,
    this.loading = false,
    this.error = false,
  });

  final BrandTokens brand;
  final VoidCallback? onTap;
  final double? balance;
  final bool loading;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: brand.secondary,
      borderRadius: BorderRadius.circular(brand.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wallet balance',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 12.5,
                      ),
                    ),
                    if (loading)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 62,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    else
                      Text(
                        error ? 'Tap to retry' : Fmt.moneySmart(balance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.tiles});

  final String title;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    if (tiles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                color: brand.inkMuted,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: brand.surface,
              borderRadius: BorderRadius.circular(brand.radiusLg),
              border: Border.all(color: brand.hairline.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                  color: brand.ink.withValues(alpha: 0.03),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var index = 0; index < tiles.length; index++) ...[
                  if (index > 0)
                    Divider(height: 1, color: brand.hairline, indent: 48),
                  tiles[index],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: brand.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 19, color: brand.primary),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: brand.ink,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: brand.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 20, color: brand.inkMuted),
        ],
      ),
    );
  }
}
