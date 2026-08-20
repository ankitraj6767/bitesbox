/// Menu domain models.
///
/// Hand-written `fromJson` rather than generated code: the payloads come from
/// purpose-built Postgres functions whose shape we control, and avoiding
/// build_runner keeps `flutter analyze` and CI free of a codegen step. The
/// trade-off is deliberate and documented in docs/architecture.md.
library;

double _toDouble(Object? value) => switch (value) {
      num n => n.toDouble(),
      String s => double.tryParse(s) ?? 0,
      _ => 0,
    };

double? _toDoubleOrNull(Object? value) => switch (value) {
      num n => n.toDouble(),
      String s => double.tryParse(s),
      _ => null,
    };

int _toInt(Object? value) => switch (value) {
      num n => n.toInt(),
      String s => int.tryParse(s) ?? 0,
      _ => 0,
    };

int? _toIntOrNull(Object? value) => switch (value) {
      num n => n.toInt(),
      String s => int.tryParse(s),
      _ => null,
    };

List<String> _toStringList(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.shortDescription,
    this.imagePath,
    this.thumbnailPath,
    this.iconName,
    this.accentColor,
    this.dayPart = 'ALL_DAY',
    this.displayOrder = 0,
    this.productCount = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String? shortDescription;
  final String? imagePath;
  final String? thumbnailPath;
  final String? iconName;
  final String? accentColor;
  final String dayPart;
  final int displayOrder;
  final int productCount;

  factory MenuCategory.fromJson(Map<String, dynamic> json) => MenuCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: (json['slug'] as String?) ?? '',
        shortDescription: json['short_description'] as String?,
        imagePath: json['image_path'] as String?,
        thumbnailPath: json['thumbnail_path'] as String?,
        iconName: json['icon_name'] as String?,
        accentColor: json['accent_color'] as String?,
        dayPart: (json['day_part'] as String?) ?? 'ALL_DAY',
        displayOrder: _toInt(json['display_order']),
        productCount: _toInt(json['product_count']),
      );
}

class MenuProduct {
  const MenuProduct({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    required this.basePrice,
    this.shortDescription,
    this.description,
    this.thumbnailPath,
    this.heroImagePath,
    this.foodType = 'VEG',
    this.spiceLevel = 'NONE',
    this.allergens = const [],
    this.dietaryTags = const [],
    this.comparePrice,
    this.preparationMinutes = 15,
    this.servesCount,
    this.calories,
    this.isFeatured = false,
    this.isBestSeller = false,
    this.isNew = false,
    this.isRecommended = false,
    this.isCombo = false,
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.displayOrder = 0,
    this.minQuantityPerOrder = 1,
    this.maxQuantityPerOrder,
    this.allowsSpecialInstructions = true,
    this.isAvailable = true,
    this.availabilityState = 'AVAILABLE',
    this.hasVariants = false,
    this.minPrice,
  });

  final String id;
  final String categoryId;
  final String name;
  final String slug;
  final double basePrice;
  final String? shortDescription;
  final String? description;
  final String? thumbnailPath;
  final String? heroImagePath;
  final String foodType;
  final String spiceLevel;
  final List<String> allergens;
  final List<String> dietaryTags;
  final double? comparePrice;
  final int preparationMinutes;
  final int? servesCount;
  final int? calories;
  final bool isFeatured;
  final bool isBestSeller;
  final bool isNew;
  final bool isRecommended;
  final bool isCombo;
  final double ratingAverage;
  final int ratingCount;
  final int displayOrder;
  final int minQuantityPerOrder;
  final int? maxQuantityPerOrder;
  final bool allowsSpecialInstructions;
  final bool isAvailable;
  final String availabilityState;
  final bool hasVariants;
  final double? minPrice;

  /// Cheapest orderable price — what "from ₹X" shows on a card.
  double get displayPrice => minPrice ?? basePrice;

  bool get hasDiscount => comparePrice != null && comparePrice! > displayPrice;

  int get discountPercent {
    if (!hasDiscount) return 0;
    return (((comparePrice! - displayPrice) / comparePrice!) * 100).round();
  }

  bool get isVeg => foodType == 'VEG' || foodType == 'VEGAN';

