import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brand_tokens.dart';
import '../../../shared/feedback.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';
import '../data/cart_models.dart';
import '../data/menu_models.dart';
import '../providers/cart_controller.dart';
import '../providers/customer_providers.dart';

/// Dish configuration: variants, modifier groups and a cooking note.
///
/// The rules shown here (required groups, "pick up to 3", "first 2 free") mirror
/// the ones the database enforces. The sheet stops a customer wasting a round
/// trip; it is not what makes the order valid.
class ProductSheet extends ConsumerStatefulWidget {
  const ProductSheet({required this.productId, super.key});

  final String productId;

  static Future<void> show(BuildContext context, {required String productId}) {
    return AppFeedback.sheet<void>(
      context,
      expand: true,
      builder: (_) => ProductSheet(productId: productId),
    );
  }

  @override
  ConsumerState<ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends ConsumerState<ProductSheet> {
  final _instructions = TextEditingController();

  String? _variantId;

  /// group id → selected modifier ids, in the order they were tapped so the free
  /// allowance can be explained consistently.
  final Map<String, List<String>> _selections = {};

  int _quantity = 1;
  bool _submitting = false;
  bool _showErrors = false;

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  /// Lets the presentation widgets below mutate this state without reaching for
  /// the protected `setState`.
  void apply(VoidCallback change) => setState(change);

  /// Seeds the default variant and any default modifiers the first time the
  /// payload arrives.
  void _primeDefaults(ProductDetail detail) {
    if (_variantId != null || _selections.isNotEmpty) return;

    _variantId = detail.defaultVariant?.id;
    _quantity = detail.product.minQuantityPerOrder;

    for (final group in detail.modifierGroups) {
      final defaults = group.modifiers
          .where((modifier) => modifier.isDefault && modifier.isAvailable)
          .map((modifier) => modifier.id)
          .toList();

      if (defaults.isEmpty) continue;
      _selections[group.id] =
          group.isSingleChoice ? defaults.take(1).toList() : defaults;
    }
  }

  void _toggle(ModifierGroup group, ProductModifier modifier) {
    setState(() {
      final selected = _selections.putIfAbsent(group.id, () => []);

      if (group.isSingleChoice) {
        // A radio group: required groups cannot be emptied by tapping again.
        if (selected.contains(modifier.id) && !group.isRequired) {
          selected.clear();
        } else {
          selected
            ..clear()
            ..add(modifier.id);
        }
        return;
      }

      if (selected.contains(modifier.id)) {
        selected.remove(modifier.id);
        return;
      }

      final max = group.maxSelect;
      if (max != null && selected.length >= max) {
        AppFeedback.showInfo(context, 'You can pick up to $max from ${group.name}.');
        return;
      }

      selected.add(modifier.id);
    });
  }

  bool _isSelected(String groupId, String modifierId) =>
      _selections[groupId]?.contains(modifierId) ?? false;

  /// Groups the customer still has to answer.
  List<ModifierGroup> _unsatisfied(ProductDetail detail) {
    return detail.modifierGroups.where((group) {
      if (!group.isRequired) return false;
      final count = _selections[group.id]?.length ?? 0;
      final minimum = group.isSingleChoice ? 1 : (group.minSelect < 1 ? 1 : group.minSelect);
      return count < minimum;
    }).toList();
  }

  ProductVariant? _selectedVariant(ProductDetail detail) {
    if (_variantId == null) return null;
    for (final variant in detail.variants) {
      if (variant.id == _variantId) return variant;
    }
    return null;
  }

  /// Preview only. The bill that matters is computed by the server the moment this
  /// is added to the cart.
  double _previewUnitPrice(ProductDetail detail) {
    final variant = _selectedVariant(detail);
    var total = variant?.price ?? detail.product.basePrice;

    for (final group in detail.modifierGroups) {
      final selected = _selections[group.id] ?? const [];
      if (selected.isEmpty) continue;

      // Cheapest selections are the free ones, matching the server's rule.
      final chosen = group.modifiers
          .where((modifier) => selected.contains(modifier.id))
          .toList()
        ..sort((a, b) => a.price.compareTo(b.price));

      for (var index = 0; index < chosen.length; index++) {
        if (index < group.freeSelections) continue;
        total += chosen[index].price;
      }
    }

    return total;
  }

  List<ModifierSelection> _modifierPayload() {
    return _selections.values
        .expand((ids) => ids)
        .map((id) => ModifierSelection(modifierId: id))
        .toList();
  }

  Future<void> _addToCart(ProductDetail detail) async {
    final missing = _unsatisfied(detail);
    if (missing.isNotEmpty) {
      setState(() => _showErrors = true);
      AppFeedback.showInfo(context, 'Please choose ${missing.first.name}.');
      return;
    }

    setState(() => _submitting = true);

    try {
      await ref.read(cartProvider.notifier).addItem(
            productId: detail.product.id,
            variantId: _variantId,
            quantity: _quantity,
            modifiers: _modifierPayload(),
            specialInstructions: _instructions.text,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, '${detail.product.name} added to your cart.');
    } catch (error) {
      if (!mounted) return;
      AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailValue = ref.watch(productDetailProvider(widget.productId));

    return AsyncValueView<ProductDetail>(
      value: detailValue,
      onRetry: () => ref.invalidate(productDetailProvider(widget.productId)),
      loading: const SizedBox(height: 320, child: AppLoader()),
      data: (detail) {
        _primeDefaults(detail);
        return _Content(
          detail: detail,
          state: this,
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.detail, required this.state});

  final ProductDetail detail;
  final _ProductSheetState state;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final product = detail.product;
    final unitPrice = state._previewUnitPrice(detail);
    final unavailable = !product.isAvailable;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              FoodImage(
                path: product.heroImagePath ?? product.thumbnailPath,
                height: 200,
                radius: 0,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        FoodTypeMark(foodType: product.foodType, size: 15),
                        const SizedBox(width: 8),
                        if (product.isBestSeller)
                          AppPill(
                            label: 'Bestseller',
                            icon: Icons.local_fire_department_rounded,
                            background: brand.accent.withValues(alpha: 0.14),
                            foreground: brand.warning,
                            dense: true,
                          ),
                        const Spacer(),
                        if (product.ratingCount > 0)
                          RatingChip(
                            rating: product.ratingAverage,
                            count: product.ratingCount,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: brand.ink,
                      ),
                    ),
                    if ((product.description ?? product.shortDescription) != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        product.description ?? product.shortDescription!,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.5,
                          color: brand.inkMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppPill(
                          label: Fmt.duration(product.preparationMinutes),
                          icon: Icons.schedule_rounded,
                        ),
                        if (product.servesCount != null)
                          AppPill(
                            label: 'Serves ${product.servesCount}',
                            icon: Icons.people_outline_rounded,
                          ),
                        if (product.calories != null)
                          AppPill(
                            label: '${product.calories} kcal',
                            icon: Icons.local_fire_department_outlined,
                          ),
                        if (product.spiceLevel != 'NONE')
                          AppPill(
                            label: Fmt.humanise(product.spiceLevel),
                            icon: Icons.whatshot_rounded,
                          ),
                        ...product.dietaryTags.map(
                          (tag) => AppPill(label: Fmt.humanise(tag)),
                        ),
                      ],
                    ),
                    if (product.allergens.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      AppNotice(
                        tone: NoticeTone.caution,
                        message:
                            'Contains ${product.allergens.map(Fmt.humanise).join(', ').toLowerCase()}.',
                      ),
                    ],
                    if (unavailable) ...[
                      const SizedBox(height: 14),
                      AppNotice(
                        tone: NoticeTone.critical,
                        message: product.unavailableReason,
                      ),
                    ],
                  ],
                ),
              ),
              ..._variantSections(context),
              ..._modifierSections(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.allowsSpecialInstructions) ...[
                      Text(
                        'Cooking instructions',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: brand.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: state._instructions,
                        maxLines: 2,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          hintText: 'Less spicy, no onion…',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'We will pass this to the kitchen. Some requests may not be possible.',
                        style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
                      ),
                    ],
                    if (detail.reviews.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Text(
                        'What customers say',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: brand.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...detail.reviews.take(3).map(
                            (review) => _ReviewTile(review: review),
                          ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
        _AddBar(
          detail: detail,
          state: state,
          unitPrice: unitPrice,
          disabled: unavailable,
        ),
      ],
    );
  }

