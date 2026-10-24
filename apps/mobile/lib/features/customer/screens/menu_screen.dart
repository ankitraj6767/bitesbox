import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/customer_copy.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';
import '../data/menu_models.dart';
import '../providers/customer_providers.dart';
import '../widgets/cart_bar.dart';
import '../widgets/product_card.dart';

/// A full-width menu for discovering food, narrowing the catalogue and ordering.
/// Sold-out dishes remain visible unless the customer filters them out.
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(menuCatalogProvider);
    final filters = ref.watch(menuFiltersProvider);

    return Scaffold(
      backgroundColor: brand.surfaceMuted,
      body: SafeArea(
        child: AsyncValueView<MenuCatalog>(
          value: catalog,
          onRetry: () => ref.invalidate(menuCatalogProvider),
          loading: const _MenuSkeleton(),
          data: (data) {
            final categories = data.categories
                .where((category) => data.forCategory(category.id).isNotEmpty)
                .toList();

            if (data.products.isEmpty || categories.isEmpty) {
              return AppEmptyState(
                title: l10n.menuEmptyTitle,
                message: l10n.menuEmptyMessage,
                icon: Icons.restaurant_menu_outlined,
              );
            }

            MenuCategory? selectedCategory;
            for (final category in categories) {
              if (category.id == filters.categoryId) {
                selectedCategory = category;
                break;
              }
            }
            final source = selectedCategory == null
                ? data.products
                : data.forCategory(selectedCategory.id);
            final products = source.where(filters.matches).toList()
              ..sort((a, b) => _compareProducts(a, b, filters.sortOrder));

            return RefreshIndicator(
              color: brand.primary,
              onRefresh: () async {
                ref.invalidate(menuCatalogProvider);
                await ref.read(menuCatalogProvider.future);
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _MenuMasthead(
                      brandName: brand.name,
                      onSearch: () => context.push(Routes.search),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _MenuSpotlight(
                      tagline: brand.tagline,
                      product: data.products.firstWhere(
                        (item) => item.isFeatured || item.isBestSeller,
                        orElse: () => data.products.first,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _SectionHeading(
                      title: context.customerText("Browse by craving"),
                      detail: context.customerText(
                        context.customerText("A little something for every mood"),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _CategoryPicker(
                      categories: categories,
                      selectedId: selectedCategory?.id,
                      totalCount: data.products.length,
                      onSelect: (id) {
                        ref
                            .read(menuFiltersProvider.notifier)
                            .update(
                              (value) => value.copyWith(
                                categoryId: id,
                                clearCategory: id == null,
                              ),
                            );
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _MenuControls(
                      title: selectedCategory?.name ?? context.customerText("All dishes"),
                      count: products.length,
                      filters: filters,
                      onSort: () => _openFilters(context, filters),
                      onFilter: () => _openFilters(context, filters),
                      onClear: () => ref
                          .read(menuFiltersProvider.notifier)
                          .update(
                            (value) => MenuFilters(
                              categoryId: value.categoryId,
                              sortOrder: MenuSortOrder.recommended,
                            ),
                          ),
                    ),
                  ),
                  if (products.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppEmptyState(
                        title: l10n.nothingMatches,
                        message: filters.isActive
                            ? l10n.clearFiltersMessage
                            : l10n.categoryEmptyMessage,
                        icon: Icons.filter_alt_off_outlined,
                        action: filters.isActive
                            ? OutlinedButton(
                                onPressed: () => ref
                                    .read(menuFiltersProvider.notifier)
                                    .update(
                                      (value) => MenuFilters(
                                        categoryId: value.categoryId,
                                      ),
                                    ),
                                child: Text(l10n.clearFilters),
                              )
                            : null,
                      ),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 124),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.crossAxisExtent;
                          final columns = width >= 760 ? 3 : 2;
                          return SliverGrid.builder(
                            itemCount: products.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisExtent: 292,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 14,
                                ),
                            itemBuilder: (context, index) =>
                                MenuProductCard(product: products[index]),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const CartBar(),
    );
  }

  Future<void> _openFilters(BuildContext context, MenuFilters current) async {
    final updated = await showModalBottomSheet<MenuFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.brand.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _MenuFilterSheet(filters: current),
    );
    if (updated != null && mounted) {
      ref.read(menuFiltersProvider.notifier).state = updated;
    }
  }
}

int _compareProducts(MenuProduct a, MenuProduct b, MenuSortOrder order) {
  switch (order) {
    case MenuSortOrder.popular:
      final bestseller = (b.isBestSeller ? 1 : 0).compareTo(
        a.isBestSeller ? 1 : 0,
      );
      if (bestseller != 0) return bestseller;
      final rating = b.ratingAverage.compareTo(a.ratingAverage);
      if (rating != 0) return rating;
      return a.displayOrder.compareTo(b.displayOrder);
    case MenuSortOrder.priceLowToHigh:
      final price = a.displayPrice.compareTo(b.displayPrice);
      return price != 0 ? price : a.displayOrder.compareTo(b.displayOrder);
    case MenuSortOrder.topRated:
      final rating = b.ratingAverage.compareTo(a.ratingAverage);
      if (rating != 0) return rating;
      final count = b.ratingCount.compareTo(a.ratingCount);
      return count != 0 ? count : a.displayOrder.compareTo(b.displayOrder);
    case MenuSortOrder.recommended:
      return a.displayOrder.compareTo(b.displayOrder);
  }
}

class _MenuMasthead extends StatelessWidget {
  const _MenuMasthead({required this.brandName, required this.onSearch});

  final String brandName;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: brand.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.ramen_dining_rounded, color: brand.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brandName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                    color: brand.ink,
                  ),
                ),
                Text(
                  context.customerText('A table full of good things'),
                  style: TextStyle(fontSize: 11.5, color: brand.inkMuted),
                ),
              ],
            ),
          ),
          Material(
            color: brand.surface,
            shape: CircleBorder(side: BorderSide(color: brand.hairline)),
            child: IconButton(
              onPressed: onSearch,
              tooltip: AppLocalizations.of(context).searchMenu,
              icon: Icon(Icons.search_rounded, color: brand.ink, size: 21),
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSpotlight extends StatelessWidget {
  const _MenuSpotlight({required this.tagline, required this.product});

  final String tagline;
  final MenuProduct product;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 154,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: brand.secondary),
              FoodImage(
                path: product.heroImagePath ?? product.thumbnailPath,
                fit: BoxFit.cover,
                placeholderAsset: FoodImage.assetForPath(product.slug),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      brand.secondary.withValues(alpha: 0.98),
                      brand.secondary.withValues(alpha: 0.86),
                      brand.secondary.withValues(alpha: 0.25),
                    ],
                    stops: const [0, 0.52, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 18, 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: brand.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'THE BITES BOX MENU',
                        style: TextStyle(
                          color: brand.accent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.customerText('A little more\nto look forward to.'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.55,
                      ),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      width: 224,
                      child: Text(
                        tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 13,
                top: 13,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FoodTypeMark(foodType: product.foodType, size: 12),
                      const SizedBox(width: 5),
                      Text(
                        switch (product.foodType) {
                          'NON_VEG' => 'NON-VEG',
                          'EGG' => 'EGG',
                          'VEGAN' => 'VEGAN',
                          _ => 'VEG',
                        },
                        style: TextStyle(
                          color: brand.ink,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.45,
                    color: brand.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(fontSize: 12, color: brand.inkMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, size: 17, color: brand.inkMuted),
        ],
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.selectedId,
    required this.totalCount,
    required this.onSelect,
  });

  final List<MenuCategory> categories;
  final String? selectedId;
  final int totalCount;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CategoryOption(
              label: context.customerText("All"),
              count: totalCount,
              selected: selectedId == null,
              onTap: () => onSelect(null),
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [brand.primary, brand.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            );
          }

          final category = categories[index - 1];
          return _CategoryOption(
            label: category.name,
            count: category.productCount > 0 ? category.productCount : null,
            selected: selectedId == category.id,
            onTap: () => onSelect(category.id),
            child: FoodImage(
              path: category.thumbnailPath ?? category.imagePath,
              width: 66,
              height: 66,
              radius: 999,
              placeholderAsset: FoodImage.assetForCategory(category.slug),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Semantics(
      button: true,
      selected: selected,
      label: count == null
          ? label
          : context.customerText(
              '{label}, {count} dishes',
              values: {'label': label, 'count': count},
            ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 74,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? brand.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: child,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? brand.primaryDark : brand.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuControls extends StatelessWidget {
  const _MenuControls({
    required this.title,
    required this.count,
    required this.filters,
    required this.onSort,
    required this.onFilter,
    required this.onClear,
  });

  final String title;
  final int count;
  final MenuFilters filters;
  final VoidCallback onSort;
  final VoidCallback onFilter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: brand.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.customerText(
                        count == 1
                            ? '{count} dish to discover'
                            : '{count} dishes to discover',
                        values: {'count': count},
                      ),
                      style: TextStyle(fontSize: 12, color: brand.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ControlButton(
                icon: Icons.swap_vert_rounded,
                label: _sortLabel(context, filters.sortOrder),
                active: filters.sortOrder != MenuSortOrder.recommended,
                onTap: onSort,
              ),
              const SizedBox(width: 8),
              _ControlButton(
                icon: Icons.tune_rounded,
                label: filters.activeCount == 0
                    ? context.customerText('Filter')
                    : context.customerText(
                        'Filter {count}',
                        values: {'count': filters.activeCount},
                      ),
                active: filters.isActive,
                onTap: onFilter,
              ),
            ],
          ),
          if (filters.isActive) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (filters.vegOnly)
                  _ActiveFilterPill(
                    label: context.customerText("Vegetarian"),
                    icon: Icons.eco_rounded,
                  ),
                if (filters.nonVegOnly)
                  _ActiveFilterPill(
                    label: context.customerText("Non-veg"),
                    icon: Icons.set_meal_rounded,
                  ),
                if (filters.bestSellersOnly)
                  _ActiveFilterPill(
                    label: context.customerText("Bestsellers"),
                    icon: Icons.local_fire_department_rounded,
                  ),
                if (filters.hideUnavailable)
                  _ActiveFilterPill(
                    label: context.customerText("Available now"),
                    icon: Icons.check_circle_outline_rounded,
                  ),
                TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(context.customerText("Clear all")),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _sortLabel(BuildContext context, MenuSortOrder order) => switch (order) {
  MenuSortOrder.recommended => context.customerText("Sort"),
  MenuSortOrder.popular => context.customerText("Popular"),
  MenuSortOrder.priceLowToHigh => context.customerText("Price"),
  MenuSortOrder.topRated => context.customerText("Top rated"),
};

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Material(
      color: active ? brand.primary.withValues(alpha: 0.1) : brand.surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: active
                  ? brand.primary.withValues(alpha: 0.35)
                  : brand.hairline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: active ? brand.primaryDark : brand.ink,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: active ? brand.primaryDark : brand.ink,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterPill extends StatelessWidget {
  const _ActiveFilterPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: brand.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: brand.primaryDark),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: brand.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuFilterSheet extends StatefulWidget {
  const _MenuFilterSheet({required this.filters});

  final MenuFilters filters;

  @override
  State<_MenuFilterSheet> createState() => _MenuFilterSheetState();
}

class _MenuFilterSheetState extends State<_MenuFilterSheet> {
  late MenuFilters _draft = widget.filters;

  void _toggle({
    bool? vegOnly,
    bool? nonVegOnly,
    bool? bestSellersOnly,
    bool? hideUnavailable,
  }) {
    setState(() {
      _draft = _draft.copyWith(
        vegOnly: vegOnly,
        nonVegOnly: nonVegOnly,
        bestSellersOnly: bestSellersOnly,
        hideUnavailable: hideUnavailable,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 17, 12, 13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.customerText('Find your kind of good'),
                          style: TextStyle(
                            color: brand.ink,
                            fontSize: 20,
                            letterSpacing: -0.45,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.customerText('Choose what sounds right today.'),
                          style: TextStyle(color: brand.inkMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: context.customerText("Close filters"),
                    icon: Icon(Icons.close_rounded, color: brand.inkMuted),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: brand.hairline),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 17, 20, 16),
                children: [
                  _SheetSectionTitle(title: context.customerText("YOUR PREFERENCES")),
                  const SizedBox(height: 5),
                  _PreferenceTile(
                    title: context.customerText("Vegetarian"),
                    detail: context.customerText("Only plant-forward and vegetarian dishes"),
                    icon: Icons.eco_rounded,
                    iconColor: brand.veg,
                    selected: _draft.vegOnly,
                    onTap: () =>
                        _toggle(vegOnly: !_draft.vegOnly, nonVegOnly: false),
                  ),
                  _PreferenceTile(
                    title: context.customerText("Non-vegetarian"),
                    detail: context.customerText("Show dishes with meat or seafood"),
                    icon: Icons.set_meal_rounded,
                    iconColor: brand.nonVeg,
                    selected: _draft.nonVegOnly,
                    onTap: () =>
                        _toggle(nonVegOnly: !_draft.nonVegOnly, vegOnly: false),
                  ),
                  _PreferenceTile(
                    title: context.customerText("Bestsellers"),
                    detail: context.customerText("Guest favourites from the menu"),
                    icon: Icons.local_fire_department_rounded,
                    iconColor: brand.warning,
                    selected: _draft.bestSellersOnly,
                    onTap: () =>
                        _toggle(bestSellersOnly: !_draft.bestSellersOnly),
                  ),
                  _PreferenceTile(
                    title: context.customerText("Available now"),
                    detail: context.customerText("Hide dishes that are temporarily unavailable"),
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: brand.success,
                    selected: _draft.hideUnavailable,
                    onTap: () =>
                        _toggle(hideUnavailable: !_draft.hideUnavailable),
                  ),
                  const SizedBox(height: 17),
                  _SheetSectionTitle(title: context.customerText("SORT YOUR MENU")),
                  const SizedBox(height: 8),
                  _SortOption(
                    title: context.customerText("Recommended"),
                    detail: context.customerText("A balanced mix of the menu"),
                    selected: _draft.sortOrder == MenuSortOrder.recommended,
                    onTap: () => setState(
                      () => _draft = _draft.copyWith(
                        sortOrder: MenuSortOrder.recommended,
                      ),
                    ),
                  ),
                  _SortOption(
                    title: context.customerText("Popular choices"),
                    detail: context.customerText("Bestsellers and highly rated dishes first"),
                    selected: _draft.sortOrder == MenuSortOrder.popular,
                    onTap: () => setState(
                      () => _draft = _draft.copyWith(
                        sortOrder: MenuSortOrder.popular,
                      ),
                    ),
                  ),
                  _SortOption(
                    title: context.customerText("Top rated"),
                    detail: context.customerText("Highest customer ratings first"),
                    selected: _draft.sortOrder == MenuSortOrder.topRated,
                    onTap: () => setState(
                      () => _draft = _draft.copyWith(
                        sortOrder: MenuSortOrder.topRated,
                      ),
                    ),
                  ),
                  _SortOption(
                    title: context.customerText("Price: low to high"),
                    detail: context.customerText("Start with the lighter spend"),
                    selected: _draft.sortOrder == MenuSortOrder.priceLowToHigh,
                    onTap: () => setState(
                      () => _draft = _draft.copyWith(
                        sortOrder: MenuSortOrder.priceLowToHigh,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: brand.hairline),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(
                      () => _draft = MenuFilters(
                        categoryId: widget.filters.categoryId,
                      ),
                    ),
                    child: Text(
                      context.customerText('Reset'),
                      style: TextStyle(
                        color: brand.inkMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, _draft),
                        style: FilledButton.styleFrom(
                          backgroundColor: brand.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          context.customerText(
                            _draft.activeCount > 0
                                ? 'Show dishes ({count})'
                                : 'Show dishes',
                            values: {'count': _draft.activeCount},
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: context.brand.inkMuted,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.05,
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.title,
    required this.detail,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String detail;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: brand.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(color: brand.inkMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? brand.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? brand.primary : brand.hairline,
                  width: selected ? 1 : 1.5,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: brand.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(color: brand.inkMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? brand.primary : brand.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSkeleton extends StatelessWidget {
  const _MenuSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: const [
        Row(
          children: [
            SkeletonBox(width: 42, height: 42, radius: 14),
            SizedBox(width: 11),
            Expanded(child: SkeletonBox(height: 38, radius: 10)),
            SizedBox(width: 12),
            SkeletonBox(width: 44, height: 44, radius: 999),
          ],
        ),
        SizedBox(height: 16),
        SkeletonBox(height: 154, radius: 24),
        SizedBox(height: 24),
        SkeletonBox(width: 170, height: 20, radius: 8),
        SizedBox(height: 14),
        SkeletonBox(height: 95, radius: 18),
        SizedBox(height: 24),
        SkeletonBox(width: 130, height: 20, radius: 8),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 280, radius: 20)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 280, radius: 20)),
          ],
        ),
      ],
    );
  }
}