  String get unavailableReason => switch (availabilityState) {
        'OUT_OF_STOCK' => 'Sold out for today',
        'TEMPORARILY_UNAVAILABLE' => 'Back soon',
        _ => 'Not available right now',
      };

  factory MenuProduct.fromJson(Map<String, dynamic> json) => MenuProduct(
        id: json['id'] as String,
        categoryId: (json['category_id'] as String?) ?? '',
        name: json['name'] as String,
        slug: (json['slug'] as String?) ?? '',
        basePrice: _toDouble(json['base_price']),
        shortDescription: json['short_description'] as String?,
        description: json['description'] as String?,
        thumbnailPath: json['thumbnail_path'] as String?,
        heroImagePath: json['hero_image_path'] as String?,
        foodType: (json['food_type'] as String?) ?? 'VEG',
        spiceLevel: (json['spice_level'] as String?) ?? 'NONE',
        allergens: _toStringList(json['allergens']),
        dietaryTags: _toStringList(json['dietary_tags']),
        comparePrice: _toDoubleOrNull(json['compare_price']),
        preparationMinutes: _toInt(json['preparation_minutes']),
        servesCount: _toIntOrNull(json['serves_count']),
        calories: _toIntOrNull(json['calories']),
        isFeatured: json['is_featured'] as bool? ?? false,
        isBestSeller: json['is_best_seller'] as bool? ?? false,
        isNew: json['is_new'] as bool? ?? false,
        isRecommended: json['is_recommended'] as bool? ?? false,
        isCombo: json['is_combo'] as bool? ?? false,
        ratingAverage: _toDouble(json['rating_average']),
        ratingCount: _toInt(json['rating_count']),
        displayOrder: _toInt(json['display_order']),
        minQuantityPerOrder: json['min_quantity_per_order'] == null
            ? 1
            : _toInt(json['min_quantity_per_order']),
        maxQuantityPerOrder: _toIntOrNull(json['max_quantity_per_order']),
        allowsSpecialInstructions: json['allows_special_instructions'] as bool? ?? true,
        isAvailable: json['is_available'] as bool? ?? true,
        availabilityState: (json['availability_state'] as String?) ?? 'AVAILABLE',
        hasVariants: json['has_variants'] as bool? ?? false,
        minPrice: _toDoubleOrNull(json['min_price']),
      );
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.name,
    required this.optionGroup,
    required this.price,
    this.comparePrice,
    this.calories,
    this.servesCount,
    this.isDefault = false,
    this.isAvailable = true,
    this.displayOrder = 0,
  });

  final String id;
  final String name;
  final String optionGroup;
  final double price;
  final double? comparePrice;
  final int? calories;
  final int? servesCount;
  final bool isDefault;
  final bool isAvailable;
  final int displayOrder;

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        id: json['id'] as String,
        name: json['name'] as String,
        optionGroup: (json['option_group'] as String?) ?? 'Option',
        price: _toDouble(json['price']),
        comparePrice: _toDoubleOrNull(json['compare_price']),
        calories: _toIntOrNull(json['calories']),
        servesCount: _toIntOrNull(json['serves_count']),
        isDefault: json['is_default'] as bool? ?? false,
        isAvailable: json['is_available'] as bool? ?? true,
        displayOrder: _toInt(json['display_order']),
      );
}

class ProductModifier {
  const ProductModifier({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imagePath,
    this.foodType = 'VEG',
    this.calories,
    this.maxQuantity = 1,
    this.isDefault = false,
    this.isAvailable = true,
    this.displayOrder = 0,
  });

  final String id;
  final String name;
  final double price;
  final String? description;
  final String? imagePath;
  final String foodType;
  final int? calories;
  final int maxQuantity;
  final bool isDefault;
  final bool isAvailable;
  final int displayOrder;

  factory ProductModifier.fromJson(Map<String, dynamic> json) => ProductModifier(
        id: json['id'] as String,
        name: json['name'] as String,
        price: _toDouble(json['price']),
        description: json['description'] as String?,
        imagePath: json['image_path'] as String?,
        foodType: (json['food_type'] as String?) ?? 'VEG',
        calories: _toIntOrNull(json['calories']),
        maxQuantity: json['max_quantity'] == null ? 1 : _toInt(json['max_quantity']),
        isDefault: json['is_default'] as bool? ?? false,
        isAvailable: json['is_available'] as bool? ?? true,
        displayOrder: _toInt(json['display_order']),
      );
}

