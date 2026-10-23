// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get account => 'Account';

  @override
  String get home => 'Home';

  @override
  String get menu => 'Menu';

  @override
  String get orders => 'Orders';

  @override
  String get yourProfile => 'Your profile';

  @override
  String get fullName => 'Full name';

  @override
  String get email => 'Email';

  @override
  String get language => 'App language';

  @override
  String get english => 'English';

  @override
  String get hindi => 'हिन्दी';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get profileUpdated => 'Profile updated.';

  @override
  String get favorites => 'Saved favorites';

  @override
  String get referrals => 'Refer a friend';

  @override
  String get outlet => 'Ordering from';

  @override
  String get chooseOutlet => 'Choose an outlet';

  @override
  String get outletChanged =>
      'Outlet changed. Your other outlet\'s cart is saved separately.';

  @override
  String get outletPickerBrowsingHint =>
      'Choose an outlet for menu availability and checkout.';

  @override
  String get outletPickerAddressHint =>
      'Outlets are checked against your saved delivery address.';

  @override
  String get switchOutletTitle => 'Switch outlet?';

  @override
  String get stayAtOutlet => 'Stay here';

  @override
  String get switchOutletAction => 'Switch outlet';

  @override
  String get orderCriticalMessages =>
      'Order-critical updates help us complete your order. Optional offers are controlled separately.';

  @override
  String get offersConsent => 'Offers and new dish alerts';

  @override
  String get signInForFavorites =>
      'Sign in to save favorites across your devices.';

  @override
  String get noFavorites => 'You have not saved any dishes yet.';

  @override
  String get referralCode => 'Your referral code';

  @override
  String get enterReferralCode => 'Enter a friend\'s code';

  @override
  String get applyReferral => 'Apply code';

  @override
  String get referralApplied => 'Referral code applied.';

  @override
  String get referralUnavailable => 'The referral program is not active yet.';

  @override
  String get shareReferral => 'Share code';

  @override
  String get copyReferral => 'Copy code';

  @override
  String get unavailableAtOutlet => 'Unavailable at this outlet';

  @override
  String get chooseLanguage => 'Choose a language';

  @override
  String get signIn => 'Sign in';

  @override
  String get takingOrders => 'Taking orders now';

  @override
  String get currentlyClosed => 'Currently closed';

  @override
  String get pickupOnly => 'Delivery is unavailable here; pickup is available';

  @override
  String get discontinuedDish => 'Dish no longer on the menu';

  @override
  String get removeFavorite => 'Remove from favorites';

  @override
  String get referralSignInDescription =>
      'Sign in with your phone to attach a code before your first eligible order.';

  @override
  String get referralShareDescription =>
      'Share your code. Rewards follow the published program terms.';

  @override
  String referralCounts(int invited, int rewarded) {
    String _temp0 = intl.Intl.pluralLogic(
      invited,
      locale: localeName,
      other: '$invited invited',
      one: '$invited invited',
      zero: 'No one invited',
    );
    String _temp1 = intl.Intl.pluralLogic(
      rewarded,
      locale: localeName,
      other: '$rewarded rewarded',
      one: '$rewarded rewarded',
      zero: 'none rewarded',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get applying => 'Applying…';

  @override
  String get referralCopied => 'Referral code copied.';

  @override
  String get inviteCopied => 'Invite copied.';

  @override
  String referralInviteMessageCode(Object code) {
    return 'Use my Bites Box referral code: $code';
  }

  @override
  String referralInviteMessageWithLink(Object code, Object url) {
    return 'Use my Bites Box referral code $code: $url';
  }

  @override
  String get yourCart => 'Your cart';

  @override
  String get signInToBuildCart => 'Sign in to build your cart';

  @override
  String get cartSavedToAccount =>
      'Your cart is saved to your account so you can pick up where you left off.';

  @override
  String get clear => 'Clear';

  @override
  String get clearCartTitle => 'Clear your cart?';

  @override
  String get clearCartMessage => 'This removes every item you have added.';

  @override
  String get clearCartAction => 'Clear cart';

  @override
  String get emptyCartTitle => 'Your cart is empty';

  @override
  String get emptyCartMessage =>
      'Add a few dishes from the menu and they will show up here.';

  @override
  String get browseMenu => 'Browse the menu';

  @override
  String get unavailableRemoveToContinue => 'Unavailable — remove to continue';

  @override
  String get ourMenu => 'Our menu';

  @override
  String get searchMenu => 'Search the menu';

  @override
  String get searchHint => 'Search for biryani, litti, thali…';

  @override
  String get clearSearch => 'Clear search';

  @override
  String noDishesMatchQuery(Object query) {
    return 'No dishes match $query';
  }

  @override
  String get searchSpellingHelp =>
      'Check the spelling, or browse the menu to see everything we cook.';

  @override
  String searchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '$count result',
      zero: 'No results',
    );
    return '$_temp0';
  }

  @override
  String get recentSearches => 'Your recent searches';

  @override
  String get trendingThisWeek => 'Trending this week';

  @override
  String get mostOrdered => 'Most ordered';

  @override
  String get cravingTitle => 'What are you craving?';

  @override
  String get startTypingSearch => 'Start typing to search our whole menu.';

  @override
  String get checkout => 'Checkout';

  @override
  String get cartEmptyForCheckout => 'Your cart is empty';

  @override
  String get fulfilmentChoice => 'How would you like it?';

  @override
  String get delivery => 'Delivery';

  @override
  String get pickUp => 'Pick up';

  @override
  String get deliverTo => 'Deliver to';

  @override
  String get chooseAddress => 'Choose an address';

  @override
  String get whenToOrder => 'When?';

  @override
  String get asSoonAsPossible => 'As soon as possible';

  @override
  String get scheduleForLater => 'Schedule for later';

  @override
  String get changeSlot => 'Change slot';

  @override
  String get payment => 'Payment';

  @override
  String get payOnline => 'Pay online';

  @override
  String get cashOnDelivery => 'Cash on delivery';

  @override
  String get payAtCounter => 'Pay at the counter';

  @override
  String get wallet => 'Bites Box wallet';

  @override
  String useWalletBalance(Object amount) {
    return 'Use my $amount balance';
  }

  @override
  String get tipDeliveryPartner => 'Tip your delivery partner';

  @override
  String get offers => 'Offers';

  @override
  String get placeOrder => 'Place order';

  @override
  String get orderSavedPaymentPending =>
      'Your order is saved. Finish the payment to confirm it.';

  @override
  String get applyCoupon => 'Apply a coupon';

  @override
  String get remove => 'Remove';

  @override
  String cartItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get menuEmptyTitle => 'The menu is empty';

  @override
  String get menuEmptyMessage =>
      'Dishes are being added. Please check back shortly.';

  @override
  String get nothingMatches => 'Nothing matches';

  @override
  String get clearFiltersMessage =>
      'Try clearing your filters to see more dishes.';

  @override
  String get categoryEmptyMessage => 'This category has no dishes right now.';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get add => 'Add';

  @override
  String get change => 'Change';

  @override
  String get deliveryAddressInstruction =>
      'Choose where we should deliver this order.';

  @override
  String readyInAbout(Object duration) {
    return 'Ready in about $duration';
  }

  @override
  String get pickFutureSlot => 'Pick a slot at least 30 minutes from now';

  @override
  String get onlinePaymentMethods => 'UPI, cards, netbanking and wallets';

  @override
  String get payDeliveryPartner =>
      'Pay the delivery partner when your order arrives';

  @override
  String get payWhenCollecting => 'Settle the bill when you collect your order';

  @override
  String get walletOnHold => 'Your wallet is on hold. Please contact support.';

  @override
  String walletAppliedToOrder(Object amount) {
    return '$amount applied to this order';
  }

  @override
  String get walletAppliedFirst => 'Applied to the order total first';

  @override
  String get tipGoesToRider => 'The full tip goes to your delivery partner.';

  @override
  String get noTip => 'No tip';

  @override
  String get viewOffers => 'View offers';

  @override
  String get noCouponApplied => 'No coupon applied';

  @override
  String get payNow => 'Pay now';

  @override
  String automaticOfferApplied(Object offer) {
    return '$offer applied automatically';
  }

  @override
  String savingAmount(Object amount) {
    return 'saving $amount';
  }
}
