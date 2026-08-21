import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';
import '../data/menu_models.dart';
import '../providers/customer_providers.dart';
import '../widgets/cart_bar.dart';
import '../widgets/home_sections.dart';

/// The storefront.
///
/// Every section, its order and its contents come from the CMS tables, so
/// merchandising is an operator decision rather than a release.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final feed = ref.watch(homeFeedProvider);
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(currentSessionProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(greetingName: session.profile?.firstName),
            Expanded(
              child: RefreshIndicator(
                color: brand.primary,
                onRefresh: () async {
                  ref.invalidate(homeFeedProvider);
                  ref.invalidate(appConfigProvider);
                  ref.invalidate(activeOrdersProvider);
                  await ref.read(homeFeedProvider.future);
                },
                child: AsyncValueView<HomeFeed>(
                  value: feed,
                  onRetry: () => ref.invalidate(homeFeedProvider),
                  loading: const _HomeSkeleton(),
                  data: (data) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      FoodImage.primeAll(data.imagePaths);
                    });
                    return ListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      children: [
                        // Store state is the first thing a customer needs to know.
                        config.maybeWhen(
                          data: (value) => value.acceptingOrders
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    0,
                                  ),
                                  child: AppNotice(
                                    tone: NoticeTone.caution,
                                    icon: Icons.storefront_outlined,
                                    message: value.closedMessage,
                                  ),
                                ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                        const ActiveOrderStrip(),
                        if (data.sections.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 60),
                            child: AppEmptyState(
                              title: 'Nothing here yet',
                              message:
                                  'Our menu is being set up. Please check back shortly.',
                              icon: Icons.restaurant_outlined,
                            ),
                          )
                        else
                          ...data.sections.map(
                            (section) => HomeSectionView(section: section),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CartBar(),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({this.greetingName});

  final String? greetingName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final address = ref.watch(selectedAddressProvider);
    final session = ref.watch(currentSessionProvider);
    final config = ref.watch(appConfigProvider).valueOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: session.isGuest
                      ? () => context.push(Routes.signIn)
                      : () => context.push(Routes.addresses),
                  borderRadius: BorderRadius.circular(brand.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 18,
                          color: brand.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.isGuest
                                    ? 'Sign in to set your address'
                                    : (address?.labelText ??
                                          'Add a delivery address'),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: brand.ink,
                                ),
                              ),
                              Text(
                                address?.secondary ??
                                    config?.branchName ??
                                    'Bakhtiyarpur',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: brand.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: brand.inkMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => context.push(
                  session.isGuest ? Routes.signIn : Routes.notifications,
                ),
                icon: Badge(
                  isLabelVisible:
                      ref.watch(unreadNotificationCountProvider) > 0,
                  backgroundColor: brand.primary,
                  child: const Icon(Icons.notifications_none_rounded),
                ),
                tooltip: 'Notifications',
              ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => context.push(Routes.search),
            borderRadius: BorderRadius.circular(brand.radiusMd),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: brand.surface,
                borderRadius: BorderRadius.circular(brand.radiusMd),
                border: Border.all(color: brand.hairline),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 20, color: brand.inkMuted),
                  const SizedBox(width: 10),
                  Text(
                    greetingName == null
                        ? 'Search for biryani, litti, thali…'
                        : 'Hungry, $greetingName? Search the menu',
                    style: TextStyle(fontSize: 14.5, color: brand.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SkeletonBox(height: 152, radius: 20),
        SizedBox(height: 26),
        SkeletonBox(width: 180, height: 20),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 116, radius: 14)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 116, radius: 14)),
          ],
        ),
        SizedBox(height: 26),
        SkeletonBox(width: 140, height: 20),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 180, radius: 14)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 180, radius: 14)),
          ],
        ),
      ],
    );
  }
}
