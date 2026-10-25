import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/customer_copy.dart';
import '../providers/customer_providers.dart';
import '../widgets/favorite_button.dart';
import '../widgets/product_sheet.dart';

/// Full dish page opened from a dish photo or a shared product link.
/// Portions and add-ons stay visible and selectable on this page.
class ProductScreen extends ConsumerWidget {
  const ProductScreen({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref
        .watch(productDetailProvider(productId))
        .valueOrNull
        ?.product;

    return Scaffold(
      appBar: AppBar(
        title: Text(product?.name ?? context.customerText('Dish')),
        actions: [
          if (product != null)
            FavoriteButton(productId: productId, filledBackground: false),
        ],
      ),
      body: ProductSheet(productId: productId, embedded: true),
    );
  }
}
