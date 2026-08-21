import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/widgets/states.dart';
import '../data/menu_models.dart';
import '../providers/customer_providers.dart';
import '../widgets/cart_bar.dart';
import '../widgets/product_card.dart';

/// The full menu: a category rail on the left, dishes on the right.
///
/// Availability is whatever the server said when the catalogue was fetched, and a
/// sold-out dish stays visible but cannot be added — hiding it would leave a
/// customer wondering where their favourite went.
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final _scrollController = ScrollController();
  bool _categoriesExpanded = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final catalog = ref.watch(menuCatalogProvider);
    final filters = ref.watch(menuFiltersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Our menu'),
        actions: [
          IconButton(
            onPressed: () => context.push(Routes.search),
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search the menu',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _FilterRow(filters: filters),
        ),
      ),
      body: AsyncValueView<MenuCatalog>(
        value: catalog,
        onRetry: () => ref.invalidate(menuCatalogProvider),
        loading: const _MenuSkeleton(),
        data: (data) {
          final categories = data.categories
              .where((category) => data.forCategory(category.id).isNotEmpty)
              .toList();

          if (categories.isEmpty) {
            return const AppEmptyState(
              title: 'The menu is empty',
              message: 'Dishes are being added. Please check back shortly.',
              icon: Icons.restaurant_menu_outlined,
            );
          }

          final selectedId = filters.categoryId ?? categories.first.id;

          final products = data
              .forCategory(selectedId)
              .where(filters.matches)
              .toList();

          return Row(
            children: [
              _CategoryRail(
                categories: categories,
                selectedId: selectedId,
                expanded: _categoriesExpanded,
                onToggle: () =>
                    setState(() => _categoriesExpanded = !_categoriesExpanded),
                onSelect: (id) {
                  ref
                      .read(menuFiltersProvider.notifier)
                      .update((value) => value.copyWith(categoryId: id));
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(0);
                  }
                },
              ),
              Expanded(
                child: products.isEmpty
                    ? AppEmptyState(
                        title: 'Nothing matches',
                        message: filters.isActive
                            ? 'Try clearing your filters to see more dishes.'
                            : 'This category has no dishes right now.',
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
                                child: const Text('Clear filters'),
                              )
                            : null,
                      )
                    : RefreshIndicator(
                        color: brand.primary,
                        onRefresh: () async {
                          ref.invalidate(menuCatalogProvider);
                          await ref.read(menuCatalogProvider.future);
                        },
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: products.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: brand.hairline,
                            indent: 16,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, index) =>
                              ProductListCard(product: products[index]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const CartBar(),
    );
  }
}

class _FilterRow extends ConsumerWidget {
  const _FilterRow({required this.filters});

  final MenuFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final notifier = ref.read(menuFiltersProvider.notifier);

    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: brand.hairline)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _FilterChip(
            label: 'Veg only',
            icon: Icons.eco_rounded,
            selected: filters.vegOnly,
            onTap: () => notifier.update(
              (value) =>
                  value.copyWith(vegOnly: !value.vegOnly, nonVegOnly: false),
            ),
          ),
          _FilterChip(
            label: 'Non-veg only',
            icon: Icons.set_meal_rounded,
            selected: filters.nonVegOnly,
            onTap: () => notifier.update(
              (value) =>
                  value.copyWith(nonVegOnly: !value.nonVegOnly, vegOnly: false),
            ),
          ),
          _FilterChip(
            label: 'Bestsellers',
            icon: Icons.local_fire_department_rounded,
            selected: filters.bestSellersOnly,
            onTap: () => notifier.update(
              (value) =>
                  value.copyWith(bestSellersOnly: !value.bestSellersOnly),
            ),
          ),
          _FilterChip(
            label: 'Available now',
            icon: Icons.check_circle_outline_rounded,
            selected: filters.hideUnavailable,
            onTap: () => notifier.update(
              (value) =>
                  value.copyWith(hideUnavailable: !value.hideUnavailable),
            ),
          ),
          if (filters.isActive)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: TextButton.icon(
                onPressed: () => notifier.update(
                  (value) => MenuFilters(categoryId: value.categoryId),
                ),
                icon: const Icon(Icons.close_rounded, size: 15),
                label: Text('Clear (${filters.activeCount})'),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        onSelected: (_) => onTap(),
        avatar: Icon(
          icon,
          size: 15,
          color: selected ? brand.primary : brand.inkMuted,
        ),
        label: Text(label),
        showCheckmark: false,
        selectedColor: brand.primary.withValues(alpha: 0.10),
        side: BorderSide(
          color: selected
              ? brand.primary.withValues(alpha: 0.45)
              : brand.hairline,
        ),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? brand.primary : brand.ink,
        ),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.categories,
    required this.selectedId,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
  });

  final List<MenuCategory> categories;
  final String selectedId;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: expanded ? 104 : 44,
      decoration: BoxDecoration(
        color: brand.surfaceMuted,
        border: Border(right: BorderSide(color: brand.hairline)),
      ),
      child: expanded
          ? ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: categories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: onToggle,
                      icon: const Icon(Icons.chevron_left_rounded),
                      tooltip: 'Hide categories',
                    ),
                  );
                }

                final category = categories[index - 1];
                final selected = category.id == selectedId;

                return InkWell(
                  onTap: () => onSelect(category.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? brand.surface : null,
                      border: Border(
                        left: BorderSide(
                          color: selected ? brand.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          category.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected ? brand.primary : brand.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${category.productCount}',
                          style: TextStyle(fontSize: 11, color: brand.inkMuted),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          : Column(
              children: [
                IconButton(
                  onPressed: onToggle,
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Show categories',
                ),
                const Divider(height: 1),
                Expanded(
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        'Categories',
                        style: TextStyle(fontSize: 11, color: brand.inkMuted),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MenuSkeleton extends StatelessWidget {
  const _MenuSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (_, __) => const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 60, height: 12),
                SizedBox(height: 8),
                SkeletonBox(width: 170, height: 16),
                SizedBox(height: 8),
                SkeletonBox(width: 90, height: 14),
              ],
            ),
          ),
          SizedBox(width: 14),
          SkeletonBox(width: 112, height: 96, radius: 14),
        ],
      ),
    );
  }
}