class ModifierGroup {
  const ModifierGroup({
    required this.id,
    required this.name,
    required this.selection,
    required this.modifiers,
    this.description,
    this.isRequired = false,
    this.minSelect = 0,
    this.maxSelect,
    this.freeSelections = 0,
    this.displayOrder = 0,
  });

  final String id;
  final String name;
  final String selection;
  final List<ProductModifier> modifiers;
  final String? description;
  final bool isRequired;
  final int minSelect;
  final int? maxSelect;
  final int freeSelections;
  final int displayOrder;

  bool get isSingleChoice => selection == 'SINGLE';

  /// Helper copy under the group title: "Pick 1", "Pick up to 3", "2 free".
  String get rule {
    if (isSingleChoice) return isRequired ? 'Required · pick 1' : 'Pick 1';
    final parts = <String>[];
    if (isRequired) parts.add('Required');
    if (maxSelect != null) {
      parts.add('Pick up to $maxSelect');
    } else {
      parts.add('Pick any');
    }
    if (freeSelections > 0) parts.add('$freeSelections free');
    return parts.join(' · ');
  }

  factory ModifierGroup.fromJson(Map<String, dynamic> json) => ModifierGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        selection: (json['selection'] as String?) ?? 'MULTIPLE',
        modifiers: json['modifiers'] is List
            ? (json['modifiers'] as List)
                .whereType<Map>()
                .map((item) => ProductModifier.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const [],
        description: json['description'] as String?,
        isRequired: json['is_required'] as bool? ?? false,
        minSelect: _toInt(json['min_select']),
        maxSelect: _toIntOrNull(json['max_select']),
        freeSelections: _toInt(json['free_selections']),
        displayOrder: _toInt(json['display_order']),
      );
}

class ProductDetail {
  const ProductDetail({
    required this.product,
    required this.variants,
    required this.modifierGroups,
    this.categoryName,
    this.reviews = const [],
    this.similarProducts = const [],
  });

  final MenuProduct product;
  final List<ProductVariant> variants;
  final List<ModifierGroup> modifierGroups;
  final String? categoryName;
  final List<ProductReview> reviews;
  final List<MenuProduct> similarProducts;

  ProductVariant? get defaultVariant {
    if (variants.isEmpty) return null;
    return variants.firstWhere(
      (variant) => variant.isDefault && variant.isAvailable,
      orElse: () => variants.firstWhere(
        (variant) => variant.isAvailable,
        orElse: () => variants.first,
      ),
    );
  }

  /// Variants grouped by their option label ("Portion", "Crust"), preserving order.
  Map<String, List<ProductVariant>> get variantGroups {
    final groups = <String, List<ProductVariant>>{};
    for (final variant in variants) {
      groups.putIfAbsent(variant.optionGroup, () => []).add(variant);
    }
    return groups;
  }

