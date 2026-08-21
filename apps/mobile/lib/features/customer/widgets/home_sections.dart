import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../data/menu_models.dart';
import '../providers/customer_providers.dart';
import 'product_card.dart';
import 'product_sheet.dart';

/// Renders one CMS-driven home section.
///
/// The operator controls order, titles and contents from the admin dashboard; the
/// app only knows how to draw each `kind`. An unknown kind renders nothing rather
/// than an error, so publishing a new section type never breaks an old build.
class HomeSectionView extends ConsumerWidget {
  const HomeSectionView({required this.section, super.key});

  final HomeSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (section.kind) {
      'BANNER_CAROUSEL' => _BannerCarousel(section: section),
      'CATEGORY_GRID' => _CategoryGrid(section: section),
      'CATEGORY_CAROUSEL' => _CategoryCarousel(section: section),
      'PRODUCT_CAROUSEL' => _ProductCarousel(section: section),
      'PRODUCT_GRID' => _ProductGrid(section: section),
      'COUPON_STRIP' => _CouponStrip(section: section),
      'RICH_TEXT' => _RichText(section: section),
      _ => const SizedBox.shrink(),
    };
  }
}

class _SectionFrame extends StatelessWidget {
  const _SectionFrame({required this.section, required this.child});

  final HomeSection section;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final title = section.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title.isNotEmpty)
          SectionHeader(
            title: title,
            subtitle: section.subtitle,
            actionLabel: section.actionRoute == null
                ? null
                : section.actionLabel,
            onAction: section.actionRoute == null
                ? null
                : () => _openRoute(context, section.actionRoute!),
          )
        else
          // An untitled section still needs breathing room above it.
          const SizedBox(height: 18),
        child,
      ],
    );
  }
}

void _openRoute(BuildContext context, String route) {
  // CMS routes are relative app paths; anything unexpected falls back to the menu.
  if (route.startsWith('/')) {
    context.push(route);
  } else {
    context.push(Routes.menu);
  }
}

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.section});

  final HomeSection section;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final banners = widget.section.banners;
    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 14),
        SizedBox(
          height: 152,
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            padEnds: false,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) {
              final banner = banners[index];

              return Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 16 : 8,
                  right: index == banners.length - 1 ? 16 : 0,
                ),
                child: InkWell(
                  onTap: () => _openBanner(context, banner),
                  borderRadius: BorderRadius.circular(brand.radiusLg),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FoodImage(
                        path: banner.imagePathWide ?? banner.imagePath,
                        radius: brand.radiusLg,
                      ),
                      if ((banner.title ?? '').isNotEmpty)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(brand.radiusLg),
                            gradient: LinearGradient(
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                              colors: [
                                Colors.black.withValues(alpha: 0.62),
                                Colors.black.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((banner.badgeText ?? '').isNotEmpty)
                                  AppPill(
                                    label: banner.badgeText!,
                                    dense: true,
                                    background: brand.accent,
                                    foreground: Colors.black,
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  banner.title!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                if ((banner.subtitle ?? '').isNotEmpty)
                                  Text(
                                    banner.subtitle!,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.92,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(banners.length, (index) {
              final active = index == _page;
              return Container(
                width: active ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: active ? brand.primary : brand.hairline,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  void _openBanner(BuildContext context, HomeBanner banner) {
    switch (banner.linkKind) {
      case 'PRODUCT':
        if (banner.linkProductId != null) {
          ProductSheet.show(context, productId: banner.linkProductId!);
        }
      case 'CATEGORY':
        context.push(Routes.menu);
      case 'COUPON':
        context.push(Routes.offers);
      case 'ROUTE':
        if (banner.linkRoute != null) _openRoute(context, banner.linkRoute!);
      case 'EXTERNAL_URL':
        // External links are intentionally not auto-opened from a banner.
        break;
      default:
        break;
    }
  }
}

class _CategoryGrid extends ConsumerWidget {
  const _CategoryGrid({required this.section});

  final HomeSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = section.categories;
    if (categories.isEmpty) return const SizedBox.shrink();

    return _SectionFrame(
      section: section,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) =>
              _CategoryTile(category: categories[index]),
        ),
      ),
    );
  }
}

class _CategoryCarousel extends ConsumerWidget {
  const _CategoryCarousel({required this.section});

  final HomeSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = section.categories;
    if (categories.isEmpty) return const SizedBox.shrink();

    return _SectionFrame(
      section: section,
      child: SizedBox(
        height: 116,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) => SizedBox(
            width: 78,
            child: _CategoryTile(category: categories[index]),
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category});

  final MenuCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;

    return InkWell(
      onTap: () {
        ref
            .read(menuFiltersProvider.notifier)
            .update((filters) => filters.copyWith(categoryId: category.id));
        context.push(Routes.menu);
      },
      borderRadius: BorderRadius.circular(brand.radiusMd),
      child: Column(
        children: [
          FoodImage(
            path: category.thumbnailPath ?? category.imagePath,
            width: 66,
            height: 66,
            radius: 999,
            placeholderAsset: FoodImage.assetForCategory(category.slug),
          ),
          const SizedBox(height: 7),
          Text(
            category.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: brand.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCarousel extends StatelessWidget {
  const _ProductCarousel({required this.section});

  final HomeSection section;

  @override
  Widget build(BuildContext context) {
    if (section.products.isEmpty) return const SizedBox.shrink();

    return _SectionFrame(
      section: section,
      child: SizedBox(
        height: 210,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: section.products.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) =>
              ProductRailCard(product: section.products[index]),
        ),
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.section});

  final HomeSection section;

  @override
  Widget build(BuildContext context) {
    if (section.products.isEmpty) return const SizedBox.shrink();

    return _SectionFrame(
      section: section,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: section.products.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) =>
              ProductRailCard(product: section.products[index]),
        ),
      ),
    );
  }
}

class _CouponStrip extends StatelessWidget {
  const _CouponStrip({required this.section});

  final HomeSection section;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    if (section.coupons.isEmpty) return const SizedBox.shrink();

    return _SectionFrame(
      section: section,
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: section.coupons.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final coupon = section.coupons[index];

            return InkWell(
              onTap: () => context.push(Routes.offers),
              borderRadius: BorderRadius.circular(brand.radiusMd),
              child: Container(
                width: 232,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: brand.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(brand.radiusMd),
                  border: Border.all(
                    color: brand.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      coupon.headline,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: brand.primary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      coupon.description ?? coupon.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: brand.surface,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: brand.primary, width: 1),
                          ),
                          child: Text(
                            coupon.code,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: brand.primary,
                            ),
                          ),
                        ),
                        if (coupon.endsAt != null) ...[
                          const Spacer(),
                          Text(
                            'till ${Fmt.day(coupon.endsAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: brand.inkMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RichText extends StatelessWidget {
  const _RichText({required this.section});

  final HomeSection section;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final text = section.richText;
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();

    return _SectionFrame(
      section: section,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Text(
          text,
          style: TextStyle(fontSize: 14, height: 1.55, color: brand.inkMuted),
        ),
      ),
    );
  }
}