  List<Widget> _variantSections(BuildContext context) {
    if (detail.variants.isEmpty) return const [];
    final groups = detail.variantGroups;

    return groups.entries.map((entry) {
      return _OptionSection(
        title: entry.key,
        rule: 'Required · pick 1',
        showError: false,
        children: entry.value
            .map(
              (variant) => _OptionRow(
                label: variant.name,
                price: variant.price,
                priceIsAbsolute: true,
                comparePrice: variant.comparePrice,
                subtitle: variant.servesCount == null
                    ? null
                    : 'Serves ${variant.servesCount}',
                selected: state._variantId == variant.id,
                isRadio: true,
                enabled: variant.isAvailable,
                onTap: () => state.apply(() => state._variantId = variant.id),
              ),
            )
            .toList(),
      );
    }).toList();
  }

  List<Widget> _modifierSections(BuildContext context) {
    final unsatisfied = state._unsatisfied(detail).map((group) => group.id).toSet();

    return detail.modifierGroups.map((group) {
      final selected = state._selections[group.id] ?? const <String>[];

      return _OptionSection(
        title: group.name,
        rule: group.rule,
        subtitle: group.description,
        showError: state._showErrors && unsatisfied.contains(group.id),
        children: group.modifiers.map((modifier) {
          // The free allowance goes to the cheapest picks, exactly as the server
          // computes it — so the customer sees the same "Free" markers.
          final chosen = group.modifiers
              .where((item) => selected.contains(item.id))
              .toList()
            ..sort((a, b) => a.price.compareTo(b.price));
          final rank = chosen.indexWhere((item) => item.id == modifier.id);
          final isFree = rank >= 0 && rank < group.freeSelections && modifier.price > 0;

          return _OptionRow(
            label: modifier.name,
            price: modifier.price,
            subtitle: modifier.description,
            selected: state._isSelected(group.id, modifier.id),
            isRadio: group.isSingleChoice,
            enabled: modifier.isAvailable,
            freeByAllowance: isFree,
            foodType: modifier.foodType,
            onTap: () => state._toggle(group, modifier),
          );
        }).toList(),
      );
    }).toList();
  }
}

