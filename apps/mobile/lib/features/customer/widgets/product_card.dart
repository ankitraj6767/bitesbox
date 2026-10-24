import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../data/cart_models.dart';
import '../data/menu_models.dart';
import '../providers/cart_controller.dart';
import 'favorite_button.dart';
import 'product_sheet.dart';

Future<void> _addProductToCart(
  BuildContext context,
  WidgetRef ref,
  MenuProduct product,
) async {
  if (product.hasVariants) {
    ProductSheet.show(context, productId: product.id);
    return;
  }

  try {
    await ref.read(cartProvider.notifier).addItem(productId: product.id);
  } catch (error) {
    if (!context.mounted) return;
    if (error is AppError &&
        (error.code == ErrorCodes.modifierSelectionRequired ||
            error.code == ErrorCodes.variantRequired)) {
      ProductSheet.show(context, productId: product.id);
      return;
    }
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
/// The add control is a stepper when exactly one configuration of the dish is in
/// the cart, and an "Add" button otherwise — a customer who ordered two different
/// sizes must be sent back to the sheet rather than have one silently changed.
class ProductListCard extends ConsumerWidget {
  const ProductListCard({required this.product, super.key});

  final MenuProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;

    return Opacity(
      opacity: product.isAvailable ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Material(
          color: brand.surface,
          elevation: 1,
          shadowColor: brand.ink.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => ProductSheet.show(context, productId: product.id),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(12),
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
                                label: 'Bestseller',
                                icon: Icons.local_fire_department_rounded,
                                background: brand.accent.withValues(
                                  alpha: 0.14,
                                ),
                                foreground: brand.warning,
                                dense: true,
                              ),
                            ] else if (product.isNew) ...[
                              const SizedBox(width: 8),
                              AppPill(
                                label: 'New',
                                background: brand.secondary.withValues(
                                  alpha: 0.10,
                                ),
                                foreground: brand.secondary,
                                dense: true,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.25,
                            color: brand.ink,
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
          ),
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
        child: InkWell(
          onTap: () => ProductSheet.show(context, productId: product.id),
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
                      FoodImage(
                        path: product.thumbnailPath ?? product.heroImagePath,
                        fit: BoxFit.cover,
                        placeholderAsset: FoodImage.assetForPath(product.slug),
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
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${product.hasVariants ? 'from ' : ''}${Fmt.moneySmart(product.displayPrice)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: brand.ink,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
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
                          onAdd: () => _addProductToCart(context, ref, product),
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

class _MenuAddControl extends StatelessWidget {
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
  final VoidCallback onAdd;
  final ValueChanged<int>? onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    if (!product.isAvailable) {
      return Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: brand.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Currently unavailable',
          style: TextStyle(
            color: brand.inkMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (quantity > 0 && line != null && onQuantityChanged != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              quantity == 1 ? 'In your box' : '$quantity in your box',
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
            quantity: line!.quantity,
            dense: true,
            busy: busy,
            max: product.maxQuantityPerOrder ?? 50,
            onChanged: onQuantityChanged!,
          ),
        ],
      );
    }

    return SizedBox(
      height: 32,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: busy
            ? null
            : () {
                if (quantity > 0) {
                  ProductSheet.show(context, productId: product.id);
                } else {
                  onAdd();
                }
              },
        icon: Icon(
          quantity > 0 ? Icons.tune_rounded : Icons.add_rounded,
          size: 15,
        ),
        label: Text(
          quantity > 0 ? '$quantity in your box' : 'ADD',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
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
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product});

  final MenuProduct product;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Row(
      children: [
        if (product.hasVariants)
          Text('from ', style: TextStyle(fontSize: 13, color: brand.inkMuted)),
        Text(
          Fmt.moneySmart(product.displayPrice),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: brand.ink,
          ),
        ),
        if (product.hasDiscount) ...[
          const SizedBox(width: 7),
          Text(
            Fmt.moneySmart(product.comparePrice),
            style: TextStyle(
              fontSize: 13,
              color: brand.inkMuted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${product.discountPercent}% off',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: brand.success,
            ),
          ),
        ],
      ],
    );
  }
}

class _ImageWithAction extends ConsumerWidget {
  const _ImageWithAction({required this.product});

  final MenuProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final quantity = ref.watch(productCartQuantityProvider(product.id));
    final line = ref.watch(singleCartLineProvider(product.id));
    final busy = ref.watch(cartProvider).isLoading;

    return SizedBox(
      width: 112,
      child: Column(
        children: [
          Stack(
            children: [
              FoodImage(
                path: product.thumbnailPath ?? product.heroImagePath,
                width: 112,
                height: 96,
                radius: brand.radiusMd,
                placeholderAsset: FoodImage.assetForPath(product.slug),
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
            // Several configurations of this dish are in the cart: editing has to
            // happen where the customer can see which one they mean.
            OutlinedButton(
              onPressed: () =>
                  ProductSheet.show(context, productId: product.id),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(112, 34),
                padding: EdgeInsets.zero,
                foregroundColor: brand.primary,
                side: BorderSide(color: brand.primary.withValues(alpha: 0.4)),
              ),
              child: Text(
                '$quantity in cart',
                style: const TextStyle(fontSize: 12.5),
              ),
            )
          else
            OutlinedButton(
              onPressed: busy ? null : () => _add(context, ref),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(112, 34),
                padding: EdgeInsets.zero,
                foregroundColor: brand.primary,
                side: BorderSide(color: brand.primary.withValues(alpha: 0.4)),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('ADD'),
            ),
        ],
      ),
    );
  }

  /// A dish with options always opens the sheet: the server would reject an add
  /// without a variant, and guessing one for the customer is worse than asking.
  Future<void> _add(BuildContext context, WidgetRef ref) async {
    await _addProductToCart(context, ref, product);
  }

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
        onTap: () => ProductSheet.show(context, productId: product.id),
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
                          '${product.discountPercent}% OFF',
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
                          '$quantity in cart',
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
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    Fmt.moneySmart(product.displayPrice),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: brand.ink,
                    ),
                  ),
                  if (product.ratingCount > 0) ...[
                    const Spacer(),
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
}
