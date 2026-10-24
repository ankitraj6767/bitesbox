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
import '../widgets/customer_outlet_picker.dart';
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
    final firstName = greetingName?.trim().split(RegExp(r'\s+')).first;
    final address = ref.watch(selectedAddressProvider);
    final addressesState = ref.watch(addressesProvider);
    final sessionState = ref.watch(sessionProvider);
    final sessionLoading = sessionState.isLoading;
    final session = ref.watch(currentSessionProvider);
    final addressLoading =
        sessionLoading ||
        (!session.isGuest &&
            (addressesState.isReloading ||
                (!addressesState.hasValue && addressesState.isLoading)));
    final addressError =
        !session.isGuest &&
        addressesState.hasError &&
        !addressesState.hasValue &&
        !addressLoading;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: sessionLoading
                      ? null
                      : session.isGuest
                      ? () => context.push(Routes.signIn)
                      : () => context.push(Routes.addresses),
                  borderRadius: BorderRadius.circular(brand.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: brand.surface,
                      borderRadius: BorderRadius.circular(brand.radiusMd),
                      border: Border.all(color: brand.hairline),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: brand.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 20,
                            color: brand.primary,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: addressLoading
                              ? Semantics(
                                  label: 'Loading saved delivery address',
                                  child: const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SkeletonBox(width: 112, height: 11),
                                      SizedBox(height: 6),
                                      SkeletonBox(width: 174, height: 13),
                                    ],
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DELIVERING TO',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.0,
                                        color: brand.inkMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      session.isGuest
                                          ? 'Set your delivery address'
                                          : addressError
                                          ? 'Address unavailable'
                                          : address?.labelText ??
                                                'Add a delivery address',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                        color: brand.ink,
                                      ),
                                    ),
                                    Text(
                                      session.isGuest
                                          ? 'Choose a place after sign in'
                                          : addressError
                                          ? 'Tap to choose an address'
                                          : address == null
                                          ? 'Tap to choose where to deliver'
                                          : (address.secondary.trim().isNotEmpty
                                                ? address.secondary
                                                : '${address.city}, ${address.state}'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: brand.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 19,
                          color: brand.inkMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Material(
                color: brand.surface,
                borderRadius: BorderRadius.circular(brand.radiusMd),
                child: IconButton(
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
              ),
            ],
          ),
          const CustomerOutletPicker(),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => context.push(Routes.search),
            borderRadius: BorderRadius.circular(brand.radiusMd),
            child: Material(
              color: brand.surface,
              elevation: 2,
              shadowColor: brand.ink.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(brand.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: brand.surface,
                  borderRadius: BorderRadius.circular(brand.radiusMd),
                  border: Border.all(
                    color: brand.hairline.withValues(alpha: 0.85),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: brand.primary.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        size: 21,
                        color: brand.primary,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        firstName == null || firstName.isEmpty
                            ? 'Search dishes, cuisines, combos…'
                            : 'Craving something, $firstName?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14.5, color: brand.inkMuted),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: brand.inkMuted,
                    ),
                  ],
                ),
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
