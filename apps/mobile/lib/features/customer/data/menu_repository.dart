import '../../../core/network/api_client.dart';
import 'menu_models.dart';

/// Menu reads. Every method is a single RPC returning a whole screen, because a
/// customer on a patchy connection should wait for one round trip, not six.
class MenuRepository {
  const MenuRepository(this._api);

  final ApiClient _api;

  /// The home screen: banners, categories, curated rails and offers.
  Future<HomeFeed> homeFeed({String? branchId}) async {
    final result = await _api.rpc<dynamic>(
      'home_feed',
      params: {if (branchId != null) 'p_branch_id': branchId},
      dedupeKey: 'home_feed:$branchId',
    );

    return HomeFeed.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// The whole menu with per-branch availability resolved server-side.
  Future<MenuCatalog> catalog({String? branchId, String? categoryId}) async {
    final result = await _api.rpc<dynamic>(
      'menu_catalog',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
        if (categoryId != null) 'p_category_id': categoryId,
      },
      dedupeKey: 'menu_catalog:$branchId:$categoryId',
    );

    return MenuCatalog.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// Variants, modifier groups, reviews and similar dishes for the product sheet.
  Future<ProductDetail> productDetail({
    String? productId,
    String? slug,
    String? branchId,
  }) async {
    assert(productId != null || slug != null, 'A product id or slug is required');

    final result = await _api.rpc<dynamic>(
      'product_detail',
      params: {
        if (productId != null) 'p_product_id': productId,
        if (slug != null) 'p_slug': slug,
        if (branchId != null) 'p_branch_id': branchId,
      },
      dedupeKey: 'product_detail:${productId ?? slug}',
    );

    return ProductDetail.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// Typo-tolerant search. Not de-duplicated: each keystroke-debounced query is a
  /// distinct question, and the server also records it for trending terms.
  Future<SearchResults> search(String query, {String? branchId, int limit = 30}) async {
    final result = await _api.rpc<dynamic>(
      'search_menu',
      params: {
        'p_query': query,
        'p_limit': limit,
        if (branchId != null) 'p_branch_id': branchId,
      },
    );

    return SearchResults.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// Recent, trending and popular, shown before the customer types anything.
  Future<SearchSuggestions> suggestions({String? branchId}) async {
    final result = await _api.rpc<dynamic>(
      'search_suggestions',
      params: {if (branchId != null) 'p_branch_id': branchId},
      dedupeKey: 'search_suggestions:$branchId',
    );

    return SearchSuggestions.fromJson(Map<String, dynamic>.from(result as Map));
  }
}
