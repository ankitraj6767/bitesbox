import 'package:bitesbox/core/theme/brand_tokens.dart';
import 'package:bitesbox/features/customer/data/menu_models.dart';
import 'package:bitesbox/features/customer/data/taste_passport_models.dart';
import 'package:bitesbox/features/customer/data/taste_passport_repository.dart';
import 'package:bitesbox/features/customer/providers/customer_providers.dart';
import 'package:bitesbox/features/customer/widgets/taste_passport_editor.dart';
import 'package:bitesbox/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('edits and saves the customer-selected taste constraints', (
    tester,
  ) async {
    final repository = _FakeTastePassportRepository();
    var feedReads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tastePassportProvider.overrideWith(
            (ref) async => const TastePassportProfile(),
          ),
          tastePassportRepositoryProvider.overrideWithValue(repository),
          menuCatalogProvider.overrideWith(
            (ref) async => MenuCatalog(
              categories: const [
                MenuCategory(id: 'cat-1', name: 'Biryani', slug: 'biryani'),
              ],
              products: const [],
              generatedAt: DateTime.utc(2026),
            ),
          ),
          homeFeedProvider.overrideWith((ref) async {
            feedReads++;
            return HomeFeed(
              sections: const [],
              generatedAt: DateTime.utc(2026),
            );
          }),
        ],
        child: BrandTheme(
          tokens: const BrandTokens(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ListView(
                children: [
                  Consumer(
                    builder: (context, ref, child) {
                      ref.watch(homeFeedProvider);
                      return Text('feed reads: $feedReads');
                    },
                  ),
                  const TastePassportEditor(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Vegetarian'));
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mild').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Biryani'));
    await tester.enterText(find.byType(TextField), '220');
    await tester.tap(find.text('Save Taste Passport'));
    await tester.pumpAndSettle();

    expect(repository.foodTypes, ['VEG']);
    expect(repository.maxSpice, 'MILD');
    expect(repository.categoryIds, ['cat-1']);
    expect(repository.priceCeiling, 220);
    expect(feedReads, greaterThan(1));
  });
}

class _FakeTastePassportRepository implements TastePassportRepository {
  List<String> foodTypes = const [];
  String? maxSpice;
  List<String> categoryIds = const [];
  double? priceCeiling;

  @override
  Future<TastePassportProfile> profile() async => const TastePassportProfile();

  @override
  Future<TastePassportProfile> save({
    required List<String> foodTypes,
    required String? maxSpice,
    required List<String> categoryIds,
    required double? priceCeiling,
  }) async {
    this.foodTypes = foodTypes;
    this.maxSpice = maxSpice;
    this.categoryIds = categoryIds;
    this.priceCeiling = priceCeiling;
    return TastePassportProfile(
      foodTypes: foodTypes,
      maxSpice: maxSpice,
      categoryIds: categoryIds,
      priceCeiling: priceCeiling,
      hasProfile: true,
    );
  }
}
