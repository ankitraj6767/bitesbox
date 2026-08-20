import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/providers/core_providers.dart';
import '../data/cart_models.dart';
import 'customer_providers.dart';

/// The cart.
///
/// State is always a server-computed [CheckoutQuote]. Nothing is ever patched
/// locally: adding an item replaces the whole quote with the one the database
/// just calculated, which is why the displayed total can never drift from what
/// will actually be charged.
class CartController extends AsyncNotifier<CheckoutQuote> {
  @override
  Future<CheckoutQuote> build() async {
    final session = ref.watch(currentSessionProvider);
    if (session.isGuest) return const CheckoutQuote.empty();

    final branchId = ref.watch(activeBranchIdProvider);
    return ref.watch(cartRepositoryProvider).quote(branchId: branchId);
  }

  String? get _branchId => ref.read(activeBranchIdProvider);

  /// Runs a cart mutation, keeping the previous quote visible while it is in
  /// flight so the cart never blinks empty, and restoring it if the call fails.
  Future<void> _mutate(Future<CheckoutQuote> Function() action) async {
    final previous = state.valueOrNull;
    state = const AsyncValue<CheckoutQuote>.loading().copyWithPrevious(state);

    try {
      state = AsyncValue.data(await action());
    } on AppError catch (error, stackTrace) {
      // Keep the last good cart on screen and surface the error to the caller.
      state = previous == null
          ? AsyncValue.error(error, stackTrace)
          : AsyncValue.data(previous);
      rethrow;
    }
  }

  Future<void> addItem({
    required String productId,
    String? variantId,
    int quantity = 1,
    List<ModifierSelection> modifiers = const [],
    String? specialInstructions,
    bool replaceQuantity = false,
  }) {
    return _mutate(() => ref.read(cartRepositoryProvider).addItem(
          productId: productId,
          variantId: variantId,
          quantity: quantity,
          modifiers: modifiers,
          specialInstructions: specialInstructions,
          branchId: _branchId,
          replaceQuantity: replaceQuantity,
        ));
  }

  /// A quantity of zero removes the line, matching the server's behaviour.
  Future<void> setQuantity({required String cartItemId, required int quantity}) {
    return _mutate(() => ref.read(cartRepositoryProvider).updateQuantity(
          cartItemId: cartItemId,
          quantity: quantity,
        ));
  }

  Future<void> removeItem(String cartItemId) {
    return _mutate(() => ref.read(cartRepositoryProvider).removeItem(cartItemId));
  }

  Future<void> clear() {
    return _mutate(() => ref.read(cartRepositoryProvider).clear(branchId: _branchId));
  }

  Future<void> setFulfilment(String fulfilmentType) {
    return _mutate(() => ref.read(cartRepositoryProvider).setOptions(
          branchId: _branchId,
          fulfilmentType: fulfilmentType,
        ));
  }

  Future<void> setAddress(String addressId) {
    return _mutate(() => ref.read(cartRepositoryProvider).setOptions(
          branchId: _branchId,
          addressId: addressId,
          fulfilmentType: 'DELIVERY',
        ));
  }

  Future<void> setTimingNow() {
    return _mutate(() => ref.read(cartRepositoryProvider).setOptions(
          branchId: _branchId,
          timing: 'NOW',
        ));
  }

  Future<void> scheduleFor(DateTime when) {
    return _mutate(() => ref.read(cartRepositoryProvider).setOptions(
          branchId: _branchId,
          timing: 'SCHEDULED',
          scheduledFor: when,
        ));
  }

  Future<void> setInstructions({String? delivery, String? cooking}) {
    return _mutate(() => ref.read(cartRepositoryProvider).setOptions(
          branchId: _branchId,
          deliveryInstructions: delivery,
          cookingInstructions: cooking,
        ));
  }

  Future<void> setUseWallet(bool useWallet) {
    return _mutate(() => ref.read(cartRepositoryProvider).setOptions(
          branchId: _branchId,
          useWallet: useWallet,
        ));
  }

  Future<void> applyCoupon(String code) {
    return _mutate(() => ref.read(cartRepositoryProvider).applyCoupon(
          code,
          branchId: _branchId,
        ));
  }

  Future<void> removeCoupon() {
    return _mutate(
      () => ref.read(cartRepositoryProvider).removeCoupon(branchId: _branchId),
    );
  }

  /// Re-prices for a payment mode, tip and loyalty redemption. Called on the
  /// checkout screen so COD limits and loyalty caps are enforced before paying.
  Future<void> reprice({
    String? paymentMode,
    double tipAmount = 0,
    int loyaltyPoints = 0,
  }) {
    return _mutate(() => ref.read(cartRepositoryProvider).quote(
          branchId: _branchId,
          cartId: state.valueOrNull?.cartId,
          paymentMode: paymentMode,
          tipAmount: tipAmount,
          loyaltyPoints: loyaltyPoints,
        ));
  }

  /// Rebuilds the cart from a past order. Returns the lines that could not be
  /// restored so the screen can say exactly what changed.
  Future<List<SkippedItem>> reorder(String orderId) async {
    List<SkippedItem> skipped = const [];

    await _mutate(() async {
      final quote = await ref.read(cartRepositoryProvider).reorder(orderId);
      skipped = quote.skippedItems;
      return quote;
    });

    return skipped;
  }

  /// Pulls a fresh quote — used after returning from the background, since
  /// availability and the store's open state may have changed while away.
  Future<void> refresh() async {
    state = const AsyncValue<CheckoutQuote>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(cartRepositoryProvider).quote(branchId: _branchId),
    );
  }
}

final cartProvider = AsyncNotifierProvider<CartController, CheckoutQuote>(
  CartController.new,
);

/// The quote as currently known, treating "loading" as the previous value so
/// badges and the cart bar do not flicker during a mutation.
final cartQuoteProvider = Provider<CheckoutQuote>((ref) {
  return ref.watch(cartProvider).valueOrNull ?? const CheckoutQuote.empty();
});

/// Units in the cart, for the tab-bar badge.
final cartUnitCountProvider = Provider<int>((ref) {
  return ref.watch(cartQuoteProvider).unitCount;
});

/// Quantity of one product already in the cart, so a menu card can show a
/// stepper instead of "Add". Sums every configuration of that product.
final productCartQuantityProvider = Provider.family<int, String>((ref, productId) {
  final quote = ref.watch(cartQuoteProvider);
  var total = 0;
  for (final line in quote.lines) {
    if (line.productId == productId) total += line.quantity;
  }
  return total;
});

/// The single cart line for a product, when it appears exactly once. A stepper on
/// a menu card can only safely edit an unambiguous line.
final singleCartLineProvider =
    Provider.family<CheckoutLine?, String>((ref, productId) {
  final lines = ref
      .watch(cartQuoteProvider)
      .lines
      .where((line) => line.productId == productId)
      .toList();

  return lines.length == 1 ? lines.first : null;
});
