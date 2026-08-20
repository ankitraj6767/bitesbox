import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';
import '../data/kitchen_models.dart';
import '../providers/kitchen_providers.dart';

/// Sentinel for "pause with no automatic restore", chosen so the pause sheet can
/// always pop a non-null value and a dismissal stays distinguishable.
const int _indefinitely = 0;

/// Availability control.
///
/// A timed pause is the default because it matches how a kitchen actually runs out
/// of things: the scheduled job restores the dish so nobody has to remember, and
/// the customer menu updates the moment it changes.
class KitchenAvailabilityScreen extends ConsumerWidget {
  const KitchenAvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final availability = ref.watch(kitchenAvailabilityProvider);
    final filter = ref.watch(availabilityFilterProvider).trim().toLowerCase();

    return AsyncValueView<KitchenAvailability>(
      value: availability,
      onRetry: () => ref.read(kitchenAvailabilityProvider.notifier).refresh(),
      data: (data) {
        final categories = data.categories
            .map(
              (category) => AvailabilityCategory(
                id: category.id,
                name: category.name,
                products: filter.isEmpty
                    ? category.products
                    : category.products
                        .where((product) =>
                            product.name.toLowerCase().contains(filter))
                        .toList(),
              ),
            )
            .where((category) => category.products.isNotEmpty)
            .toList();

        return Column(
          children: [
            _Toolbar(outOfStockCount: data.outOfStockCount),
            Expanded(
              child: categories.isEmpty
                  ? const AppEmptyState(
                      title: 'Nothing matches',
                      message: 'Try a different search.',
                      icon: Icons.search_off_rounded,
                    )
                  : RefreshIndicator(
                      color: brand.primary,
                      onRefresh: () =>
                          ref.read(kitchenAvailabilityProvider.notifier).refresh(),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: categories.length,
                        itemBuilder: (context, index) =>
                            _CategoryBlock(category: categories[index]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Toolbar extends ConsumerStatefulWidget {
  const _Toolbar({required this.outOfStockCount});

  final int outOfStockCount;

  @override
  ConsumerState<_Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends ConsumerState<_Toolbar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: brand.surface,
        border: Border(bottom: BorderSide(color: brand.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Search a dish',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _controller.clear();
                          ref.read(availabilityFilterProvider.notifier).state = '';
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
              ),
              onChanged: (value) {
                ref.read(availabilityFilterProvider.notifier).state = value;
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 12),
          AppPill(
            label: '${widget.outOfStockCount} off the menu',
            icon: Icons.remove_shopping_cart_outlined,
            background: widget.outOfStockCount > 0
                ? brand.error.withValues(alpha: 0.10)
                : brand.surfaceMuted,
            foreground: widget.outOfStockCount > 0 ? brand.error : brand.inkMuted,
          ),
        ],
      ),
    );
  }
}

class _CategoryBlock extends ConsumerWidget {
  const _CategoryBlock({required this.category});

  final AvailabilityCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final unavailable = category.products.where((p) => !p.isAvailable).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container
          (width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: brand.surfaceMuted,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: brand.ink,
                  ),
                ),
              ),
              if (unavailable.isEmpty)
                TextButton(
                  onPressed: () => _bulk(context, ref, available: false),
                  child: const Text('Mark all out'),
                )
              else
                TextButton(
                  onPressed: () => _bulk(context, ref, available: true),
                  child: Text('Restore ${unavailable.length}'),
                ),
            ],
          ),
        ),
        ...category.products.map((product) => _ProductRow(product: product)),
      ],
    );
  }

  /// Bulk toggles are the fastest way to close a whole section at the end of
  /// service, so they get a confirmation rather than a silent apply.
  Future<void> _bulk(
    BuildContext context,
    WidgetRef ref, {
    required bool available,
  }) async {
    final targets = category.products
        .where((product) => product.isAvailable != available)
        .map((product) => product.id)
        .toList();

    if (targets.isEmpty) return;

    final confirmed = await AppFeedback.confirm(
      context,
      title: available
          ? 'Put ${targets.length} dishes back on the menu?'
          : 'Take ${targets.length} dishes off the menu?',
      message: available
          ? 'Customers will be able to order them again immediately.'
          : 'Customers will not be able to order anything in ${category.name}.',
      confirmLabel: available ? 'Restore' : 'Take off',
      destructive: !available,
    );

    if (!confirmed) return;

    try {
      final changed =
          await ref.read(kitchenAvailabilityProvider.notifier).setBulkState(
                productIds: targets,
                availabilityState: available ? 'AVAILABLE' : 'OUT_OF_STOCK',
              );

      if (context.mounted) {
        AppFeedback.showSuccess(context, '$changed dish${changed == 1 ? '' : 'es'} updated.');
      }
    } catch (error) {
      if (context.mounted) AppFeedback.showError(context, error);
    }
  }
}

class _ProductRow extends ConsumerStatefulWidget {
  const _ProductRow({required this.product});

  final AvailabilityProduct product;

  @override
  ConsumerState<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends ConsumerState<_ProductRow> {
  bool _busy = false;

  Future<void> _toggle(bool makeAvailable) async {
    int? minutes;

    if (!makeAvailable) {
      // The sheet returns the pause length; 0 means "no auto-restore" and a
      // dismissed sheet returns null, which must not silently pause the dish.
      final choice = await AppFeedback.sheet<int>(
        context,
        builder: (_) => _PauseDurationSheet(productName: widget.product.name),
      );

      // A dismissed sheet returns null and must not pause the dish.
      if (!mounted || choice == null) return;
      minutes = choice == _indefinitely ? null : choice;
    }

    setState(() => _busy = true);

    try {
      await ref.read(kitchenAvailabilityProvider.notifier).setState(
            productId: widget.product.id,
            availabilityState: makeAvailable ? 'AVAILABLE' : 'OUT_OF_STOCK',
            minutes: minutes,
          );
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final product = widget.product;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: brand.hairline)),
      ),
      child: Row(
        children: [
          FoodImage(path: product.thumbnailPath, width: 46, height: 46, radius: 9),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FoodTypeMark(foodType: product.foodType, size: 11),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        product.name,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: product.isAvailable ? brand.ink : brand.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  product.isAvailable
                      ? Fmt.moneySmart(product.basePrice)
                      : (product.autoResumes
                          ? 'Back at ${Fmt.time(product.outOfStockUntil)}'
                          : product.stateLabel),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: product.isAvailable ? FontWeight.w500 : FontWeight.w700,
                    color: product.isAvailable ? brand.inkMuted : brand.error,
                  ),
                ),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else
            Switch.adaptive(
              value: product.isAvailable,
              onChanged: _toggle,
            ),
        ],
      ),
    );
  }
}

class _PauseDurationSheet extends StatelessWidget {
  const _PauseDurationSheet({required this.productName});

  final String productName;

  /// `_indefinitely` rather than null: popping null is indistinguishable from
  /// dismissing the sheet, which previously made this option silently do nothing.
  static const _options = <(String, int)>[
    ('30 minutes', 30),
    ('1 hour', 60),
    ('2 hours', 120),
    ('Rest of the day', 720),
    ('Until I switch it back on', _indefinitely),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeader(
            title: 'Take $productName off the menu',
            subtitle: 'It will come back automatically unless you say otherwise.',
          ),
          ..._options.map(
            (option) => ListTile(
              title: Text(option.$1),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).pop(option.$2),
            ),
          ),
        ],
      ),
    );
  }
}
