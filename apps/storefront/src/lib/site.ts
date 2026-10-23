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
        tagline: 'Bihar favourites', heroTitle: 'Food made for your cravings.', heroDescription: 'Browse the menu, select an outlet and see current availability before checkout.',
        dishes: 'dishes', all: 'All', vegetarian: 'Vegetarian', favouriteDish: 'Bites Box favourite',
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
        invited: 'invited', rewarded: 'rewarded', unavailableProduct: 'This dish is currently unavailable at this outlet.',
        privacyMessage: 'We use your location only after you choose to share it to check delivery coverage.',
        locationError: 'Location could not be checked. Enter coordinates or choose pickup.',
        currentOutletCart: 'Each outlet has its own cart. Switching outlets returns to that outlet’s saved cart.',
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
        tagline: 'बिहार के पसंदीदा स्वाद', heroTitle: 'आपकी पसंद का स्वाद।', heroDescription: 'मेन्यू देखें, आउटलेट चुनें और चेकआउट से पहले उपलब्धता जानें।',
        dishes: 'व्यंजन', all: 'सभी', vegetarian: 'शाकाहारी', favouriteDish: 'बाइट्स बॉक्स का पसंदीदा',
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
        invited: 'आमंत्रित', rewarded: 'इनाम मिला', unavailableProduct: 'यह व्यंजन अभी इस आउटलेट पर उपलब्ध नहीं है।',
        privacyMessage: 'डिलीवरी कवरेज जाँचने के लिए लोकेशन केवल आपकी अनुमति के बाद उपयोग होती है।',
        locationError: 'लोकेशन जाँची नहीं जा सकी। निर्देशांक दर्ज करें या पिकअप चुनें।',
        currentOutletCart: 'हर आउटलेट का अलग कार्ट है। बदलने पर उस आउटलेट का सहेजा कार्ट खुलेगा।',
    },
} as const;

export function localeFrom(value?: string | null): Locale {
    return value === 'hi' ? 'hi' : 'en';
}