class _OptionSection extends StatelessWidget {
  const _OptionSection({
    required this.title,
    required this.rule,
    required this.children,
    required this.showError,
    this.subtitle,
  });

  final String title;
  final String rule;
  final String? subtitle;
  final bool showError;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: showError ? brand.error.withValues(alpha: 0.04) : null,
        border: Border(
          top: BorderSide(color: brand.hairline),
          bottom: BorderSide(color: brand.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: brand.ink,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(fontSize: 13, color: brand.inkMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                AppPill(
                  label: rule,
                  dense: true,
                  background: showError
                      ? brand.error.withValues(alpha: 0.12)
                      : brand.surfaceMuted,
                  foreground: showError ? brand.error : brand.inkMuted,
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.price,
    required this.selected,
    required this.isRadio,
    required this.enabled,
    required this.onTap,
    this.subtitle,
    this.comparePrice,
    this.priceIsAbsolute = false,
    this.freeByAllowance = false,
    this.foodType,
  });

  final String label;
  final double price;
  final bool selected;
  final bool isRadio;
  final bool enabled;
  final VoidCallback onTap;
  final String? subtitle;
  final double? comparePrice;
  final bool priceIsAbsolute;
  final bool freeByAllowance;
  final String? foodType;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                isRadio
                    ? (selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded)
                    : (selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded),
                size: 21,
                color: selected ? brand.primary : brand.inkMuted.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 12),
              if (foodType != null) ...[
                FoodTypeMark(foodType: foodType!, size: 11),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: brand.ink,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 12.5, color: brand.inkMuted),
                      ),
                    if (!enabled)
                      Text(
                        'Unavailable',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: brand.error,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (freeByAllowance)
                AppPill(
                  label: 'Free',
                  dense: true,
                  background: brand.success.withValues(alpha: 0.12),
                  foreground: brand.success,
                )
              else if (comparePrice != null && comparePrice! > price)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.moneySmart(price),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: brand.ink,
                      ),
                    ),
                    Text(
                      Fmt.moneySmart(comparePrice),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: brand.inkMuted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                )
              else if (price > 0 || priceIsAbsolute)
                Text(
                  priceIsAbsolute
                      ? Fmt.moneySmart(price)
                      : '+ ${Fmt.moneySmart(price)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: brand.ink,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RatingChip(rating: review.rating, dense: true),
              const SizedBox(width: 8),
              Text(
                review.customerName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: brand.ink,
                ),
              ),
              const Spacer(),
              Text(
                Fmt.relative(review.createdAt),
                style: TextStyle(fontSize: 12, color: brand.inkMuted),
              ),
            ],
          ),
          if ((review.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              review.comment!,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: brand.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddBar extends StatelessWidget {
  const _AddBar({
    required this.detail,
    required this.state,
    required this.unitPrice,
    required this.disabled,
  });

  final ProductDetail detail;
  final _ProductSheetState state;
  final double unitPrice;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final product = detail.product;
    final total = unitPrice * state._quantity;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: brand.surface,
        border: Border(top: BorderSide(color: brand.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            QuantityStepper(
              quantity: state._quantity,
              min: product.minQuantityPerOrder,
              max: product.maxQuantityPerOrder ?? 50,
              onChanged: (next) {
                if (next < product.minQuantityPerOrder) return;
                state.apply(() => state._quantity = next);
              },
            ),
            const SizedBox(width: 14),
            Expanded(
              child: FilledButton(
                onPressed: disabled || state._submitting
                    ? null
                    : () => state._addToCart(detail),
                child: state._submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        disabled
                            ? product.unavailableReason
                            : 'Add · ${Fmt.moneySmart(total)}',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
