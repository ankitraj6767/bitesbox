import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brand_tokens.dart';
import '../../../shared/widgets/states.dart';
import '../data/menu_models.dart';
import '../providers/customer_providers.dart';
import '../widgets/product_sheet.dart';

/// A deep-linkable product page.
///
/// Inside the app a dish opens as a bottom sheet, which keeps the customer in the
/// menu. This route exists so a push notification, a banner or a shared link can
/// land directly on one dish.
class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({required this.productId, super.key});

  final String productId;

  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final detail = ref.watch(productDetailProvider(widget.productId));

    // Once the dish resolves, present the same sheet the menu uses. A single
    // configuration UI means the variant and modifier rules can never diverge.
    if (!_opened && detail.hasValue) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ProductSheet.show(context, productId: widget.productId);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.valueOrNull?.product.name ?? 'Dish'),
      ),
      body: AsyncValueView<ProductDetail>(
        value: detail,
        onRetry: () => ref.invalidate(productDetailProvider(widget.productId)),
        data: (data) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_menu_rounded,
                  size: 40,
                  color: brand.inkMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  data.product.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: brand.ink,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () =>
                      ProductSheet.show(context, productId: widget.productId),
                  child: const Text('Choose options'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
