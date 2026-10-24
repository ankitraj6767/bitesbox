import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/brand_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';
import '../providers/customer_providers.dart';
import '../widgets/product_sheet.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final brand = context.brand;
    final favorites = ref.watch(favoritesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.favorites)),
      body: AsyncValueView(
        value: favorites,
        onRetry: () => ref.invalidate(favoritesProvider),
        loading: const Center(child: CircularProgressIndicator()),
        data: (items) => items.isEmpty
            ? AppEmptyState(
                title: l10n.favorites,
                message: l10n.noFavorites,
                icon: Icons.favorite_border_rounded,
                action: OutlinedButton(
                  onPressed: () => context.go('/menu'),
                  child: Text(l10n.menu),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final available = item.isActive && item.isAvailable;
                  return Material(
                    color: brand.surface,
                    elevation: 1,
                    shadowColor: brand.ink.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(brand.radiusMd),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(brand.radiusMd),
                      onTap: available
                          ? () => ProductSheet.show(context, productId: item.id)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            FoodImage(
                              path: item.imagePath,
                              width: 82,
                              height: 82,
                              radius: 14,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.15,
                                      color: brand.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    Fmt.moneySmart(item.price),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: brand.ink,
                                    ),
                                  ),
                                  if (!available) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.isActive
                                          ? l10n.unavailableAtOutlet
                                          : l10n.discontinuedDish,
                                      style: TextStyle(
                                        color: brand.warning,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.removeFavorite,
                              onPressed: () async {
                                await ref
                                    .read(growthRepositoryProvider)
                                    .setFavorite(item.id, false);
                                ref.invalidate(favoritesProvider);
                              },
                              icon: Icon(
                                Icons.favorite_rounded,
                                color: brand.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
