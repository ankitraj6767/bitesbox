// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get account => 'खाता';

  @override
  String get home => 'होम';

  @override
  String get menu => 'मेन्यू';

  @override
  String get orders => 'ऑर्डर';

  @override
  String get friendsTab => 'दोस्त';

  @override
  String get yourProfile => 'आपकी प्रोफ़ाइल';

  @override
  String get fullName => 'पूरा नाम';

  @override
  String get email => 'ईमेल';

  @override
  String get language => 'ऐप की भाषा';

  @override
  String get english => 'English';

  @override
  String get hindi => 'हिन्दी';

  @override
  String get saveChanges => 'बदलाव सहेजें';

  @override
  String get profileUpdated => 'प्रोफ़ाइल अपडेट हुई।';

  @override
  String get favorites => 'पसंदीदा व्यंजन';

  @override
  String get referrals => 'दोस्त को आमंत्रित करें';

  @override
  String get outlet => 'ऑर्डर का आउटलेट';

  @override
  String get chooseOutlet => 'आउटलेट चुनें';

  @override
  String get outletChanged =>
      'आउटलेट बदल गया। दूसरे आउटलेट की कार्ट अलग से सुरक्षित है।';

  @override
  String get outletPickerBrowsingHint =>
      'मेन्यू और चेकआउट के लिए आउटलेट चुनें।';

  @override
  String get outletPickerAddressHint =>
      'आउटलेट आपके सहेजे गए डिलीवरी पते के अनुसार जाँचे जाते हैं।';

  @override
  String get switchOutletTitle => 'आउटलेट बदलें?';

  @override
  String get stayAtOutlet => 'यहीं रहें';

  @override
  String get switchOutletAction => 'आउटलेट बदलें';

  @override
  String get orderCriticalMessages =>
      'ऑर्डर पूरा करने के लिए ज़रूरी अपडेट भेजे जा सकते हैं। ऑफ़र के संदेश अलग से नियंत्रित होते हैं।';

  @override
  String get offersConsent => 'ऑफ़र और नए व्यंजन की जानकारी';

  @override
  String get signInForFavorites =>
      'अपने डिवाइसों पर पसंदीदा व्यंजन सहेजने के लिए साइन इन करें।';

  @override
  String get noFavorites => 'आपने अभी कोई व्यंजन पसंदीदा नहीं रखा है।';

  @override
  String get referralCode => 'आपका रेफ़रल कोड';

  @override
  String get enterReferralCode => 'दोस्त का कोड दर्ज करें';

  @override
  String get applyReferral => 'कोड लागू करें';

  @override
  String get referralApplied => 'रेफ़रल कोड लागू हो गया।';

  @override
  String get referralUnavailable => 'रेफ़रल प्रोग्राम अभी चालू नहीं है।';

  @override
  String get shareReferral => 'कोड साझा करें';

  @override
  String get copyReferral => 'कोड कॉपी करें';

  @override
  String get unavailableAtOutlet => 'इस आउटलेट पर उपलब्ध नहीं';

  @override
  String get chooseLanguage => 'भाषा चुनें';

  @override
  String get signIn => 'साइन इन';

  @override
  String get takingOrders => 'अभी ऑर्डर लिए जा रहे हैं';

  @override
  String get currentlyClosed => 'अभी बंद है';

  @override
  String get pickupOnly => 'यहाँ डिलीवरी उपलब्ध नहीं है; पिकअप उपलब्ध है';

  @override
  String get discontinuedDish => 'यह व्यंजन अब मेन्यू में नहीं है';

  @override
  String get removeFavorite => 'पसंदीदा से हटाएँ';

  @override
  String get referralSignInDescription =>
      'पहले योग्य ऑर्डर से पहले कोड जोड़ने के लिए फ़ोन से साइन इन करें।';

  @override
  String get referralShareDescription =>
      'अपना कोड साझा करें। इनाम प्रकाशित प्रोग्राम की शर्तों के अनुसार मिलते हैं।';

  @override
  String referralCounts(int invited, int rewarded) {
    String _temp0 = intl.Intl.pluralLogic(
      invited,
      locale: localeName,
      other: '$invited आमंत्रित',
      one: '$invited आमंत्रित',
      zero: 'कोई आमंत्रित नहीं',
    );
    String _temp1 = intl.Intl.pluralLogic(
      rewarded,
      locale: localeName,
      other: '$rewarded को इनाम',
      one: '$rewarded को इनाम',
      zero: 'कोई इनाम नहीं',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get applying => 'लागू हो रहा है…';

  @override
  String get referralCopied => 'रेफ़रल कोड कॉपी हुआ।';

  @override
  String get inviteCopied => 'आमंत्रण कॉपी हुआ।';

  @override
  String referralInviteMessageCode(Object code) {
    return 'मेरा Bites Box रेफ़रल कोड इस्तेमाल करें: $code';
  }

  @override
  String referralInviteMessageWithLink(Object code, Object url) {
    return 'मेरा Bites Box रेफ़रल कोड $code इस्तेमाल करें: $url';
  }

  @override
  String get yourCart => 'आपकी कार्ट';

  @override
  String get signInToBuildCart => 'कार्ट बनाने के लिए साइन इन करें';

  @override
  String get cartSavedToAccount =>
      'आपकी कार्ट खाते में सुरक्षित रहती है, आप बाद में वहीं से जारी रख सकते हैं।';

  @override
  String get clear => 'हटाएँ';

  @override
  String get clearCartTitle => 'कार्ट खाली करें?';

  @override
  String get clearCartMessage => 'इससे जोड़े गए सभी आइटम हट जाएँगे।';

  @override
  String get clearCartAction => 'कार्ट खाली करें';

  @override
  String get emptyCartTitle => 'आपकी कार्ट खाली है';

  @override
  String get emptyCartMessage =>
      'मेन्यू से कुछ व्यंजन जोड़ें, वे यहाँ दिखेंगे।';

  @override
  String get browseMenu => 'मेन्यू देखें';

  @override
  String get unavailableRemoveToContinue =>
      'उपलब्ध नहीं — आगे बढ़ने के लिए हटाएँ';

  @override
  String get ourMenu => 'हमारा मेन्यू';

  @override
  String get searchMenu => 'मेन्यू खोजें';

  @override
  String get searchHint => 'बिरयानी, लिट्टी, थाली खोजें…';

  @override
  String get clearSearch => 'खोज हटाएँ';

  @override
  String noDishesMatchQuery(Object query) {
    return '$query से कोई व्यंजन नहीं मिला';
  }

  @override
  String get searchSpellingHelp =>
      'वर्तनी जाँचें या हमारे सभी व्यंजन देखने के लिए मेन्यू खोलें।';

  @override
  String searchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count परिणाम',
      one: '$count परिणाम',
      zero: 'कोई परिणाम नहीं',
    );
    return '$_temp0';
  }

  @override
  String get recentSearches => 'आपकी हाल की खोजें';

  @override
  String get trendingThisWeek => 'इस सप्ताह लोकप्रिय';

  @override
  String get mostOrdered => 'सबसे ज़्यादा ऑर्डर किए गए';

  @override
  String get cravingTitle => 'क्या खाने का मन है?';

  @override
  String get startTypingSearch => 'मेन्यू में खोजने के लिए लिखना शुरू करें।';

  @override
  String get checkout => 'चेकआउट';

  @override
  String get cartEmptyForCheckout => 'आपकी कार्ट खाली है';

  @override
  String get fulfilmentChoice => 'ऑर्डर कैसे चाहिए?';

  @override
  String get delivery => 'डिलीवरी';

  @override
  String get pickUp => 'पिकअप';

  @override
  String get deliverTo => 'यहाँ डिलीवर करें';

  @override
  String get chooseAddress => 'पता चुनें';

  @override
  String get whenToOrder => 'कब चाहिए?';

  @override
  String get asSoonAsPossible => 'जितनी जल्दी हो सके';

  @override
  String get scheduleForLater => 'बाद के लिए तय करें';

  @override
  String get changeSlot => 'समय बदलें';

  @override
  String get payment => 'भुगतान';

  @override
  String get payOnline => 'ऑनलाइन भुगतान';

  @override
  String get cashOnDelivery => 'डिलीवरी पर नकद';

  @override
  String get payAtCounter => 'काउंटर पर भुगतान';

  @override
  String get wallet => 'बाइट्स बॉक्स वॉलेट';

  @override
  String useWalletBalance(Object amount) {
    return 'मेरे $amount बैलेंस का उपयोग करें';
  }

  @override
  String get tipDeliveryPartner => 'डिलीवरी पार्टनर को टिप दें';

  @override
  String get offers => 'ऑफ़र';

  @override
  String get placeOrder => 'ऑर्डर करें';

  @override
  String get orderSavedPaymentPending =>
      'आपका ऑर्डर सुरक्षित है। पुष्टि के लिए भुगतान पूरा करें।';

  @override
  String get applyCoupon => 'कूपन लागू करें';

  @override
  String get remove => 'हटाएँ';

  @override
  String cartItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count आइटम',
      one: '$count आइटम',
      zero: 'कोई आइटम नहीं',
    );
    return '$_temp0';
  }

  @override
  String get menuEmptyTitle => 'मेन्यू खाली है';

  @override
  String get menuEmptyMessage =>
      'व्यंजन जोड़े जा रहे हैं। थोड़ी देर बाद फिर देखें।';

  @override
  String get nothingMatches => 'कोई परिणाम नहीं';

  @override
  String get clearFiltersMessage => 'और व्यंजन देखने के लिए फ़िल्टर हटाएँ।';

  @override
  String get categoryEmptyMessage => 'इस श्रेणी में अभी कोई व्यंजन नहीं है।';

  @override
  String get clearFilters => 'फ़िल्टर हटाएँ';

  @override
  String get add => 'जोड़ें';

  @override
  String get change => 'बदलें';

  @override
  String get deliveryAddressInstruction =>
      'चुनें कि यह ऑर्डर कहाँ डिलीवर करना है।';

  @override
  String readyInAbout(Object duration) {
    return 'लगभग $duration में तैयार';
  }

  @override
  String get pickFutureSlot => 'अभी से कम से कम 30 मिनट बाद का समय चुनें';

  @override
  String get onlinePaymentMethods => 'UPI, कार्ड, नेटबैंकिंग और वॉलेट';

  @override
  String get payDeliveryPartner =>
      'ऑर्डर पहुँचने पर डिलीवरी पार्टनर को भुगतान करें';

  @override
  String get payWhenCollecting => 'ऑर्डर लेते समय बिल चुकाएँ';

  @override
  String get walletOnHold => 'आपका वॉलेट रोका गया है। सहायता से संपर्क करें।';

  @override
  String walletAppliedToOrder(Object amount) {
    return 'इस ऑर्डर में $amount इस्तेमाल हुआ';
  }

  @override
  String get walletAppliedFirst => 'पहले ऑर्डर के कुल में लागू होगा';

  @override
  String get tipGoesToRider => 'पूरी टिप आपके डिलीवरी पार्टनर को मिलेगी।';

  @override
  String get noTip => 'टिप नहीं';

  @override
  String get viewOffers => 'ऑफ़र देखें';

  @override
  String get noCouponApplied => 'कोई कूपन लागू नहीं';

  @override
  String get payNow => 'अभी भुगतान करें';

  @override
  String automaticOfferApplied(Object offer) {
    return '$offer अपने आप लागू हुआ';
  }

  @override
  String savingAmount(Object amount) {
    return '$amount की बचत';
  }
}
