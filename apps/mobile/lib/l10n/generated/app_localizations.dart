import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @friendsTab.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsTab;

  /// No description provided for @yourProfile.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get yourProfile;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get hindi;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get profileUpdated;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Saved favorites'**
  String get favorites;

  /// No description provided for @referrals.
  ///
  /// In en, this message translates to:
  /// **'Refer a friend'**
  String get referrals;

  /// No description provided for @outlet.
  ///
  /// In en, this message translates to:
  /// **'Ordering from'**
  String get outlet;

  /// No description provided for @chooseOutlet.
  ///
  /// In en, this message translates to:
  /// **'Choose an outlet'**
  String get chooseOutlet;

  /// No description provided for @outletChanged.
  ///
  /// In en, this message translates to:
  /// **'Outlet changed. Your other outlet\'s cart is saved separately.'**
  String get outletChanged;

  /// No description provided for @outletPickerBrowsingHint.
  ///
  /// In en, this message translates to:
  /// **'Choose an outlet for menu availability and checkout.'**
  String get outletPickerBrowsingHint;

  /// No description provided for @outletPickerAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Outlets are checked against your saved delivery address.'**
  String get outletPickerAddressHint;

  /// No description provided for @switchOutletTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch outlet?'**
  String get switchOutletTitle;

  /// No description provided for @stayAtOutlet.
  ///
  /// In en, this message translates to:
  /// **'Stay here'**
  String get stayAtOutlet;

  /// No description provided for @switchOutletAction.
  ///
  /// In en, this message translates to:
  /// **'Switch outlet'**
  String get switchOutletAction;

  /// No description provided for @orderCriticalMessages.
  ///
  /// In en, this message translates to:
  /// **'Order-critical updates help us complete your order. Optional offers are controlled separately.'**
  String get orderCriticalMessages;

  /// No description provided for @offersConsent.
  ///
  /// In en, this message translates to:
  /// **'Offers and new dish alerts'**
  String get offersConsent;

  /// No description provided for @signInForFavorites.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save favorites across your devices.'**
  String get signInForFavorites;

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'You have not saved any dishes yet.'**
  String get noFavorites;

  /// No description provided for @referralCode.
  ///
  /// In en, this message translates to:
  /// **'Your referral code'**
  String get referralCode;

  /// No description provided for @enterReferralCode.
  ///
  /// In en, this message translates to:
  /// **'Enter a friend\'s code'**
  String get enterReferralCode;

  /// No description provided for @applyReferral.
  ///
  /// In en, this message translates to:
  /// **'Apply code'**
  String get applyReferral;

  /// No description provided for @referralApplied.
  ///
  /// In en, this message translates to:
  /// **'Referral code applied.'**
  String get referralApplied;

  /// No description provided for @referralUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The referral program is not active yet.'**
  String get referralUnavailable;

  /// No description provided for @shareReferral.
  ///
  /// In en, this message translates to:
  /// **'Share code'**
  String get shareReferral;

  /// No description provided for @copyReferral.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyReferral;

  /// No description provided for @unavailableAtOutlet.
  ///
  /// In en, this message translates to:
  /// **'Unavailable at this outlet'**
  String get unavailableAtOutlet;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose a language'**
  String get chooseLanguage;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @takingOrders.
  ///
  /// In en, this message translates to:
  /// **'Taking orders now'**
  String get takingOrders;

  /// No description provided for @currentlyClosed.
  ///
  /// In en, this message translates to:
  /// **'Currently closed'**
  String get currentlyClosed;

  /// No description provided for @pickupOnly.
  ///
  /// In en, this message translates to:
  /// **'Delivery is unavailable here; pickup is available'**
  String get pickupOnly;

  /// No description provided for @discontinuedDish.
  ///
  /// In en, this message translates to:
  /// **'Dish no longer on the menu'**
  String get discontinuedDish;

  /// No description provided for @removeFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFavorite;

  /// No description provided for @referralSignInDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your phone to attach a code before your first eligible order.'**
  String get referralSignInDescription;

  /// No description provided for @referralShareDescription.
  ///
  /// In en, this message translates to:
  /// **'Share your code. Rewards follow the published program terms.'**
  String get referralShareDescription;

  /// No description provided for @referralCounts.
  ///
  /// In en, this message translates to:
  /// **'{invited, plural, =0{No one invited} one{{invited} invited} other{{invited} invited}} · {rewarded, plural, =0{none rewarded} one{{rewarded} rewarded} other{{rewarded} rewarded}}'**
  String referralCounts(int invited, int rewarded);

  /// No description provided for @applying.
  ///
  /// In en, this message translates to:
  /// **'Applying…'**
  String get applying;

  /// No description provided for @referralCopied.
  ///
  /// In en, this message translates to:
  /// **'Referral code copied.'**
  String get referralCopied;

  /// No description provided for @inviteCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite copied.'**
  String get inviteCopied;

  /// No description provided for @referralInviteMessageCode.
  ///
  /// In en, this message translates to:
  /// **'Use my Bites Box referral code: {code}'**
  String referralInviteMessageCode(Object code);

  /// No description provided for @referralInviteMessageWithLink.
  ///
  /// In en, this message translates to:
  /// **'Use my Bites Box referral code {code}: {url}'**
  String referralInviteMessageWithLink(Object code, Object url);

  /// No description provided for @yourCart.
  ///
  /// In en, this message translates to:
  /// **'Your cart'**
  String get yourCart;

  /// No description provided for @signInToBuildCart.
  ///
  /// In en, this message translates to:
  /// **'Sign in to build your cart'**
  String get signInToBuildCart;

  /// No description provided for @cartSavedToAccount.
  ///
  /// In en, this message translates to:
  /// **'Your cart is saved to your account so you can pick up where you left off.'**
  String get cartSavedToAccount;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearCartTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear your cart?'**
  String get clearCartTitle;

  /// No description provided for @clearCartMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes every item you have added.'**
  String get clearCartMessage;

  /// No description provided for @clearCartAction.
  ///
  /// In en, this message translates to:
  /// **'Clear cart'**
  String get clearCartAction;

  /// No description provided for @emptyCartTitle.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get emptyCartTitle;

  /// No description provided for @emptyCartMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a few dishes from the menu and they will show up here.'**
  String get emptyCartMessage;

  /// No description provided for @browseMenu.
  ///
  /// In en, this message translates to:
  /// **'Browse the menu'**
  String get browseMenu;

  /// No description provided for @unavailableRemoveToContinue.
  ///
  /// In en, this message translates to:
  /// **'Unavailable — remove to continue'**
  String get unavailableRemoveToContinue;

  /// No description provided for @ourMenu.
  ///
  /// In en, this message translates to:
  /// **'Our menu'**
  String get ourMenu;

  /// No description provided for @searchMenu.
  ///
  /// In en, this message translates to:
  /// **'Search the menu'**
  String get searchMenu;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for biryani, litti, thali…'**
  String get searchHint;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @noDishesMatchQuery.
  ///
  /// In en, this message translates to:
  /// **'No dishes match {query}'**
  String noDishesMatchQuery(Object query);

  /// No description provided for @searchSpellingHelp.
  ///
  /// In en, this message translates to:
  /// **'Check the spelling, or browse the menu to see everything we cook.'**
  String get searchSpellingHelp;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No results} one{{count} result} other{{count} results}}'**
  String searchResults(int count);

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Your recent searches'**
  String get recentSearches;

  /// No description provided for @trendingThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Trending this week'**
  String get trendingThisWeek;

  /// No description provided for @mostOrdered.
  ///
  /// In en, this message translates to:
  /// **'Most ordered'**
  String get mostOrdered;

  /// No description provided for @cravingTitle.
  ///
  /// In en, this message translates to:
  /// **'What are you craving?'**
  String get cravingTitle;

  /// No description provided for @startTypingSearch.
  ///
  /// In en, this message translates to:
  /// **'Start typing to search our whole menu.'**
  String get startTypingSearch;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @cartEmptyForCheckout.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmptyForCheckout;

  /// No description provided for @fulfilmentChoice.
  ///
  /// In en, this message translates to:
  /// **'How would you like it?'**
  String get fulfilmentChoice;

  /// No description provided for @delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// No description provided for @pickUp.
  ///
  /// In en, this message translates to:
  /// **'Pick up'**
  String get pickUp;

  /// No description provided for @deliverTo.
  ///
  /// In en, this message translates to:
  /// **'Deliver to'**
  String get deliverTo;

  /// No description provided for @chooseAddress.
  ///
  /// In en, this message translates to:
  /// **'Choose an address'**
  String get chooseAddress;

  /// No description provided for @whenToOrder.
  ///
  /// In en, this message translates to:
  /// **'When?'**
  String get whenToOrder;

  /// No description provided for @asSoonAsPossible.
  ///
  /// In en, this message translates to:
  /// **'As soon as possible'**
  String get asSoonAsPossible;

  /// No description provided for @scheduleForLater.
  ///
  /// In en, this message translates to:
  /// **'Schedule for later'**
  String get scheduleForLater;

  /// No description provided for @changeSlot.
  ///
  /// In en, this message translates to:
  /// **'Change slot'**
  String get changeSlot;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @payOnline.
  ///
  /// In en, this message translates to:
  /// **'Pay online'**
  String get payOnline;

  /// No description provided for @cashOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Cash on delivery'**
  String get cashOnDelivery;

  /// No description provided for @payAtCounter.
  ///
  /// In en, this message translates to:
  /// **'Pay at the counter'**
  String get payAtCounter;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Bites Box wallet'**
  String get wallet;

  /// No description provided for @useWalletBalance.
  ///
  /// In en, this message translates to:
  /// **'Use my {amount} balance'**
  String useWalletBalance(Object amount);

  /// No description provided for @tipDeliveryPartner.
  ///
  /// In en, this message translates to:
  /// **'Tip your delivery partner'**
  String get tipDeliveryPartner;

  /// No description provided for @offers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get offers;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get placeOrder;

  /// No description provided for @orderSavedPaymentPending.
  ///
  /// In en, this message translates to:
  /// **'Your order is saved. Finish the payment to confirm it.'**
  String get orderSavedPaymentPending;

  /// No description provided for @applyCoupon.
  ///
  /// In en, this message translates to:
  /// **'Apply a coupon'**
  String get applyCoupon;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @cartItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} one{{count} item} other{{count} items}}'**
  String cartItemCount(int count);

  /// No description provided for @menuEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'The menu is empty'**
  String get menuEmptyTitle;

  /// No description provided for @menuEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Dishes are being added. Please check back shortly.'**
  String get menuEmptyMessage;

  /// No description provided for @nothingMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches'**
  String get nothingMatches;

  /// No description provided for @clearFiltersMessage.
  ///
  /// In en, this message translates to:
  /// **'Try clearing your filters to see more dishes.'**
  String get clearFiltersMessage;

  /// No description provided for @categoryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'This category has no dishes right now.'**
  String get categoryEmptyMessage;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @deliveryAddressInstruction.
  ///
  /// In en, this message translates to:
  /// **'Choose where we should deliver this order.'**
  String get deliveryAddressInstruction;

  /// No description provided for @readyInAbout.
  ///
  /// In en, this message translates to:
  /// **'Ready in about {duration}'**
  String readyInAbout(Object duration);

  /// No description provided for @pickFutureSlot.
  ///
  /// In en, this message translates to:
  /// **'Pick a slot at least 30 minutes from now'**
  String get pickFutureSlot;

  /// No description provided for @onlinePaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'UPI, cards, netbanking and wallets'**
  String get onlinePaymentMethods;

  /// No description provided for @payDeliveryPartner.
  ///
  /// In en, this message translates to:
  /// **'Pay the delivery partner when your order arrives'**
  String get payDeliveryPartner;

  /// No description provided for @payWhenCollecting.
  ///
  /// In en, this message translates to:
  /// **'Settle the bill when you collect your order'**
  String get payWhenCollecting;

  /// No description provided for @walletOnHold.
  ///
  /// In en, this message translates to:
  /// **'Your wallet is on hold. Please contact support.'**
  String get walletOnHold;

  /// No description provided for @walletAppliedToOrder.
  ///
  /// In en, this message translates to:
  /// **'{amount} applied to this order'**
  String walletAppliedToOrder(Object amount);

  /// No description provided for @walletAppliedFirst.
  ///
  /// In en, this message translates to:
  /// **'Applied to the order total first'**
  String get walletAppliedFirst;

  /// No description provided for @tipGoesToRider.
  ///
  /// In en, this message translates to:
  /// **'The full tip goes to your delivery partner.'**
  String get tipGoesToRider;

  /// No description provided for @noTip.
  ///
  /// In en, this message translates to:
  /// **'No tip'**
  String get noTip;

  /// No description provided for @viewOffers.
  ///
  /// In en, this message translates to:
  /// **'View offers'**
  String get viewOffers;

  /// No description provided for @noCouponApplied.
  ///
  /// In en, this message translates to:
  /// **'No coupon applied'**
  String get noCouponApplied;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get payNow;

  /// No description provided for @automaticOfferApplied.
  ///
  /// In en, this message translates to:
  /// **'{offer} applied automatically'**
  String automaticOfferApplied(Object offer);

  /// No description provided for @savingAmount.
  ///
  /// In en, this message translates to:
  /// **'saving {amount}'**
  String savingAmount(Object amount);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
