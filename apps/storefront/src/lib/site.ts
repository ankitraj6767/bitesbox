export const siteUrl = (process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3001').replace(/\/$/, '');

export function hasSameSiteOrigin(request: Request) {
    const origin = request.headers.get('origin');
    if (!origin) return true;
    try {
        const configuredOrigin = process.env.NEXT_PUBLIC_SITE_URL ? new URL(siteUrl).origin : new URL(request.url).origin;
        return origin === configuredOrigin;
    } catch {
        return false;
    }
}

export function storageUrl(path?: string | null) {
    if (!path) return null;
    const expansionPrefix = 'menu-images/products/expansion/';
    if (path.startsWith(expansionPrefix)) {
        return `/bundled/menu/products/${path.slice(expansionPrefix.length)}`;
    }
    const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
    if (!base) return null;
    const known = ['menu-images', 'banners', 'brand-assets'];
    const [first, ...rest] = path.split('/');
    const bucket = known.includes(first) ? first : 'menu-images';
    const key = known.includes(first) ? rest.join('/') : path;
    return `${base}/storage/v1/object/public/${bucket}/${key}`;
}

export type Locale = 'en' | 'hi';

export const messages = {
    en: {
        home: 'Home', menu: 'Menu', favorites: 'Favorites', account: 'Account', cart: 'Cart', offers: 'Offers',
        search: 'Search dishes', chooseOutlet: 'Choose an outlet', orderingFrom: 'Ordering from', outlet: 'Outlet', noOffers: 'No public offers are available at this outlet right now.', signInToSeeOffer: 'Sign in to check which offers apply to your cart.',
        add: 'Add to cart', viewMenu: 'Explore the menu', available: 'Available now', closed: 'Currently closed',
        outOfArea: 'This address is outside delivery coverage', signIn: 'Continue with phone',
        phone: 'Phone number', sendCode: 'Send code', verifyCode: 'Verify code', code: 'Verification code',
        checkout: 'Checkout', deliveryAddress: 'Delivery address', pickup: 'Pickup', delivery: 'Delivery',
        placeOrder: 'Place order', payNow: 'Pay now', orderPlaced: 'Order placed', noProducts: 'No dishes match your search.',
        unavailable: 'Unavailable at this outlet', referral: 'Referral code', apply: 'Apply code',
        copy: 'Copy', save: 'Save', priceChecked: 'Prices and fees are confirmed by Bites Box at checkout.',
        addAddress: 'Add delivery address', street: 'Street and house number', city: 'City', state: 'State',
        locate: 'Use my current location', terms: 'Order updates are transactional. Optional offers follow your saved preferences.',
        help: 'Help and contact', closedReason: 'This outlet is not taking orders at the moment.',
        tagline: 'Bihar favourites, served with a little magic', heroTitle: 'Food made for your cravings.', heroDescription: 'Slow-dum biryani, smoky tandoor favourites and comforting Bihari plates, prepared fresh for your table.',
        freshPicks: 'Fresh from the kitchen', freshPicksDescription: 'Meet the latest additions to the Bites Box menu.',
        chooseYourMood: 'What are you craving?', chooseYourMoodDescription: 'Find a favourite for every mood, from slow-dum classics to something sweet.',
        featuredDish: 'A Bites Box signature', exploreFullMenu: 'Explore the full menu', seeOffers: 'See today’s offers',
        curatedCount: 'curated dishes', freshlyPrepared: 'Prepared with care', regionalFlavours: 'Rooted in Bihar',
        moodEyebrow: 'A little inspiration', freshEyebrow: 'Just landed', heroCareLabel: 'Made with care', heroCareSub: 'From our kitchen to your table',
        prepTime: 'Ready in', servesLabel: 'Portion', spiceLevel: 'Spice', calorieEstimate: 'Approx. calories', containsAllergens: 'Allergen info', dietaryInfo: 'Dietary',
        dishes: 'dishes', all: 'All', vegetarian: 'Vegetarian', nonVeg: 'Non-veg', egg: 'Contains egg', vegan: 'Vegan',
        mild: 'Mild', medium: 'Medium', hot: 'Hot', extraHot: 'Extra hot', favouriteDish: 'Bites Box favourite',
        browseMenu: 'Browse the menu', selectedOutlet: 'Selected outlet', noOutlets: 'No active Bites Box outlet is available right now.',
        outletChanged: 'Outlet changed. Carts and availability are kept separate for each outlet.',
        guestCart: 'Your cart is saved on this device. Sign in to check current price and delivery availability.',
        savedCartTitle: 'Items saved on this device', savedCartDescription: 'Add these items to your account cart. Bites Box will recheck availability and current prices.',
        importSavedCart: 'Add saved items to my cart',
        emptyCart: 'Your cart is empty.', orderUpdates: 'Order updates', optionalOffers: 'Optional offers',
        enterPhone: 'Enter the phone number registered with your account.', otpSent: 'A verification code has been sent if this number can sign in.',
        invalidPhone: 'Enter a valid phone number with country code.', invalidCode: 'Enter the code sent to your phone.',
        referralApplied: 'Referral code applied.', referralInvalid: 'This referral code cannot be applied to this account.',
        signInRequired: 'Sign in with your phone to continue.', continueCheckout: 'Continue to secure checkout',
        orderTracking: 'Order tracking', orderNotFound: 'We could not load this order. Sign in with the account used to place it.',
        loading: 'Loading…', retry: 'Try again', unavailableItem: 'This dish is no longer available at the selected outlet.',
        chooseOptions: 'Choose options', quantity: 'Quantity', specialInstructions: 'Special instructions (optional)',
        deliveryMode: 'Fulfilment', contactHelp: 'Contact support', helpText: 'For help with an existing order, sign in and open its order details.',
        noResults: 'No results found.', resultsFor: 'Search results for', category: 'Category', status: 'Status',
        paymentFailed: 'Payment was not verified. Check your order status before trying again.',
        paymentPending: 'Payment confirmation is pending. Your order remains protected while we verify it.',
        addressLine: 'Address', area: 'Area / locality', postalCode: 'PIN code', latitude: 'Latitude', longitude: 'Longitude',
        useLocation: 'Use device location', outOfAreaMessage: 'Delivery is not available at this location for the selected outlet. You can choose pickup if the outlet supports it.',
        outletOpen: 'Taking orders', outletClosed: 'Not taking orders', pickupUnavailable: 'Pickup is unavailable at this outlet.',
        applyCoupon: 'Apply coupon', couponCode: 'Coupon code', remove: 'Remove', subtotal: 'Items', discount: 'Discount',
        tax: 'Tax', deliveryFee: 'Delivery fee', total: 'Total', wallet: 'Use wallet balance', paymentMethod: 'Payment method',
        onlinePayment: 'Online payment', cashPayment: 'Cash on delivery', paymentDisclaimer: 'Payment is confirmed by Bites Box and Razorpay after checkout.',
        orderNumber: 'Order number', currentStatus: 'Current status', backMenu: 'Back to menu', signOut: 'Sign out',
        referralShare: 'Share your referral code', referralTerms: 'Rewards are available only if the owner enables and publishes program terms.',
        referralInactive: 'Referral invites are not active yet. Check back when the program launches.',
        referralRewardsTitle: 'How the rewards work', youEarn: 'You earn', friendEarns: 'Your friend earns', minimumOrder: 'After an order of at least', rewardExpiry: 'Reward expires after', days: 'days',
        yourInvites: 'Your invites', noInvites: 'No invitations yet.', invite: 'Invite',
        statusAttributed: 'Invited', statusQualified: 'First eligible order placed', statusRewarded: 'Reward credited', statusReversed: 'Reward reversed',
        invited: 'invited', rewarded: 'rewarded', unavailableProduct: 'This dish is currently unavailable at this outlet.',
        privacyMessage: 'We use your location only after you choose to share it to check delivery coverage.',
        locationError: 'Location could not be checked. Enter coordinates or choose pickup.',
        currentOutletCart: 'Each outlet has its own cart. Switching outlets returns to that outlet’s saved cart.',
        tastePassport: 'Taste Passport',
        tastePassportDescription: 'Optional choices for menu recommendations. You can change them any time.',
        tastePassportDisclaimer: 'These choices are not allergy or medical advice. Check item details if you have a dietary concern.',
        foodTypes: 'Food types', maximumSpice: 'Maximum spice level', anyLevel: 'Any level', noSpice: 'No spice',
        favoriteCategories: 'Favorite categories', optionalPriceCeiling: 'Optional item price ceiling',
        tasteCategoriesUnavailable: 'Menu categories are not available right now.',
        leaveBlankPrice: 'Leave blank for any price.', saveTastePassport: 'Save Taste Passport',
        tasteSaved: 'Taste Passport saved.', tasteSaveError: 'Your taste preferences could not be saved. Please try again.',
        tasteSetupTitle: 'Set up your Taste Passport', tasteSetupDescription: 'Choose a few preferences to get more relevant picks.',
        priceCeilingInvalid: 'Enter an item price from ₹1 to ₹100,000.', chooseUpTo20Categories: 'Choose up to 20 categories.',
    },
    hi: {
        home: 'होम', menu: 'मेन्यू', favorites: 'पसंदीदा', account: 'खाता', cart: 'कार्ट', offers: 'ऑफ़र',
        search: 'व्यंजन खोजें', chooseOutlet: 'आउटलेट चुनें', orderingFrom: 'ऑर्डर का आउटलेट', outlet: 'आउटलेट', noOffers: 'इस आउटलेट पर अभी कोई सार्वजनिक ऑफ़र उपलब्ध नहीं है।', signInToSeeOffer: 'अपने कार्ट पर लागू ऑफ़र देखने के लिए साइन इन करें।',
        add: 'कार्ट में जोड़ें', viewMenu: 'मेन्यू देखें', available: 'अभी उपलब्ध', closed: 'अभी बंद है',
        outOfArea: 'इस पते पर डिलीवरी उपलब्ध नहीं है', signIn: 'फ़ोन से जारी रखें',
        phone: 'फ़ोन नंबर', sendCode: 'कोड भेजें', verifyCode: 'कोड सत्यापित करें', code: 'सत्यापन कोड',
        checkout: 'चेकआउट', deliveryAddress: 'डिलीवरी का पता', pickup: 'पिकअप', delivery: 'डिलीवरी',
        placeOrder: 'ऑर्डर करें', payNow: 'अभी भुगतान करें', orderPlaced: 'ऑर्डर मिल गया', noProducts: 'आपकी खोज से कोई व्यंजन नहीं मिला।',
        unavailable: 'इस आउटलेट पर उपलब्ध नहीं', referral: 'रेफ़रल कोड', apply: 'कोड लागू करें',
        copy: 'कॉपी करें', save: 'सहेजें', priceChecked: 'कीमत और शुल्क की पुष्टि चेकआउट पर Bites Box करेगा।',
        addAddress: 'डिलीवरी पता जोड़ें', street: 'गली और मकान नंबर', city: 'शहर', state: 'राज्य',
        locate: 'मेरी वर्तमान लोकेशन लें', terms: 'ऑर्डर अपडेट ज़रूरी संदेश हैं। ऑफ़र आपके चुने गए विकल्पों के अनुसार आते हैं।',
        help: 'सहायता और संपर्क', closedReason: 'यह आउटलेट अभी ऑर्डर नहीं ले रहा है।',
        tagline: 'बिहार के पसंदीदा स्वाद, खास अंदाज़ में', heroTitle: 'आपकी पसंद का स्वाद।', heroDescription: 'धीमी आँच की दम बिरयानी, तंदूर के पसंदीदा व्यंजन और बिहारी स्वाद—आपके लिए ताज़ा तैयार।',
        freshPicks: 'रसोई से ताज़ा', freshPicksDescription: 'Bites Box मेन्यू के नए स्वादों से मिलें।',
        chooseYourMood: 'आज क्या खाने का मन है?', chooseYourMoodDescription: 'दम बिरयानी से लेकर कुछ मीठा तक, हर पसंद के लिए एक स्वाद।',
        featuredDish: 'Bites Box की खास पेशकश', exploreFullMenu: 'पूरा मेन्यू देखें', seeOffers: 'आज के ऑफ़र देखें',
        curatedCount: 'चुने हुए व्यंजन', freshlyPrepared: 'ध्यान से तैयार', regionalFlavours: 'बिहार के स्वाद',
        moodEyebrow: 'आपकी पसंद के लिए', freshEyebrow: 'नया स्वाद', heroCareLabel: 'प्यार से तैयार', heroCareSub: 'हमारी रसोई से आपकी मेज़ तक',
        prepTime: 'तैयारी का समय', servesLabel: 'परोसने की मात्रा', spiceLevel: 'तीखापन', calorieEstimate: 'लगभग कैलोरी', containsAllergens: 'एलर्जी की जानकारी', dietaryInfo: 'आहार',
        dishes: 'व्यंजन', all: 'सभी', vegetarian: 'शाकाहारी', nonVeg: 'मांसाहारी', egg: 'अंडे वाला', vegan: 'वीगन',
        mild: 'कम तीखा', medium: 'मध्यम तीखा', hot: 'तीखा', extraHot: 'बहुत तीखा', favouriteDish: 'बाइट्स बॉक्स का पसंदीदा',
        browseMenu: 'मेन्यू देखें', selectedOutlet: 'चुना हुआ आउटलेट', noOutlets: 'अभी कोई सक्रिय Bites Box आउटलेट उपलब्ध नहीं है।',
        outletChanged: 'आउटलेट बदल गया। हर आउटलेट का कार्ट और उपलब्धता अलग रहती है।',
        guestCart: 'आपका कार्ट इस डिवाइस पर सहेजा है। कीमत और डिलीवरी उपलब्धता जाँचने के लिए फ़ोन से साइन इन करें।',
        savedCartTitle: 'इस डिवाइस पर सहेजे आइटम', savedCartDescription: 'इन आइटम को अपने खाते के कार्ट में जोड़ें। Bites Box उपलब्धता और मौजूदा कीमत फिर जाँचेगा।',
        importSavedCart: 'सहेजे आइटम मेरे कार्ट में जोड़ें',
        emptyCart: 'आपका कार्ट खाली है।', orderUpdates: 'ऑर्डर के अपडेट', optionalOffers: 'वैकल्पिक ऑफ़र',
        enterPhone: 'अपने खाते से जुड़ा फ़ोन नंबर दर्ज करें।', otpSent: 'यदि यह नंबर साइन इन कर सकता है, तो सत्यापन कोड भेजा गया है।',
        invalidPhone: 'देश कोड सहित सही फ़ोन नंबर दर्ज करें।', invalidCode: 'फ़ोन पर भेजा गया कोड दर्ज करें।',
        referralApplied: 'रेफ़रल कोड लागू हो गया।', referralInvalid: 'यह रेफ़रल कोड इस खाते पर लागू नहीं हो सकता।',
        signInRequired: 'जारी रखने के लिए फ़ोन से साइन इन करें।', continueCheckout: 'सुरक्षित चेकआउट जारी रखें',
        orderTracking: 'ऑर्डर ट्रैकिंग', orderNotFound: 'ऑर्डर नहीं मिला। ऑर्डर वाले खाते से साइन इन करें।',
        loading: 'लोड हो रहा है…', retry: 'फिर कोशिश करें', unavailableItem: 'यह व्यंजन चुने हुए आउटलेट पर उपलब्ध नहीं है।',
        chooseOptions: 'विकल्प चुनें', quantity: 'मात्रा', specialInstructions: 'खास निर्देश (वैकल्पिक)',
        deliveryMode: 'ऑर्डर का तरीका', contactHelp: 'सहायता से संपर्क करें', helpText: 'मौजूदा ऑर्डर की सहायता के लिए साइन इन करके ऑर्डर विवरण खोलें।',
        noResults: 'कोई परिणाम नहीं मिला।', resultsFor: 'खोज परिणाम', category: 'श्रेणी', status: 'स्थिति',
        paymentFailed: 'भुगतान सत्यापित नहीं हुआ। दोबारा कोशिश करने से पहले ऑर्डर की स्थिति देखें।',
        paymentPending: 'भुगतान की पुष्टि बाकी है। जाँच के दौरान आपका ऑर्डर सुरक्षित रहेगा।',
        addressLine: 'पता', area: 'इलाका / मोहल्ला', postalCode: 'पिन कोड', latitude: 'अक्षांश', longitude: 'देशांतर',
        useLocation: 'डिवाइस की लोकेशन लें', outOfAreaMessage: 'चुने हुए आउटलेट से यहाँ डिलीवरी उपलब्ध नहीं है। आउटलेट पर सुविधा हो तो पिकअप चुनें।',
        outletOpen: 'ऑर्डर लिए जा रहे हैं', outletClosed: 'अभी ऑर्डर नहीं लिए जा रहे', pickupUnavailable: 'इस आउटलेट पर पिकअप उपलब्ध नहीं है।',
        applyCoupon: 'कूपन लागू करें', couponCode: 'कूपन कोड', remove: 'हटाएँ', subtotal: 'आइटम', discount: 'छूट',
        tax: 'टैक्स', deliveryFee: 'डिलीवरी शुल्क', total: 'कुल', wallet: 'वॉलेट बैलेंस उपयोग करें', paymentMethod: 'भुगतान का तरीका',
        onlinePayment: 'ऑनलाइन भुगतान', cashPayment: 'डिलीवरी पर नकद', paymentDisclaimer: 'चेकआउट के बाद Bites Box और Razorpay भुगतान की पुष्टि करते हैं।',
        orderNumber: 'ऑर्डर नंबर', currentStatus: 'अभी की स्थिति', backMenu: 'मेन्यू पर जाएँ', signOut: 'साइन आउट',
        referralShare: 'अपना रेफ़रल कोड साझा करें', referralTerms: 'इनाम तभी मिलेगा जब मालिक प्रोग्राम की शर्तें तय करके चालू करेगा।',
        referralInactive: 'रेफ़रल आमंत्रण अभी चालू नहीं हैं। प्रोग्राम शुरू होने पर फिर देखें।',
        referralRewardsTitle: 'इनाम कैसे मिलेंगे', youEarn: 'आपको मिलेगा', friendEarns: 'आपके दोस्त को मिलेगा', minimumOrder: 'कम से कम इतने रुपये के ऑर्डर पर', rewardExpiry: 'इनाम की समय-सीमा', days: 'दिन',
        yourInvites: 'आपके आमंत्रण', noInvites: 'अभी कोई आमंत्रण नहीं है।', invite: 'आमंत्रण',
        statusAttributed: 'आमंत्रित', statusQualified: 'पहला योग्य ऑर्डर हुआ', statusRewarded: 'इनाम वॉलेट में आया', statusReversed: 'इनाम वापस लिया गया',
        invited: 'आमंत्रित', rewarded: 'इनाम मिला', unavailableProduct: 'यह व्यंजन अभी इस आउटलेट पर उपलब्ध नहीं है।',
        privacyMessage: 'डिलीवरी कवरेज जाँचने के लिए लोकेशन केवल आपकी अनुमति के बाद उपयोग होती है।',
        locationError: 'लोकेशन जाँची नहीं जा सकी। निर्देशांक दर्ज करें या पिकअप चुनें।',
        currentOutletCart: 'हर आउटलेट का अलग कार्ट है। बदलने पर उस आउटलेट का सहेजा कार्ट खुलेगा।',
        tastePassport: 'टेस्ट पासपोर्ट',
        tastePassportDescription: 'मेन्यू के सुझावों के लिए वैकल्पिक पसंद। आप इन्हें कभी भी बदल सकते हैं।',
        tastePassportDisclaimer: 'ये विकल्प एलर्जी या चिकित्सा सलाह नहीं हैं। आहार संबंधी चिंता हो तो आइटम की जानकारी जाँचें।',
        foodTypes: 'खाने के प्रकार', maximumSpice: 'तीखेपन की अधिकतम मात्रा', anyLevel: 'कोई भी स्तर', noSpice: 'बिना तीखा',
        favoriteCategories: 'पसंदीदा श्रेणियाँ', optionalPriceCeiling: 'आइटम की अधिकतम कीमत (वैकल्पिक)',
        tasteCategoriesUnavailable: 'मेन्यू की श्रेणियाँ अभी उपलब्ध नहीं हैं।',
        leaveBlankPrice: 'किसी भी कीमत के लिए खाली छोड़ें।', saveTastePassport: 'टेस्ट पासपोर्ट सहेजें',
        tasteSaved: 'टेस्ट पासपोर्ट सहेज लिया गया।', tasteSaveError: 'स्वाद की पसंद सहेजी नहीं जा सकी। फिर कोशिश करें।',
        tasteSetupTitle: 'अपना टेस्ट पासपोर्ट बनाएँ', tasteSetupDescription: 'बेहतर सुझावों के लिए अपनी कुछ पसंद चुनें।',
        priceCeilingInvalid: 'आइटम की कीमत ₹1 से ₹100,000 के बीच दर्ज करें।', chooseUpTo20Categories: 'अधिकतम 20 श्रेणियाँ चुनें।',
    },
} as const;

export function localeFrom(value?: string | null): Locale {
    return value === 'hi' ? 'hi' : 'en';
}

export function tasteReasonLabel(code: string | undefined, locale: Locale): string {
    const copy = {
        FAVORITE_CATEGORY: { en: 'From a category you like', hi: 'आपकी पसंद की श्रेणी से' },
        ORDERED_BEFORE: { en: 'You ordered this before', hi: 'आपने इसे पहले ऑर्डर किया था' },
        SAVED_FAVORITE: { en: 'You saved this', hi: 'आपने इसे पसंदीदा में रखा' },
        POSITIVE_REVIEW: { en: 'You rated this highly', hi: 'आपने इसे अच्छी रेटिंग दी' },
        MILD_SPICE: { en: 'Mild spice', hi: 'हल्का तीखापन' },
        FOOD_TYPE_MATCH: { en: 'Matches a food type you chose', hi: 'आपकी चुनी हुई खाने की श्रेणी से मेल खाता है' },
        POPULAR_AT_OUTLET: { en: 'Popular at this outlet', hi: 'इस आउटलेट पर लोकप्रिय' },
        POPULAR_MENU_PICK: { en: 'Popular on our menu', hi: 'हमारे मेन्यू में लोकप्रिय' },
        CURATED_MENU_PICK: { en: 'Picked for our menu', hi: 'हमारे मेन्यू से चुना गया' },
        CUSTOMER_RATED_MENU_PICK: { en: 'Customer-rated dish', hi: 'ग्राहकों द्वारा रेट किया गया व्यंजन' },
        TASTE_PROFILE_MATCH: { en: 'Matches your taste profile', hi: 'आपकी पसंद से मेल खाता है' },
    } as const;
    const reason = copy[code as keyof typeof copy] ?? copy.TASTE_PROFILE_MATCH;
    return reason[locale];
}
