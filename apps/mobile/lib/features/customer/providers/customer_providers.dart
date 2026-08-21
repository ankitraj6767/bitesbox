import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/account_models.dart';
import '../data/account_repository.dart';
import '../data/address_models.dart';
import '../data/address_repository.dart';
import '../data/cart_repository.dart';
import '../data/content_models.dart';
import '../data/content_repository.dart';
import '../data/menu_models.dart';
import '../data/menu_repository.dart';
import '../data/order_models.dart';
import '../data/order_repository.dart';
import '../data/payment_repository.dart';

// ── Repositories ───────────────────────────────────────────────────────────
final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => MenuRepository(ref.watch(apiClientProvider)),
);

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => CartRepository(ref.watch(apiClientProvider)),
);

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ref.watch(apiClientProvider)),
);

final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => AddressRepository(ref.watch(apiClientProvider)),
);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(apiClientProvider)),
);

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepository(ref.watch(apiClientProvider)),
);

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ContentRepository(ref.watch(apiClientProvider)),
);

final publishedDocumentsProvider = FutureProvider<List<CmsDocument>>((ref) {
  return ref.watch(contentRepositoryProvider).documents();
});

final publishedFaqsProvider = FutureProvider<List<CmsFaq>>((ref) {
  return ref.watch(contentRepositoryProvider).faqs();
});

/// The branch everything is scoped to. Single-brand, multi-branch ready: today
/// this is the configured default, and switching outlets means changing this one
/// value rather than threading a branch id through every screen.
final activeBranchIdProvider = Provider<String?>((ref) {
  return ref
      .watch(appConfigProvider)
      .maybeWhen(data: (config) => config.branchId, orElse: () => null);
});

// ── Menu ───────────────────────────────────────────────────────────────────
final homeFeedProvider = FutureProvider<HomeFeed>((ref) async {
  final branchId = ref.watch(activeBranchIdProvider);
  return ref.watch(menuRepositoryProvider).homeFeed(branchId: branchId);
});

final menuCatalogProvider = FutureProvider<MenuCatalog>((ref) async {
  final branchId = ref.watch(activeBranchIdProvider);
  return ref.watch(menuRepositoryProvider).catalog(branchId: branchId);
});

final productDetailProvider = FutureProvider.family<ProductDetail, String>((
  ref,
  productId,
) async {
  final branchId = ref.watch(activeBranchIdProvider);
  return ref
      .watch(menuRepositoryProvider)
      .productDetail(productId: productId, branchId: branchId);
});

final searchSuggestionsProvider = FutureProvider<SearchSuggestions>((
  ref,
) async {
  final branchId = ref.watch(activeBranchIdProvider);
  return ref.watch(menuRepositoryProvider).suggestions(branchId: branchId);
});

/// The live search term. Debouncing happens in the search field so a fast typist
/// does not fire a request per keystroke.
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<SearchResults?>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.length < 2) return null;

  final branchId = ref.watch(activeBranchIdProvider);
  return ref.watch(menuRepositoryProvider).search(query, branchId: branchId);
});

/// Menu filters the customer can toggle. Purely a view concern: availability and
/// pricing still come from the server.
class MenuFilters {
  const MenuFilters({
    this.vegOnly = false,
    this.nonVegOnly = false,
    this.bestSellersOnly = false,
    this.hideUnavailable = false,
    this.categoryId,
  });

  final bool vegOnly;
  final bool nonVegOnly;
  final bool bestSellersOnly;
  final bool hideUnavailable;
  final String? categoryId;

  bool get isActive =>
      vegOnly || nonVegOnly || bestSellersOnly || hideUnavailable;

  int get activeCount =>
      (vegOnly ? 1 : 0) +
      (nonVegOnly ? 1 : 0) +
      (bestSellersOnly ? 1 : 0) +
      (hideUnavailable ? 1 : 0);

  MenuFilters copyWith({
    bool? vegOnly,
    bool? nonVegOnly,
    bool? bestSellersOnly,
    bool? hideUnavailable,
    String? categoryId,
    bool clearCategory = false,
  }) {
    return MenuFilters(
      vegOnly: vegOnly ?? this.vegOnly,
      nonVegOnly: nonVegOnly ?? this.nonVegOnly,
      bestSellersOnly: bestSellersOnly ?? this.bestSellersOnly,
      hideUnavailable: hideUnavailable ?? this.hideUnavailable,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    );
  }

