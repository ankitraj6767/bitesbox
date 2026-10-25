import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/customer_copy.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../data/cart_models.dart';
import '../data/menu_models.dart';
import '../providers/cart_controller.dart';
import '../providers/customer_providers.dart';
import 'favorite_button.dart';

Future<void> addMenuProductToCart(
  BuildContext context,
  WidgetRef ref,
  MenuProduct product,
) async {
  try {
    final detail = await ref.read(productDetailProvider(product.id).future);
    final modifiers = <ModifierSelection>[];

    for (final group in detail.modifierGroups) {
      final available = group.modifiers
          .where((modifier) => modifier.isAvailable)
          .toList();
      final maxSelections = group.maxSelect ?? available.length;
      final selected = available
          .where((modifier) => modifier.isDefault)
          .take(group.isSingleChoice ? 1 : maxSelections)
          .toList();
      final minimum = group.isRequired
          ? (group.isSingleChoice
                ? 1
                : (group.minSelect < 1 ? 1 : group.minSelect))
          : 0;

      // One-tap add uses the configured defaults. For a required group without
      // enough defaults, use its first available choices so the cart action does
      // not unexpectedly open a separate configuration page.
      for (final modifier in available) {
        if (selected.length >= minimum || selected.length >= maxSelections) {
          break;
        }
        if (!selected.any((item) => item.id == modifier.id)) {
          selected.add(modifier);
        }
      }

      modifiers.addAll(
        selected.map((modifier) => ModifierSelection(modifierId: modifier.id)),
      );
    }

    await ref
        .read(cartProvider.notifier)
        .addItem(
          productId: detail.product.id,
          variantId: detail.defaultVariant?.id,
          quantity: product.minQuantityPerOrder,
          modifiers: modifiers,
        );
    if (!context.mounted) return;
    AppFeedback.showSuccess(
      context,
      context.customerText(
        '{name} added to your cart.',
        values: {'name': product.name},
      ),
      duration: const Duration(seconds: 1),
    );
  } catch (error) {
    if (!context.mounted) return;
    AppFeedback.showError(context, error);
  }
}

Future<void> _setProductQuantity(
  BuildContext context,
  WidgetRef ref,
  String cartItemId,
  int quantity,
) async {
  try {
    await ref
        .read(cartProvider.notifier)
        .setQuantity(cartItemId: cartItemId, quantity: quantity);
  } catch (error) {
    if (context.mounted) AppFeedback.showError(context, error);
  }
}

/// A dish on the menu list.
///
/// The add control is a stepper for a single cart configuration. If several
/// configurations are already present, another Add uses the dish defaults and
/// adds a separate line instead of changing either existing configuration.
class ProductListCard extends ConsumerWidget {
  const ProductListCard({required this.product, super.key});

  final MenuProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;

    return Opacity(
      opacity: product.isAvailable ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FoodTypeMark(foodType: product.foodType),
                      if (product.isBestSeller) ...[
                        const SizedBox(width: 8),
                        AppPill(
                          label: context.customerText("Bestseller"),
                          icon: Icons.local_fire_department_rounded,
                          background: brand.accent.withValues(alpha: 0.14),
                          foreground: brand.warning,
                          dense: true,
                        ),
                      ] else if (product.isNew) ...[
                        const SizedBox(width: 8),
                        AppPill(
                          label: context.customerText("New"),
                          background: brand.secondary.withValues(alpha: 0.10),
                          foreground: brand.secondary,
                          dense: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => context.push(Routes.product(product.id)),
                    child: Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.25,
                        color: brand.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _PriceRow(product: product),
                  if (product.ratingCount > 0) ...[
                    const SizedBox(height: 5),
                    RatingChip(
                      rating: product.ratingAverage,
                      count: product.ratingCount,
                      dense: true,
                    ),
                  ],
                  if ((product.shortDescription ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      product.shortDescription!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: brand.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
            _ImageWithAction(product: product),
          ],
        ),
      ),
    );
  }
}