  factory ProductDetail.fromJson(Map<String, dynamic> json) => ProductDetail(
        product: MenuProduct.fromJson(json),
        categoryName: json['category_name'] as String?,
        variants: json['variants'] is List
            ? (json['variants'] as List)
                .whereType<Map>()
                .map((item) => ProductVariant.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const [],
        modifierGroups: json['modifier_groups'] is List
            ? (json['modifier_groups'] as List)
                .whereType<Map>()
                .map((item) => ModifierGroup.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const [],
        reviews: json['reviews'] is List
            ? (json['reviews'] as List)
                .whereType<Map>()
                .map((item) => ProductReview.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const [],
        similarProducts: json['similar_products'] is List
            ? (json['similar_products'] as List)
                .whereType<Map>()
                .map((item) => MenuProduct.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const [],
      );
}

class ProductReview {
  const ProductReview({
    required this.rating,
    required this.customerName,
    this.comment,
    this.createdAt,
  });

  final int rating;
  final String customerName;
  final String? comment;
  final DateTime? createdAt;

  factory ProductReview.fromJson(Map<String, dynamic> json) => ProductReview(
        rating: _toInt(json['rating']),
        customerName: (json['customer_name'] as String?) ?? 'Customer',
        comment: json['comment'] as String?,
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
      );
}

class MenuCatalog {
  const MenuCatalog({
    required this.categories,
    required this.products,
    required this.generatedAt,
  });

  final List<MenuCategory> categories;
  final List<MenuProduct> products;
  final DateTime generatedAt;

  List<MenuProduct> forCategory(String categoryId) =>
      products.where((product) => product.categoryId == categoryId).toList();

  factory MenuCatalog.fromJson(Map<String, dynamic> json) => MenuCatalog(
        categories: json['categories'] is List
            ? (json['categories'] as List)
                .whereType<Map>()
                .map((item) => MenuCategory.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const [],
        products: json['products'] is List
            ? (json['products'] as List)
                .whereType<Map>()
                .map((item) => MenuProduct.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const [],
        generatedAt:
            DateTime.tryParse((json['generated_at'] as String?) ?? '') ?? DateTime.now(),
      );
}

// ── Home feed ──────────────────────────────────────────────────────────────
class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.imagePath,
    this.title,
    this.subtitle,
    this.badgeText,
    this.imagePathWide,
    this.backgroundColor,
    this.linkKind = 'NONE',
    this.linkCategoryId,
    this.linkProductId,
    this.linkCouponId,
    this.linkRoute,
    this.linkUrl,
  });

  final String id;
  final String imagePath;
  final String? title;
  final String? subtitle;
  final String? badgeText;
  final String? imagePathWide;
  final String? backgroundColor;
  final String linkKind;
  final String? linkCategoryId;
  final String? linkProductId;
  final String? linkCouponId;
  final String? linkRoute;
  final String? linkUrl;

  factory HomeBanner.fromJson(Map<String, dynamic> json) => HomeBanner(
        id: json['id'] as String,
        imagePath: (json['image_path'] as String?) ?? '',
        title: json['title'] as String?,
        subtitle: json['subtitle'] as String?,
        badgeText: json['badge_text'] as String?,
        imagePathWide: json['image_path_wide'] as String?,
        backgroundColor: json['background_color'] as String?,
        linkKind: (json['link_kind'] as String?) ?? 'NONE',
        linkCategoryId: json['link_category_id'] as String?,
        linkProductId: json['link_product_id'] as String?,
        linkCouponId: json['link_coupon_id'] as String?,
        linkRoute: json['link_route'] as String?,
        linkUrl: json['link_url'] as String?,
      );
}

class CustomerCoupon {
  const CustomerCoupon({
    required this.id,
    required this.code,
    required this.title,
    required this.discountKind,
    required this.discountValue,
    this.description,
    this.terms,
    this.minOrderAmount = 0,
    this.maxDiscountAmount,
    this.bannerPath,
    this.endsAt,
    this.isApplicable,
    this.reason,
    this.estimatedDiscount,
  });

  final String id;
  final String code;
  final String title;
  final String discountKind;
  final double discountValue;
  final String? description;
  final String? terms;
  final double minOrderAmount;
  final double? maxDiscountAmount;
  final String? bannerPath;
  final DateTime? endsAt;
  final bool? isApplicable;
  final String? reason;
  final double? estimatedDiscount;

  /// "20% OFF" / "₹75 OFF" / "FREE DELIVERY"
  String get headline => switch (discountKind) {
        'PERCENTAGE' => '${discountValue.toStringAsFixed(0)}% OFF',
        'FLAT' => '₹${discountValue.toStringAsFixed(0)} OFF',
        'FREE_DELIVERY' => 'FREE DELIVERY',
        _ => title,
      };

  factory CustomerCoupon.fromJson(Map<String, dynamic> json) => CustomerCoupon(
        id: json['id'] as String,
        code: json['code'] as String,
        title: (json['title'] as String?) ?? '',
        discountKind: (json['discount_kind'] as String?) ?? 'FLAT',
        discountValue: _toDouble(json['discount_value']),
        description: json['description'] as String?,
        terms: json['terms'] as String?,
        minOrderAmount: _toDouble(json['min_order_amount']),
        maxDiscountAmount: _toDoubleOrNull(json['max_discount_amount']),
        bannerPath: json['banner_path'] as String?,
        endsAt: DateTime.tryParse((json['ends_at'] as String?) ?? ''),
        isApplicable: json['is_applicable'] as bool?,
        reason: json['reason'] as String?,
        estimatedDiscount: _toDoubleOrNull(json['estimated_discount']),
      );
}

class HomeSection {
  const HomeSection({
    required this.id,
    required this.key,
    required this.kind,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.actionRoute,
    this.layout = 'CAROUSEL',
    this.backgroundColor,
    this.richText,
    this.displayOrder = 0,
    this.banners = const [],
    this.categories = const [],
    this.products = const [],
    this.coupons = const [],
  });

  final String id;
  final String key;
  final String kind;
  final String? title;
  final String? subtitle;
  final String? actionLabel;
  final String? actionRoute;
  final String layout;
  final String? backgroundColor;
  final String? richText;
  final int displayOrder;
  final List<HomeBanner> banners;
  final List<MenuCategory> categories;
  final List<MenuProduct> products;
  final List<CustomerCoupon> coupons;

  factory HomeSection.fromJson(Map<String, dynamic> json) => HomeSection(
        id: json['id'] as String,
        key: (json['key'] as String?) ?? '',
        kind: (json['kind'] as String?) ?? 'PRODUCT_CAROUSEL',
        title: json['title'] as String?,
        subtitle: json['subtitle'] as String?,
        actionLabel: json['action_label'] as String?,
        actionRoute: json['action_route'] as String?,
        layout: (json['layout'] as String?) ?? 'CAROUSEL',
        backgroundColor: json['background_color'] as String?,
        richText: json['rich_text'] as String?,
        displayOrder: _toInt(json['display_order']),
        banners: json['banners'] is List
            ? (json['banners'] as List)
                .whereType<Map>()
                .map((item) => HomeBanner.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const [],
        categories: json['categories'] is List
            ? (json['categories'] as List)
                .whereType<Map>()
                .map((item) => MenuCategory.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const [],
        products: json['products'] is List
            ? (json['products'] as List)
                .whereType<Map>()
                .map((item) => MenuProduct.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const [],
        coupons: json['coupons'] is List
            ? (json['coupons'] as List)
                .whereType<Map>()
                .map((item) => CustomerCoupon.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const [],
      );
}

class HomeFeed {
  const HomeFeed({required this.sections, required this.generatedAt});

  final List<HomeSection> sections;
  final DateTime generatedAt;

  factory HomeFeed.fromJson(Map<String, dynamic> json) => HomeFeed(
        sections: json['sections'] is List
            ? (json['sections'] as List)
                .whereType<Map>()
                .map((item) => HomeSection.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const [],
        generatedAt:
            DateTime.tryParse((json['generated_at'] as String?) ?? '') ?? DateTime.now(),
      );
}

class SearchResults {
  const SearchResults({
    required this.query,
    required this.count,
    required this.products,
    this.categories = const [],
  });

  final String query;
  final int count;
  final List<MenuProduct> products;
  final List<MenuCategory> categories;

  factory SearchResults.fromJson(Map<String, dynamic> json) => SearchResults(
        query: (json['query'] as String?) ?? '',
        count: _toInt(json['count']),
        products: json['products'] is List
            ? (json['products'] as List)
                .whereType<Map>()
                .map((item) => MenuProduct.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const [],
        categories: json['categories'] is List
            ? (json['categories'] as List)
                .whereType<Map>()
                .map((item) => MenuCategory.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const [],
      );
}

class SearchSuggestions {
  const SearchSuggestions({
    this.recent = const [],
    this.trending = const [],
    this.popularProducts = const [],
  });

  final List<String> recent;
  final List<String> trending;
  final List<MenuProduct> popularProducts;

  factory SearchSuggestions.fromJson(Map<String, dynamic> json) => SearchSuggestions(
        recent: _toStringList(json['recent']),
        trending: _toStringList(json['trending']),
        popularProducts: json['popular_products'] is List
            ? (json['popular_products'] as List)
                .whereType<Map>()
                .map((item) => MenuProduct.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const [],
      );
}
