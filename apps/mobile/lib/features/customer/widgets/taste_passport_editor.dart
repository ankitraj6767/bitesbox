import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brand_tokens.dart';
import '../../../l10n/customer_copy.dart';
import '../../../shared/feedback.dart';
import '../data/menu_models.dart';
import '../data/taste_passport_models.dart';
import '../providers/customer_providers.dart';

class TastePassportEditor extends ConsumerWidget {
  const TastePassportEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(tastePassportProvider);
    final categories = ref.watch(menuCatalogProvider);
    final brand = context.brand;

    return profile.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          context.customerText('Taste preferences could not be loaded.'),
          style: TextStyle(color: brand.error),
        ),
      ),
      data: (value) {
        final options =
            categories.valueOrNull?.categories ?? const <MenuCategory>[];
        return _TastePassportForm(
          key: ValueKey(
            '${value.foodTypes}|${value.maxSpice}|${value.categoryIds}|${value.priceCeiling}',
          ),
          initial: value,
          categories: options,
          categoriesLoading: categories.isLoading,
        );
      },
    );
  }
}

class _TastePassportForm extends ConsumerStatefulWidget {
  const _TastePassportForm({
    required this.initial,
    required this.categories,
    required this.categoriesLoading,
    super.key,
  });

  final TastePassportProfile initial;
  final List<MenuCategory> categories;
  final bool categoriesLoading;

  @override
  ConsumerState<_TastePassportForm> createState() => _TastePassportFormState();
}

class _TastePassportFormState extends ConsumerState<_TastePassportForm> {
  static const _foodTypes = ['VEG', 'NON_VEG', 'EGG', 'VEGAN'];
  static const _spiceLevels = ['NONE', 'MILD', 'MEDIUM', 'HOT', 'EXTRA_HOT'];

  late final TextEditingController _price;
  late final Set<String> _foodTypesSelected;
  late final Set<String> _categoriesSelected;
  String _maxSpice = 'ANY';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _foodTypesSelected = {...widget.initial.foodTypes};
    _categoriesSelected = {...widget.initial.categoryIds};
    _maxSpice = widget.initial.maxSpice ?? 'ANY';
    _price = TextEditingController(
      text: widget.initial.priceCeiling?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ceilingText = _price.text.trim();
    final ceiling = ceilingText.isEmpty ? null : double.tryParse(ceilingText);
    if (ceilingText.isNotEmpty &&
        (ceiling == null ||
            !ceiling.isFinite ||
            ceiling < 1 ||
            ceiling > 100000)) {
      AppFeedback.showInfo(
        context,
        context.customerText('Enter a valid item price ceiling.'),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(tastePassportRepositoryProvider)
          .save(
            foodTypes: _foodTypesSelected.toList()..sort(),
            maxSpice: _maxSpice == 'ANY' ? null : _maxSpice,
            categoryIds: _categoriesSelected.toList()..sort(),
            priceCeiling: ceiling,
          );
      ref.invalidate(tastePassportProvider);
      ref.invalidate(homeFeedProvider);
      if (!mounted) return;
      AppFeedback.showSuccess(
        context,
        context.customerText('Taste Passport saved.'),
      );
    } catch (error) {
      if (!mounted) return;
      AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.customerText('Taste Passport'),
            style: TextStyle(
              color: brand.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.customerText(
              'Optional choices for menu recommendations. You can change them any time.',
            ),
            style: TextStyle(
              color: brand.inkMuted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.customerText(
              'These choices are not allergy or medical advice. Check item details if you have a dietary concern.',
            ),
            style: TextStyle(
              color: brand.inkMuted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _FieldHeading(context.customerText('Food types')),
          Wrap(
            spacing: 7,
            runSpacing: 2,
            children: _foodTypes.map((type) {
              return FilterChip(
                label: Text(context.customerText(_foodLabel(type))),
                selected: _foodTypesSelected.contains(type),
                showCheckmark: false,
                onSelected: _busy
                    ? null
                    : (selected) => setState(() {
                        if (selected) {
                          _foodTypesSelected.add(type);
                        } else {
                          _foodTypesSelected.remove(type);
                        }
                      }),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _maxSpice,
            decoration: InputDecoration(
              labelText: context.customerText('Maximum spice level'),
              prefixIcon: const Icon(Icons.local_fire_department_outlined),
            ),
            items: [
              DropdownMenuItem(
                value: 'ANY',
                child: Text(context.customerText('Any level')),
              ),
              ..._spiceLevels.map(
                (level) => DropdownMenuItem(
                  value: level,
                  child: Text(context.customerText(_spiceLabel(level))),
                ),
              ),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _maxSpice = value ?? 'ANY'),
          ),
          const SizedBox(height: 12),
          _FieldHeading(context.customerText('Favorite categories')),
          if (widget.categoriesLoading && widget.categories.isEmpty)
            const LinearProgressIndicator()
          else if (widget.categories.isEmpty)
            Text(
              context.customerText(
                'Menu categories are not available right now.',
              ),
              style: TextStyle(color: brand.inkMuted, fontSize: 12.5),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 2,
              children: widget.categories.map((category) {
                return FilterChip(
                  label: Text(category.name),
                  selected: _categoriesSelected.contains(category.id),
                  showCheckmark: false,
                  onSelected: _busy
                      ? null
                      : (selected) {
                          if (selected && _categoriesSelected.length >= 20) {
                            AppFeedback.showInfo(
                              context,
                              context.customerText(
                                'Choose up to 20 categories.',
                              ),
                            );
                            return;
                          }
                          setState(() {
                            if (selected) {
                              _categoriesSelected.add(category.id);
                            } else {
                              _categoriesSelected.remove(category.id);
                            }
                          });
                        },
                );
              }).toList(),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _price,
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.customerText('Optional item price ceiling'),
              prefixText: '₹ ',
              helperText: context.customerText('Leave blank for any price.'),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(
                _busy
                    ? context.customerText('Saving…')
                    : context.customerText('Save Taste Passport'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _foodLabel(String type) => switch (type) {
    'VEG' => 'Vegetarian',
    'NON_VEG' => 'Non-veg',
    'EGG' => 'Contains egg',
    'VEGAN' => 'Vegan',
    _ => type,
  };

  static String _spiceLabel(String level) => switch (level) {
    'NONE' => 'No spice',
    'MILD' => 'Mild',
    'MEDIUM' => 'Medium',
    'HOT' => 'Hot',
    'EXTRA_HOT' => 'Extra hot',
    _ => level,
  };
}

class _FieldHeading extends StatelessWidget {
  const _FieldHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.brand.ink,
      ),
    ),
  );
}