  bool matches(MenuProduct product) {
    if (vegOnly && !product.isVeg) return false;
    if (nonVegOnly && product.isVeg) return false;
    if (bestSellersOnly && !product.isBestSeller) return false;
    if (hideUnavailable && !product.isAvailable) return false;
    return true;
  }
}

final menuFiltersProvider = StateProvider<MenuFilters>(
  (ref) => const MenuFilters(),
);

// ── Addresses ──────────────────────────────────────────────────────────────
final addressesProvider = FutureProvider<List<CustomerAddress>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session.isGuest) return const [];
  return ref.watch(addressRepositoryProvider).list();
});

/// The address the customer is ordering to. Falls back to their default.
final selectedAddressProvider = Provider<CustomerAddress?>((ref) {
  final addresses = ref
      .watch(addressesProvider)
      .maybeWhen(data: (list) => list, orElse: () => const <CustomerAddress>[]);
  if (addresses.isEmpty) return null;

  final selectedId = ref.watch(selectedAddressIdProvider);
  if (selectedId != null) {
    for (final address in addresses) {
      if (address.id == selectedId) return address;
    }
  }

  for (final address in addresses) {
    if (address.isDefault) return address;
  }
  return addresses.first;
});

final selectedAddressIdProvider = StateProvider<String?>((ref) => null);

// ── Orders ─────────────────────────────────────────────────────────────────
final myOrdersProvider = FutureProvider.family<OrderList, String>((
  ref,
  scope,
) async {
  final session = ref.watch(currentSessionProvider);
  if (session.isGuest) return const OrderList(orders: []);
  return ref.watch(orderRepositoryProvider).myOrders(scope: scope);
});

/// A single order, refreshed whenever realtime reports a change to it.
final orderDetailProvider = FutureProvider.family<OrderDetail, String>((
  ref,
  orderId,
) async {
  final repository = ref.watch(orderRepositoryProvider);

  // Re-read on every signal rather than trusting the realtime payload, so RLS
  // remains the only thing deciding what the customer can see.
  final subscription = repository.watchOrder(orderId).listen((_) {
    ref.invalidateSelf();
  });
  ref.onDispose(subscription.cancel);

  return repository.detail(orderId);
});

final cancellationOptionsProvider =
    FutureProvider.family<CancellationOptions, String>((ref, orderId) async {
      return ref.watch(orderRepositoryProvider).cancellationOptions(orderId);
    });

/// Orders still in flight — powers the "track your order" strip on the home tab.
final activeOrdersProvider = FutureProvider<List<OrderSummary>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session.isGuest) return const [];

  final list = await ref
      .watch(orderRepositoryProvider)
      .myOrders(scope: 'CURRENT');
  return list.orders.where((order) => order.isActive).toList();
});

// ── Account ────────────────────────────────────────────────────────────────
final walletProvider = FutureProvider<WalletSummary>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session.isGuest) return const WalletSummary();
  return ref.watch(accountRepositoryProvider).wallet();
});

final notificationsProvider = FutureProvider<List<AppNotificationItem>>((
  ref,
) async {
  final session = ref.watch(currentSessionProvider);
  if (session.isGuest) return const [];
  return ref.watch(accountRepositoryProvider).notifications();
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref
      .watch(notificationsProvider)
      .maybeWhen(
        data: (items) => items.where((item) => item.isUnread).length,
        orElse: () => 0,
      );
});

final supportTicketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session.isGuest) return const [];
  return ref.watch(accountRepositoryProvider).tickets();
});

final supportThreadProvider = FutureProvider.family<SupportThread, String>((
  ref,
  ticketId,
) async {
  return ref.watch(accountRepositoryProvider).ticket(ticketId);
});

final availableCouponsProvider = FutureProvider<List<CustomerCoupon>>((
  ref,
) async {
  final session = ref.watch(currentSessionProvider);
  if (session.isGuest) return const [];

  final branchId = ref.watch(activeBranchIdProvider);
  return ref.watch(cartRepositoryProvider).availableCoupons(branchId: branchId);
});
