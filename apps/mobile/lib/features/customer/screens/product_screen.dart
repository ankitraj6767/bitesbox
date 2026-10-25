import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../l10n/customer_copy.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';
import '../data/menu_models.dart';
import '../providers/cart_controller.dart';
import '../providers/customer_providers.dart';
import '../widgets/cart_bar.dart';
import '../widgets/favorite_button.dart';
import '../widgets/product_card.dart';

/// Full dish page opened from a dish photo or a shared product link.
class ProductScreen extends ConsumerWidget {
  const ProductScreen({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final detail = ref.watch(productDetailProvider(productId));
    final product = detail.valueOrNull?.product;
    final options = detail.valueOrNull;
    final cartQuote = ref.watch(cartQuoteProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(product?.name ?? context.customerText('Dish')),
        actions: [
          if (product != null)
            FavoriteButton(productId: productId, filledBackground: false),
        ],
      ),
      body: AsyncValueView<ProductDetail>(
        value: detail,
        onRetry: () => ref.invalidate(productDetailProvider(productId)),
        data: (data) => _ProductDetails(detail: data),
      ),
      bottomNavigationBar: options == null
          ? null
          : !cartQuote.isEmpty
          ? CartBar(
              actionLabel: 'Checkout',
              destination: Routes.checkout,
              onAdd: product?.isAvailable == true
                  ? () async {
                      await addMenuProductToCart(context, ref, options.product);
                    }
                  : null,
            )
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                decoration: BoxDecoration(
                  color: brand.surface,
                  border: Border(top: BorderSide(color: brand.hairline)),
                ),
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: product?.isAvailable == true
                        ? () async {
                            await addMenuProductToCart(
                              context,
                              ref,
                              options.product,
                            );
                          }
                        : null,
                    child: Text(context.customerText('Add to cart')),
                  ),
                ),
              ),
            ),
    );
  }
}

class _ProductDetails extends StatelessWidget {
  const _ProductDetails({required this.detail});

  final ProductDetail detail;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final product = detail.product;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          // Menu photos are square. Matching the hero viewport to that aspect
          // ratio and expanding its child keeps the full photo edge-to-edge.
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FoodImage(
                  path: product.heroImagePath ?? product.thumbnailPath,
                  radius: 0,
                  fit: BoxFit.cover,
                  placeholderAsset: FoodImage.assetForPath(product.slug),
                ),
                if (product.hasDiscount)
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: brand.success,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        context.customerText('${product.discountPercent}% OFF'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FoodTypeMark(foodType: product.foodType),
                    if (detail.categoryName != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        context.customerText(detail.categoryName!),
                        style: TextStyle(
                          color: brand.inkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (product.isBestSeller) ...[
                      const SizedBox(width: 8),
                      AppPill(
                        label: context.customerText('Bestseller'),
                        background: brand.primary.withValues(alpha: 0.10),
                        foreground: brand.primaryDark,
                        dense: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.12,
                    letterSpacing: -0.6,
                    fontWeight: FontWeight.w800,
                    color: brand.ink,
                  ),
                ),
                const SizedBox(height: 10),
                ProductPrice(product: product),
                if (product.ratingCount > 0) ...[
                  const SizedBox(height: 9),
                  RatingChip(
                    rating: product.ratingAverage,
                    count: product.ratingCount,
                  ),
                ],
                if ((product.description ?? product.shortDescription ?? '')
                    .isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    product.description ?? product.shortDescription!,
                    style: TextStyle(
                      color: brand.inkMuted,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ProductStat(
                      icon: Icons.schedule_rounded,
                      label: context.customerText(
                        '{minutes} min',
                        values: {'minutes': product.preparationMinutes},
                      ),
                    ),
                    if (product.servesCount != null)
                      _ProductStat(
                        icon: Icons.people_alt_outlined,
                        label: context.customerText(
                          'Serves {count}',
                          values: {'count': product.servesCount!},
                        ),
                      ),
                    if (product.calories != null)
                      _ProductStat(
                        icon: Icons.local_fire_department_outlined,
                        label: context.customerText(
                          '{calories} kcal',
                          values: {'calories': product.calories!},
                        ),
                      ),
                    if (product.spiceLevel != 'NONE')
                      _ProductStat(
                        icon: Icons.whatshot_outlined,
                        label: context.customerText(product.spiceLevel),
                      ),
                  ],
                ),
                if (detail.variants.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    context.customerText('Available portions'),
                    style: TextStyle(
                      color: brand.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...detail.variants
                      .where((variant) => variant.isAvailable)
                      .map(
                        (variant) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  variant.name,
                                  style: TextStyle(color: brand.ink),
                                ),
                              ),
                              if (variant.comparePrice != null &&
                                  variant.comparePrice! > variant.price) ...[
                                Text(
                                  Fmt.moneySmart(variant.comparePrice),
                                  style: TextStyle(
                                    color: brand.inkMuted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 7),
                              ],
                              Text(
                                Fmt.moneySmart(variant.price),
                                style: TextStyle(
                                  color: brand.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
                if (product.allergens.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: brand.warning.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      context.customerText(
                        'Contains {allergens}',
                        values: {'allergens': product.allergens.join(', ')},
                      ),
                      style: TextStyle(
                        color: brand.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductStat extends StatelessWidget {
  const _ProductStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: brand.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: brand.inkMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: brand.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