/// Premium catalogue tile used by the full menu grid. Search keeps the denser
/// list layout so result scanning remains quick.
class MenuProductCard extends ConsumerWidget {
  const MenuProductCard({required this.product, super.key});

  final MenuProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final description = <String?>[product.shortDescription, product.description]
        .whereType<String>()
        .map((value) => value.trim())
        .firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => context.customerText('Prepared fresh in our kitchen'),
        );
    final mealDetail = product.servesCount != null
        ? context.customerText('Serves ${product.servesCount}')
        : product.spiceLevel != 'NONE'
        ? context.customerText(Fmt.humanise(product.spiceLevel))
        : product.dietaryTags.isNotEmpty
        ? context.customerText(
            Fmt.humanise(product.dietaryTags.first.replaceAll('-', ' ')),
          )
        : product.calories != null
        ? context.customerText('${product.calories} kcal')
        : null;
    final details = <String>[
      if (product.preparationMinutes > 0)
        context.customerText('${product.preparationMinutes} min'),
      if (mealDetail != null) mealDetail,
    ].join(' · ');
    final quantity = ref.watch(productCartQuantityProvider(product.id));
    final line = ref.watch(singleCartLineProvider(product.id));
    final busy = ref.watch(cartProvider).isLoading;

    return Opacity(
      opacity: product.isAvailable ? 1 : 0.76,
      child: Material(
        color: brand.surface,
        elevation: 1.5,
        shadowColor: brand.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 130,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: InkWell(
                        onTap: () => context.push(Routes.product(product.id)),
                        child: FoodImage(
                          path: product.thumbnailPath ?? product.heroImagePath,
                          fit: BoxFit.cover,
                          placeholderAsset: FoodImage.assetForPath(
                            product.slug,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _MenuProductBadge(product: product),
                    ),
                    Positioned(
                      right: 5,
                      top: 5,
                      child: FavoriteButton(productId: product.id),
                    ),
                    if (!product.isAvailable)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.34),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                product.unavailableReason,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FoodTypeMark(foodType: product.foodType, size: 13),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: brand.ink,
                                fontSize: 13.5,
                                height: 1.18,
                                letterSpacing: -0.15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 26,
                        child: Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: brand.inkMuted,
                            fontSize: 10.5,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        SizedBox(
                          height: 14,
                          child: Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 11,
                                color: brand.inkMuted,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  details,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: brand.inkMuted,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: ProductPrice(
                              product: product,
                              compact: true,
                            ),
                          ),
                          if (product.ratingCount > 0) ...[
                            const SizedBox(width: 4),
                            RatingChip(
                              rating: product.ratingAverage,
                              dense: true,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 7),
                      _MenuAddControl(
                        product: product,
                        quantity: quantity,
                        line: line,
                        busy: busy,
                        onAdd: () =>
                            addMenuProductToCart(context, ref, product),
                        onQuantityChanged: line == null
                            ? null
                            : (next) => _setProductQuantity(
                                context,
                                ref,
                                line.cartItemId,
                                next,
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

class _MenuProductBadge extends StatelessWidget {
  const _MenuProductBadge({required this.product});

  final MenuProduct product;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final (label, background) = product.hasDiscount
        ? ('${product.discountPercent}% OFF', brand.success)
        : product.isBestSeller
        ? ('BESTSELLER', brand.primaryDark)
        : product.isNew
        ? ('JUST IN', brand.secondary)
        : ('', Colors.transparent);
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.45,
        ),
      ),
    );
  }
}

class _MenuAddControl extends StatefulWidget {
  const _MenuAddControl({
    required this.product,
    required this.quantity,
    required this.line,
    required this.busy,
    required this.onAdd,
    required this.onQuantityChanged,
  });

  final MenuProduct product;
  final int quantity;
  final CheckoutLine? line;
  final bool busy;
  final Future<void> Function() onAdd;
  final ValueChanged<int>? onQuantityChanged;

  @override
  State<_MenuAddControl> createState() => _MenuAddControlState();
}

class _MenuAddControlState extends State<_MenuAddControl> {
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final product = widget.product;
    final quantity = widget.quantity;
    final line = widget.line;
    final quantityChanged = widget.onQuantityChanged;
    final busy = widget.busy || _adding;
    if (!product.isAvailable) {
      return Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: brand.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          context.customerText('Currently unavailable'),
          style: TextStyle(
            color: brand.inkMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (quantity > 0 && line != null && quantityChanged != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              quantity == 1
                  ? context.customerText('In your box')
                  : context.customerText(
                      '{count} in your box',
                      values: {'count': quantity},
                    ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: brand.success,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          QuantityStepper(
            quantity: line.quantity,
            dense: true,
            busy: busy,
            max: product.maxQuantityPerOrder ?? 50,
            onChanged: quantityChanged,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (quantity > 0 && line == null) ...[
          Text(
            context.customerText(
              '{count} in your box',
              values: {'count': quantity},
            ),
            style: TextStyle(
              color: brand.success,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
        ],
        SizedBox(
          height: 32,
          child: OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    setState(() => _adding = true);
                    try {
                      await widget.onAdd();
                    } finally {
                      if (mounted) setState(() => _adding = false);
                    }
                  },
            icon: Icon(Icons.add_rounded, size: 15),
            label: Text(
              context.customerText("ADD"),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: brand.primaryDark,
              side: BorderSide(color: brand.primary.withValues(alpha: 0.45)),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product});

  final MenuProduct product;

  @override
  Widget build(BuildContext context) {
    return ProductPrice(product: product, showDiscountLabel: true);
  }
}

class ProductPrice extends StatelessWidget {
  const ProductPrice({
    required this.product,
    this.compact = false,
    this.showDiscountLabel = false,
    super.key,
  });

  final MenuProduct product;
  final bool compact;
  final bool showDiscountLabel;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final currentStyle = TextStyle(
      fontSize: compact ? 12.5 : 16,
      fontWeight: FontWeight.w800,
      color: brand.ink,
    );
    final previousStyle = TextStyle(
      fontSize: compact ? 11 : 13,
      fontWeight: FontWeight.w500,
      color: brand.inkMuted,
      decoration: TextDecoration.lineThrough,
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: compact ? 4 : 6,
      runSpacing: 1,
      children: [
        if (product.hasDiscount)
          Text(Fmt.moneySmart(product.comparePrice), style: previousStyle),
        Text(
          '${product.hasVariants ? context.customerText("from ") : ''}${Fmt.moneySmart(product.displayPrice)}',
          style: currentStyle,
        ),
        if (showDiscountLabel && product.hasDiscount)
          Text(
            context.customerText('${product.discountPercent}% off'),
            style: TextStyle(
              fontSize: compact ? 10.5 : 12,
              fontWeight: FontWeight.w700,
              color: brand.success,
            ),
          ),
      ],
    );
  }
}

class _ImageWithAction extends ConsumerStatefulWidget {
  const _ImageWithAction({required this.product});

  final MenuProduct product;

  @override
  ConsumerState<_ImageWithAction> createState() => _ImageWithActionState();
}

class _ImageWithActionState extends ConsumerState<_ImageWithAction> {
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final product = widget.product;
    final quantity = ref.watch(productCartQuantityProvider(product.id));
    final line = ref.watch(singleCartLineProvider(product.id));
    final busy = ref.watch(cartProvider).isLoading || _adding;

    return SizedBox(
      width: 112,
      child: Column(
        children: [
          Stack(
            children: [
              InkWell(
                onTap: () => context.push(Routes.product(product.id)),
                borderRadius: BorderRadius.circular(brand.radiusMd),
                child: FoodImage(
                  path: product.thumbnailPath ?? product.heroImagePath,
                  width: 112,
                  height: 96,
                  radius: brand.radiusMd,
                  placeholderAsset: FoodImage.assetForPath(product.slug),
                ),
              ),
              if (!product.isAvailable)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(brand.radiusMd),
                    ),
                    child: Center(
                      child: Text(
                        product.unavailableReason,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 5,
                top: 5,
                child: FavoriteButton(productId: product.id),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!product.isAvailable)
            const SizedBox(height: 32)
          else if (quantity > 0 && line != null)
            QuantityStepper(
              quantity: line.quantity,
              busy: busy,
              max: product.maxQuantityPerOrder ?? 50,
              onChanged: (next) =>
                  _setQuantity(context, ref, line.cartItemId, next),
            )
          else if (quantity > 0)
            Column(
              children: [
                Text(
                  context.customerText(
                    '{count} in cart',
                    values: {'count': quantity},
                  ),
                  maxLines: 1,
                  style: TextStyle(
                    color: brand.success,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                _addButton(context, busy),
              ],
            )
          else
            _addButton(context, busy),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    setState(() => _adding = true);
    try {
      await addMenuProductToCart(context, ref, widget.product);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Widget _addButton(BuildContext context, bool busy) => OutlinedButton.icon(
    onPressed: busy ? null : () => _add(context, ref),
    icon: const Icon(Icons.add_rounded, size: 15),
    label: Text(context.customerText("ADD")),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(112, 34),
      padding: EdgeInsets.zero,
      foregroundColor: context.brand.primary,
      side: BorderSide(color: context.brand.primary.withValues(alpha: 0.4)),
      textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
    ),
  );

  Future<void> _setQuantity(
    BuildContext context,
    WidgetRef ref,
    String cartItemId,
    int quantity,
  ) async {
    await _setProductQuantity(context, ref, cartItemId, quantity);
  }
}

/// The compact card used in home-screen carousels.
class ProductRailCard extends ConsumerWidget {
  const ProductRailCard({required this.product, super.key});

  final MenuProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final quantity = ref.watch(productCartQuantityProvider(product.id));

    return SizedBox(
      width: 156,
      child: InkWell(
        onTap: () => context.push(Routes.product(product.id)),
        borderRadius: BorderRadius.circular(brand.radiusMd),
        child: Opacity(
          opacity: product.isAvailable ? 1 : 0.55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  FoodImage(
                    path: product.thumbnailPath ?? product.heroImagePath,
                    width: 156,
                    height: 116,
                    radius: brand.radiusMd,
                    placeholderAsset: FoodImage.assetForPath(product.slug),
                  ),
                  if (product.hasDiscount)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: brand.success,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          context.customerText(
                            '${product.discountPercent}% OFF',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 5,
                    top: 5,
                    child: FavoriteButton(productId: product.id),
                  ),
                  if (quantity > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: brand.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          context.customerText(
                            '{count} in cart',
                            values: {'count': quantity},
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FoodTypeMark(foodType: product.foodType, size: 12),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: brand.ink,
                      ),
                    ),
                  ),
                ],
              ),
              if (product.reasonCode != null) ...[
                const SizedBox(height: 3),
                Text(
                  context.customerText(_tasteReason(product.reasonCode!)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: brand.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: ProductPrice(product: product, compact: true),
                  ),
                  if (product.ratingCount > 0) ...[
                    const SizedBox(width: 4),
                    RatingChip(rating: product.ratingAverage, dense: true),
                  ],
                ],
              ),
              if (!product.isAvailable) ...[
                const SizedBox(height: 4),
                Text(
                  product.unavailableReason,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: brand.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _tasteReason(String code) => switch (code) {
    'FAVORITE_CATEGORY' => 'From a category you like',
    'ORDERED_BEFORE' => 'You ordered this before',
    'SAVED_FAVORITE' => 'You saved this',
    'POSITIVE_REVIEW' => 'You rated this highly',
    'MILD_SPICE' => 'Mild spice',
    'FOOD_TYPE_MATCH' => 'Matches a food type you chose',
    'POPULAR_AT_OUTLET' => 'Popular at this outlet',
    'POPULAR_MENU_PICK' => 'Popular on our menu',
    'CURATED_MENU_PICK' => 'Picked for our menu',
    'CUSTOMER_RATED_MENU_PICK' => 'Customer-rated dish',
    _ => 'Matches your taste profile',
  };
}
