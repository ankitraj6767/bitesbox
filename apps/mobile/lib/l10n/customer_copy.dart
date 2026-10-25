import 'package:flutter/widgets.dart';

/// Translates customer copy that is produced by widgets or API state rather
/// than by a generated ARB message. The selected locale is read at call time,
/// so changing the profile language updates every rebuilt customer surface.
extension CustomerCopy on BuildContext {
  String customerText(String source, {Map<String, Object?> values = const {}}) {
    final isHindi = Localizations.localeOf(this).languageCode == 'hi';
    var result = isHindi
        ? _hindi[source] ??
              _translateCompound(source) ??
              _translatePattern(source)
        : source;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
    }
    return result;
  }

  String customerErrorText(String code, String fallback) {
    if (Localizations.localeOf(this).languageCode != 'hi') return fallback;
    return _hindiErrors[code] ?? customerText(fallback);
  }
}

String? _translateCompound(String source) {
  for (final separator in const [' · ', ', ']) {
    if (!source.contains(separator)) continue;
    final parts = source.split(separator);
    final translated = <String>[];
    for (final part in parts) {
      final value = _hindi[part] ?? _translatePattern(part);
      if (value == part) return null;
      translated.add(value);
    }
    return translated.join(separator);
  }
  return null;
}

String _translatePattern(String source) {
  final duration = RegExp(r'^(\d+) min$').firstMatch(source);
  if (duration != null) return '${duration.group(1)} मिनट';

  final calories = RegExp(r'^(\d+) kcal$').firstMatch(source);
  if (calories != null) return '${calories.group(1)} किलो कैलोरी';

  final serves = RegExp(r'^Serves (\d+)$').firstMatch(source);
  if (serves != null) return '${serves.group(1)} लोगों के लिए';

  final people = RegExp(r'^(\d+) people$').firstMatch(source);
  if (people != null) return '${people.group(1)} लोग';

  final requiredPick = RegExp(r'^Required · pick (\d+)$').firstMatch(source);
  if (requiredPick != null) {
    return 'अनिवार्य · ${requiredPick.group(1)} चुनें';
  }

  final pick = RegExp(r'^Pick (\d+)$').firstMatch(source);
  if (pick != null) return '${pick.group(1)} चुनें';

  final pickUpTo = RegExp(r'^Pick up to (\d+)$').firstMatch(source);
  if (pickUpTo != null) return 'अधिकतम ${pickUpTo.group(1)} चुनें';

  final minutesAgo = RegExp(r'^(\d+) min ago$').firstMatch(source);
  if (minutesAgo != null) return '${minutesAgo.group(1)} मिनट पहले';

  final hoursAgo = RegExp(r'^(\d+) h ago$').firstMatch(source);
  if (hoursAgo != null) return '${hoursAgo.group(1)} घंटे पहले';

  final daysAgo = RegExp(r'^(\d+) d ago$').firstMatch(source);
  if (daysAgo != null) return '${daysAgo.group(1)} दिन पहले';

  final percentOff = RegExp(
    r'^(\d+)% OFF$',
    caseSensitive: false,
  ).firstMatch(source);
  if (percentOff != null) return '${percentOff.group(1)}% छूट';

  final amountOff = RegExp(r'^₹(\d+) OFF$').firstMatch(source);
  if (amountOff != null) return '₹${amountOff.group(1)} की छूट';

  final inMinutes = RegExp(r'^in (\d+) min$').firstMatch(source);
  if (inMinutes != null) return '${inMinutes.group(1)} मिनट में';

  final moreItems = RegExp(r'^(.+) \+(\d+) more$').firstMatch(source);
  if (moreItems != null) {
    final name = _hindi[moreItems.group(1)!] ?? moreItems.group(1)!;
    return '$name +${moreItems.group(2)} और';
  }

  final itemCount = RegExp(r'^(\d+) items?$').firstMatch(source);
  if (itemCount != null) return '${itemCount.group(1)} आइटम';

  final boxCount = RegExp(r'^(\d+) in your box$').firstMatch(source);
  if (boxCount != null) return 'आपके बॉक्स में ${boxCount.group(1)}';

  final cartCount = RegExp(r'^(\d+) in cart$').firstMatch(source);
  if (cartCount != null) return 'कार्ट में ${cartCount.group(1)}';

  return source;
}

const Map<String, String> _hindi = {
  'Sign in to Bites Box': 'Bites Box में साइन इन करें',
  'Sign in': 'साइन इन करें',
  'Send code': 'कोड भेजें',
  'Support': 'सहायता',
  'Email': 'ईमेल',
  'Email (optional)': 'ईमेल (ज़रूरी नहीं)',
  'We will email your bill and order updates.':
      'हम आपको बिल और ऑर्डर की जानकारी ईमेल करेंगे।',
  'Save addresses, track orders and collect rewards.':
      'पते सहेजें, ऑर्डर ट्रैक करें और रिवॉर्ड पाएँ।',
  'Apply as a delivery partner': 'डिलीवरी पार्टनर बनने के लिए आवेदन करें',
  'Ordering': 'ऑर्डर',
  'Delivery addresses': 'डिलीवरी के पते',
  'Offers and coupons': 'ऑफ़र और कूपन',
  'Notifications': 'सूचनाएँ',
  'Help': 'सहायता',
  'Help and support': 'मदद और सहायता',
  'Call the restaurant': 'रेस्टोरेंट को कॉल करें',
  'Customer': 'ग्राहक',
  'Delivery Partner': 'डिलीवरी पार्टनर',
  'Kitchen': 'किचन',
  'Manager': 'मैनेजर',
  'Administrator': 'एडमिनिस्ट्रेटर',
  'WhatsApp us': 'हमें WhatsApp करें',
  'Information': 'जानकारी',
  'Policies and terms': 'नीतियाँ और शर्तें',
  'Frequently asked questions': 'अक्सर पूछे जाने वाले सवाल',
  'Staff': 'कर्मचारी',
  'Open the kitchen board': 'किचन बोर्ड खोलें',
  'Open my deliveries': 'मेरी डिलीवरी खोलें',
  'Sign out': 'साइन आउट',
  'Sign out?': 'साइन आउट करें?',
  'You will need your mobile number to sign back in.':
      'दोबारा साइन इन करने के लिए आपके मोबाइल नंबर की ज़रूरत होगी।',
  'Turn on location services to pin your address.':
      'पते को मानचित्र पर रखने के लिए लोकेशन सेवा चालू करें।',
  'Edit address': 'पता संपादित करें',
  'Add address': 'पता जोड़ें',
  'House / flat / building *': 'मकान / फ़्लैट / इमारत *',
  'Street / road': 'सड़क / मार्ग',
  'Landmark': 'पहचान की जगह',
  'Helps the delivery partner find you faster':
      'इससे डिलीवरी पार्टनर आपको जल्दी ढूँढ़ पाएँगे',
  'Area / locality': 'इलाका / मोहल्ला',
  'City *': 'शहर *',
  'PIN code': 'पिन कोड',
  'State *': 'राज्य *',
  'Contact name': 'संपर्क का नाम',
  'Leave blank to use your own name': 'खाली छोड़ें तो आपका नाम इस्तेमाल होगा',
  'Contact number': 'संपर्क नंबर',
  'Delivery instructions': 'डिलीवरी के निर्देश',
  'Ring the bell twice, leave at the gate…':
      'दो बार घंटी बजाएँ, गेट पर रख दें…',
  'Make this my default address': 'इसे मेरा डिफ़ॉल्ट पता बनाएँ',
  'Saving…': 'सहेजा जा रहा है…',
  'Save address': 'पता सहेजें',
  'Locating…': 'लोकेशन ढूँढ़ी जा रही है…',
  'Update': 'अपडेट करें',
  'Use GPS': 'GPS इस्तेमाल करें',
  'Zone': 'ज़ोन',
  'Distance': 'दूरी',
  'Typical time': 'आमतौर पर लगने वाला समय',
  'Delivery fee': 'डिलीवरी शुल्क',
  'Minimum order': 'न्यूनतम ऑर्डर',
  'No saved addresses': 'कोई सहेजा हुआ पता नहीं',
  'Add where you would like your food delivered.':
      'वह पता जोड़ें जहाँ खाना पहुँचाना है।',
  'Add an address': 'पता जोड़ें',
  'Default': 'डिफ़ॉल्ट',
  'Selected': 'चुना हुआ',
  'We do not deliver here yet. Self pickup is still available.':
      'अभी यहाँ डिलीवरी उपलब्ध नहीं है। आप आकर ऑर्डर ले सकते हैं।',
  'Edit': 'संपादित करें',
  'Delete': 'हटाएँ',
  'Delete this address?': 'यह पता हटाएँ?',
  'Address deleted.': 'पता हटा दिया गया।',
  'Cancel this order?': 'यह ऑर्डर रद्द करें?',
  'Your order has been cancelled.': 'आपका ऑर्डर रद्द कर दिया गया है।',
  'Cannot cancel': 'रद्द नहीं किया जा सकता',
  'Got it': 'समझ गया',
  'Cancel your order': 'अपना ऑर्डर रद्द करें',
  'Tell us why so we can do better.':
      'बताएँ कि ऐसा क्यों हुआ, ताकि हम बेहतर सेवा दे सकें।',
  'Anything else we should know? (optional)':
      'क्या आप कुछ और बताना चाहेंगे? (ज़रूरी नहीं)',
  'Keep order': 'ऑर्डर जारी रखें',
  'Cancelling…': 'रद्द किया जा रहा है…',
  'Cancel order': 'ऑर्डर रद्द करें',
  'No policies published': 'अभी कोई नीति प्रकाशित नहीं है',
  'Please check back shortly.': 'कृपया थोड़ी देर बाद फिर देखें।',
  'No FAQs published': 'अभी कोई सवाल-जवाब प्रकाशित नहीं है',
  'That coupon was not applied.': 'यह कूपन लागू नहीं हुआ।',
  'Offers for you': 'आपके लिए ऑफ़र',
  'Only one coupon can be used per order.':
      'हर ऑर्डर पर केवल एक कूपन इस्तेमाल किया जा सकता है।',
  'Enter a coupon code': 'कूपन कोड दर्ज करें',
  'Apply': 'लागू करें',
  'No offers right now': 'अभी कोई ऑफ़र नहीं है',
  'New offers are added regularly. Do check back.':
      'नए ऑफ़र आते रहते हैं। बाद में फिर देखें।',
  'Applying…': 'लागू किया जा रहा है…',
  'Group code copied': 'ग्रुप कोड कॉपी हो गया',
  'Your group': 'आपका ग्रुप',
  'Your items will stay in your own cart and will not be added to the group.':
      'आपके आइटम आपकी कार्ट में ही रहेंगे और ग्रुप में नहीं जुड़ेंगे।',
  'Everyone will leave the group. Their separate carts will stay untouched.':
      'ग्रुप बंद होने पर सभी सदस्य बाहर हो जाएँगे। उनकी अलग कार्ट पर असर नहीं पड़ेगा।',
  'Leave this group order?': 'इस ग्रुप ऑर्डर से निकलें?',
  'Stay': 'रुकें',
  'Leave group': 'ग्रुप से निकलें',
  'Close this group order?': 'यह ग्रुप ऑर्डर बंद करें?',
  'Keep it open': 'इसे खुला रखें',
  'Close group': 'ग्रुप बंद करें',
  'Group order': 'ग्रुप ऑर्डर',
  'Order together': 'मिलकर ऑर्डर करें',
  'Sign in to start a group': 'ग्रुप शुरू करने के लिए साइन इन करें',
  'Start a group order': 'ग्रुप ऑर्डर शुरू करें',
  'Group code': 'ग्रुप कोड',
  'Paste the code from your host': 'होस्ट से मिला कोड यहाँ डालें',
  'Join group order': 'ग्रुप ऑर्डर में शामिल हों',
  '{count} people': '{count} लोग',
  'Browse the menu': 'मेन्यू देखें',
  'Add something from the menu': 'मेन्यू से कुछ जोड़ें',
  'Ask the host to share the invite code.':
      'होस्ट से आमंत्रण कोड साझा करने को कहें।',
  'Copy group code': 'ग्रुप कोड कॉपी करें',
  'Nothing here yet': 'अभी यहाँ कुछ नहीं है',
  'Loading saved delivery address': 'सहेजा हुआ डिलीवरी पता लोड हो रहा है',
  'Browse by craving': 'अपनी पसंद के अनुसार देखें',
  'Our menu is being set up. Please check back shortly.':
      'हमारा मेन्यू तैयार हो रहा है। थोड़ी देर बाद फिर देखें।',
  'All dishes': 'सभी व्यंजन',
  'All': 'सभी',
  'Vegetarian': 'शाकाहारी',
  'Non-veg': 'मांसाहारी',
  'Bestsellers': 'सबसे ज़्यादा पसंद किए गए',
  'Taste Passport': 'टेस्ट पासपोर्ट',
  'Optional choices for menu recommendations. You can change them any time.':
      'मेन्यू के सुझावों के लिए वैकल्पिक पसंद। आप इन्हें कभी भी बदल सकते हैं।',
  'These choices are not allergy or medical advice. Check item details if you have a dietary concern.':
      'ये विकल्प एलर्जी या चिकित्सा सलाह नहीं हैं। आहार संबंधी चिंता हो तो आइटम की जानकारी जाँचें।',
  'Choose up to 20 categories.': 'अधिकतम 20 श्रेणियाँ चुनें।',
  'Food types': 'खाने के प्रकार',
  'Contains egg': 'अंडे वाला',
  'Maximum spice level': 'तीखेपन की अधिकतम मात्रा',
  'Any level': 'कोई भी स्तर',
  'No spice': 'बिना तीखा',
  'Extra hot': 'बहुत तीखा',
  'Favorite categories': 'पसंदीदा श्रेणियाँ',
  'Menu categories are not available right now.':
      'मेन्यू की श्रेणियाँ अभी उपलब्ध नहीं हैं।',
  'Optional item price ceiling': 'आइटम की अधिकतम कीमत (वैकल्पिक)',
  'Leave blank for any price.': 'किसी भी कीमत के लिए खाली छोड़ें।',
  'Save Taste Passport': 'टेस्ट पासपोर्ट सहेजें',
  'Taste preferences could not be loaded.': 'स्वाद की पसंद लोड नहीं हो सकी।',
  'Enter a valid item price ceiling.': 'आइटम की सही अधिकतम कीमत दर्ज करें।',
  'Taste Passport saved.': 'टेस्ट पासपोर्ट सहेज लिया गया।',
  'From a category you like': 'आपकी पसंद की श्रेणी से',
  'You ordered this before': 'आपने इसे पहले ऑर्डर किया था',
  'You saved this': 'आपने इसे पसंदीदा में रखा',
  'You rated this highly': 'आपने इसे अच्छी रेटिंग दी',
  'Mild spice': 'हल्का तीखापन',
  'Matches a food type you chose':
      'आपकी चुनी हुई खाने की श्रेणी से मेल खाता है',
  'Popular at this outlet': 'इस आउटलेट पर लोकप्रिय',
  'Popular on our menu': 'हमारे मेन्यू में लोकप्रिय',
  'Picked for our menu': 'हमारे मेन्यू से चुना गया',
  'Customer-rated dish': 'ग्राहकों द्वारा रेट किया गया व्यंजन',
  'Matches your taste profile': 'आपकी पसंद से मेल खाता है',
  'Set up your Taste Passport': 'अपना टेस्ट पासपोर्ट बनाएँ',
  'Choose a few preferences to get more relevant picks.':
      'बेहतर सुझावों के लिए अपनी कुछ पसंद चुनें।',
  'Available now': 'अभी उपलब्ध',
  'Clear all': 'सब हटाएँ',
  'Close filters': 'फ़िल्टर बंद करें',
  'YOUR PREFERENCES': 'आपकी पसंद',
  'Non-vegetarian': 'मांसाहारी',
  'SORT YOUR MENU': 'मेन्यू क्रमबद्ध करें',
  'Recommended': 'आपके लिए सुझाव',
  'Sort': 'क्रम',
  'Popular': 'लोकप्रिय',
  'Price': 'कीमत',
  'Popular choices': 'लोकप्रिय विकल्प',
  'Top rated': 'सबसे अच्छी रेटिंग',
  'Price: low to high': 'कीमत: कम से ज़्यादा',
  'A little something for every mood': 'हर पसंद और हर मन के लिए कुछ खास',
  'Only plant-forward and vegetarian dishes': 'केवल शाकाहारी व्यंजन दिखाएँ',
  'Show dishes with meat or seafood': 'मांस या समुद्री भोजन वाले व्यंजन दिखाएँ',
  'Guest favourites from the menu': 'ग्राहकों के पसंदीदा व्यंजन',
  'Hide dishes that are temporarily unavailable':
      'अभी उपलब्ध नहीं व्यंजन छिपाएँ',
  'A balanced mix of the menu': 'मेन्यू के लोकप्रिय और खास व्यंजनों का मेल',
  'Bestsellers and highly rated dishes first':
      'पहले सबसे ज़्यादा पसंद और अच्छी रेटिंग वाले व्यंजन',
  'Highest customer ratings first': 'सबसे अच्छी ग्राहक रेटिंग पहले',
  'Start with the lighter spend': 'कम कीमत वाले व्यंजनों से शुरुआत करें',
  'Mark all as read': 'सभी को पढ़ा हुआ करें',
  'No notifications': 'कोई सूचना नहीं',
  'Order updates and offers will appear here.':
      'ऑर्डर की जानकारी और ऑफ़र यहाँ दिखाई देंगे।',
  'Add items to use this': 'इस्तेमाल करने के लिए आइटम जोड़ें',
  'That coupon could not be applied to your cart.':
      'यह कूपन आपकी कार्ट पर लागू नहीं हो सका।',
  'This offer does not apply to your cart.':
      'यह ऑफ़र आपकी कार्ट पर लागू नहीं होता।',
  'Your order': 'आपका ऑर्डर',
  'Refresh': 'रीफ़्रेश करें',
  'This order is running a little late. We are sorry about the wait.':
      'आपका ऑर्डर थोड़ा देर से पहुँच रहा है। इंतज़ार के लिए हमें खेद है।',
  'Payment confirmed. Your order is on its way.':
      'भुगतान की पुष्टि हो गई। आपका ऑर्डर रास्ते में है।',
  'Last location update {time}': 'लोकेशन आख़िरी बार {time} पर अपडेट हुई',
  'Location last updated {time}. This point may be out of date.':
      'लोकेशन {time} पर अपडेट हुई थी। यह जगह पुरानी हो सकती है।',
  'Your address': 'आपका पता',
  'Call the delivery partner': 'डिलीवरी पार्टनर को कॉल करें',
  'View on map': 'मानचित्र पर देखें',
  'Delivery address': 'डिलीवरी का पता',
  'Collect from': 'यहाँ से लें',
  'Call the outlet': 'आउटलेट को कॉल करें',
  'Payment': 'भुगतान',
  'Cancel this order': 'यह ऑर्डर रद्द करें',
  'Rate this order': 'इस ऑर्डर को रेट करें',
  'Order this again': 'यह ऑर्डर फिर से करें',
  'I need help with this order': 'मुझे इस ऑर्डर में मदद चाहिए',
  'Sign in to see your orders': 'अपने ऑर्डर देखने के लिए साइन इन करें',
  'Your order history and live tracking live in your account.':
      'आपके खाते में ऑर्डर का इतिहास और लाइव ट्रैकिंग उपलब्ध है।',
  'Your orders': 'आपके ऑर्डर',
  'No live orders': 'अभी कोई चालू ऑर्डर नहीं',
  'No past orders yet': 'अभी तक कोई पुराना ऑर्डर नहीं',
  'You have no orders in progress.': 'आपका कोई ऑर्डर अभी जारी नहीं है।',
  'Your completed orders will appear here.':
      'आपके पूरे हुए ऑर्डर यहाँ दिखाई देंगे।',
  'When you place an order you can follow it here, step by step.':
      'ऑर्डर देने के बाद आप उसे यहाँ हर चरण में ट्रैक कर सकते हैं।',
  'Finish payment': 'भुगतान पूरा करें',
  'Rate order': 'ऑर्डर को रेट करें',
  'Reorder': 'फिर से ऑर्डर करें',
  'Added back to your cart.': 'आइटम आपकी कार्ट में फिर से जोड़ दिया गया।',
  '{name} added to your cart.': '{name} आपकी कार्ट में जोड़ दिया गया।',
  'We have sent a new code.': 'नया कोड भेज दिया गया है।',
  'Verify and continue': 'पुष्टि करके आगे बढ़ें',
  'Sending…': 'भेजा जा रहा है…',
  'Resend code': 'कोड दोबारा भेजें',
  'Change number': 'नंबर बदलें',
  'Dish': 'व्यंजन',
  'Choose options': 'विकल्प चुनें',
  'Please enter your name.': 'कृपया अपना नाम दर्ज करें।',
  'Profile updated.': 'प्रोफ़ाइल अपडेट हो गई।',
  'Your profile could not be loaded.': 'आपकी प्रोफ़ाइल लोड नहीं हो सकी।',
  'Sign in to view your profile.': 'अपनी प्रोफ़ाइल देखने के लिए साइन इन करें।',
  'Full name': 'पूरा नाम',
  'Used for bills and order receipts':
      'बिल और ऑर्डर की रसीद के लिए इस्तेमाल होगा',
  'Mobile number': 'मोबाइल नंबर',
  'Sign in with a different number to change this':
      'इसे बदलने के लिए दूसरे नंबर से साइन इन करें',
  'Push notifications': 'पुश सूचनाएँ',
  'SMS': 'SMS',
  'WhatsApp': 'WhatsApp',
  'Send me offers and new dish alerts':
      'मुझे ऑफ़र और नए व्यंजनों की सूचना भेजें',
  'Start ordering': 'ऑर्डर करना शुरू करें',
  'Use a different number': 'दूसरा नंबर इस्तेमाल करें',
  'Please rate the food first.': 'कृपया पहले खाने को रेट करें।',
  'Thank you. Your feedback helps us improve.':
      'धन्यवाद। आपकी राय से हमें बेहतर बनने में मदद मिलती है।',
  'How was your meal?': 'आपका खाना कैसा था?',
  'Your rating goes straight to our kitchen team.':
      'आपकी रेटिंग सीधे हमारी किचन टीम तक पहुँचेगी।',
  'The food': 'खाना',
  'The delivery': 'डिलीवरी',
  'Tell us more (optional)': 'कुछ और बताएँ (ज़रूरी नहीं)',
  'Submit rating': 'रेटिंग भेजें',
  ' star': ' स्टार',
  ' stars': ' स्टार',
  'Policies': 'नीतियाँ',
  'FAQs': 'अक्सर पूछे जाने वाले सवाल',
  'Staff sign-in': 'कर्मचारी साइन इन',
  'Work email': 'काम का ईमेल',
  'Password': 'पासवर्ड',
  'Show password': 'पासवर्ड दिखाएँ',
  'Hide password': 'पासवर्ड छिपाएँ',
  'New delivery partner? Apply here':
      'डिलीवरी पार्टनर बनना चाहते हैं? यहाँ आवेदन करें',
  'No support requests': 'कोई सहायता अनुरोध नहीं',
  'If something goes wrong with an order, raise a request and we will sort it out.':
      'ऑर्डर में कोई समस्या हो तो अनुरोध भेजें, हम उसे ठीक करेंगे।',
  'New request': 'नया अनुरोध',
  'Call us': 'हमें कॉल करें',
  'Message us on WhatsApp': 'WhatsApp पर संदेश भेजें',
  'Type a message…': 'संदेश लिखें…',
  'Send': 'भेजें',
  'Request raised. We will reply shortly.':
      'अनुरोध भेज दिया गया है। हम जल्द जवाब देंगे।',
  'Category': 'श्रेणी',
  'Related order (optional)': 'संबंधित ऑर्डर (ज़रूरी नहीं)',
  'Not about a specific order': 'किसी खास ऑर्डर के बारे में नहीं',
  'Subject': 'विषय',
  'Tell us what happened': 'बताएँ कि क्या हुआ',
  'Raise request': 'अनुरोध भेजें',
  'Our team is looking into it.': 'हमारी टीम इस पर काम कर रही है।',
  'What went wrong?': 'क्या समस्या हुई?',
  'Order {number}': 'ऑर्डर {number}',
  'Describe the problem so we can put it right':
      'समस्या बताएँ, ताकि हम उसे ठीक कर सकें',
  'Send to support': 'सहायता टीम को भेजें',
  'Bites Box wallet': 'Bites Box वॉलेट',
  'Wallet is not available': 'वॉलेट अभी उपलब्ध नहीं है',
  'This feature is currently switched off.': 'यह सुविधा अभी बंद है।',
  'Contact us': 'हमसे संपर्क करें',
  'Top-ups, refunds and cashback will show up here.':
      'वॉलेट में जोड़ी गई राशि, रिफ़ंड और कैशबैक यहाँ दिखेंगे।',
  'Amount': 'राशि',
  'Enter amount': 'राशि दर्ज करें',
  'Minimum': 'न्यूनतम',
  'Maximum': 'अधिकतम',
  'Item total': 'आइटम का कुल',
  'Item discounts': 'आइटम पर छूट',
  'Offer applied': 'ऑफ़र लागू हुआ',
  'Coupon discount': 'कूपन की छूट',
  'Packaging': 'पैकेजिंग',
  'Service fee': 'सेवा शुल्क',
  'GST and charges': 'GST और अन्य शुल्क',
  'CGST': 'CGST',
  'SGST': 'SGST',
  'IGST': 'IGST',
  'Cess': 'उपकर',
  'Tip for delivery partner': 'डिलीवरी पार्टनर के लिए टिप',
  'Round off': 'राउंड ऑफ़',
  'Order total': 'ऑर्डर का कुल',
  'Paid from wallet': 'वॉलेट से भुगतान',
  'To pay now': 'अभी भुगतान करें',
  'Remove from favorites': 'पसंदीदा से हटाएँ',
  'Save to favorites': 'पसंदीदा में सहेजें',
  'Bestseller': 'सबसे ज़्यादा पसंद किया गया',
  'New': 'नया',
  'from ': 'से ',
  'ADD': 'जोड़ें',
  'Please choose {option}.': 'कृपया {option} चुनें।',
  'Less spicy, no onion…': 'कम तीखा, प्याज़ न डालें…',
  'Cooking instructions': 'खाना बनाने के निर्देश',
  'We will pass this to the kitchen. Some requests may not be possible.':
      'हम यह बात किचन तक पहुँचाएँगे। हो सकता है हर अनुरोध पूरा न हो पाए।',
  'What customers say': 'ग्राहकों की राय',
  'Free': 'मुफ़्त',
  'From': 'से',
  '{label}, {count} dishes': '{label}, {count} व्यंजन',
  'Added, but {items} could not be reordered because they are unavailable.':
      'आइटम जुड़ गए, लेकिन {items} उपलब्ध न होने के कारण दोबारा नहीं जुड़ सके।',
  'We could not reorder {items} because they are unavailable.':
      '{items} उपलब्ध न होने के कारण दोबारा ऑर्डर नहीं हो सके।',
  'Delivering to {address}.': '{address} पर डिलीवरी होगी।',
  'Sold out for today': 'आज के लिए ख़त्म',
  'Back soon': 'जल्द उपलब्ध होगा',
  'Not available right now': 'अभी उपलब्ध नहीं है',
  'Pick up to 3': 'अधिकतम 3 चुनें',
  'Contains {items}.': 'इसमें {items} है।',
  'Gluten': 'ग्लूटेन',
  'Dairy': 'डेयरी',
  'Egg': 'अंडा',
  'Nuts': 'मेवे',
  'Soy': 'सोया',
  'Vegan': 'वीगन',
  'High protein': 'ज़्यादा प्रोटीन',
  'Gluten free': 'ग्लूटेन मुक्त',
  'Mild': 'कम तीखा',
  'Medium': 'मध्यम तीखा',
  'Hot': 'तीखा',
  'None': 'नहीं',
  'Spice level': 'तीखेपन का स्तर',
  'Serves': 'लोगों के लिए',
  'Portion': 'मात्रा',
  'Style': 'तैयारी का प्रकार',
  'Size': 'आकार',
  'Required · pick 1': 'अनिवार्य · 1 चुनें',
  'Awaiting payment': 'भुगतान की प्रतीक्षा',
  'Payment failed': 'भुगतान विफल',
  'Payment confirmed': 'भुगतान की पुष्टि हुई',
  'Order placed': 'ऑर्डर दिया गया',
  'Order accepted': 'ऑर्डर स्वीकार हुआ',
  'Being prepared': 'तैयार किया जा रहा है',
  'Ready for pickup': 'पिकअप के लिए तैयार',
  'Ready': 'तैयार',
  'Delivery partner assigned': 'डिलीवरी पार्टनर मिल गया',
  'Partner at the restaurant': 'डिलीवरी पार्टनर रेस्टोरेंट पहुँच गया',
  'Picked up': 'ऑर्डर ले लिया गया',
  'On the way': 'रास्ते में',
  'Partner has arrived': 'डिलीवरी पार्टनर पहुँच गया',
  'Delivered': 'डिलीवर हो गया',
  'Completed': 'पूरा हुआ',
  'Order declined': 'ऑर्डर अस्वीकार हुआ',
  'Cancelled': 'रद्द किया गया',
  'Delivery failed': 'डिलीवरी नहीं हो सकी',
  'Refund in progress': 'रिफ़ंड जारी है',
  'Partially refunded': 'आंशिक रिफ़ंड हुआ',
  'Refunded': 'रिफ़ंड हो गया',
  'Finish the payment to send this order to our kitchen.':
      'ऑर्डर किचन तक भेजने के लिए भुगतान पूरा करें।',
  'The payment did not go through. You can retry safely.':
      'भुगतान पूरा नहीं हुआ। आप सुरक्षित रूप से फिर कोशिश कर सकते हैं।',
  'Payment received. Sending your order to the kitchen.':
      'भुगतान मिल गया। आपका ऑर्डर किचन को भेजा जा रहा है।',
  'We have your order. The kitchen is confirming it now.':
      'आपका ऑर्डर मिल गया। किचन इसकी पुष्टि कर रहा है।',
  'Our kitchen has accepted your order.':
      'किचन ने आपका ऑर्डर स्वीकार कर लिया है।',
  'Your food is being cooked fresh.': 'आपका खाना ताज़ा तैयार किया जा रहा है।',
  'Your order is packed and waiting at the counter.':
      'आपका ऑर्डर पैक होकर काउंटर पर तैयार है।',
  'Packed and waiting for a delivery partner.':
      'ऑर्डर पैक है और डिलीवरी पार्टनर का इंतज़ार है।',
  'A delivery partner is on the way to collect your order.':
      'डिलीवरी पार्टनर आपका ऑर्डर लेने आ रहा है।',
  'Your delivery partner has reached our kitchen.':
      'डिलीवरी पार्टनर हमारी किचन पहुँच गया है।',
  'Your order has left our kitchen.': 'आपका ऑर्डर किचन से निकल चुका है।',
  'Your order has been delivered.': 'आपका ऑर्डर पहुँच गया है।',
  'The restaurant could not accept your order.':
      'रेस्टोरेंट आपका ऑर्डर स्वीकार नहीं कर सका।',
  'Your order was cancelled.': 'आपका ऑर्डर रद्द कर दिया गया।',
  'We could not complete this delivery.': 'यह डिलीवरी पूरी नहीं हो सकी।',
  'Your refund is being processed.': 'आपका रिफ़ंड प्रोसेस किया जा रहा है।',
  'Some of your payment has been refunded.':
      'आपके भुगतान का कुछ हिस्सा वापस किया गया।',
  'Your payment has been refunded.': 'आपका भुगतान वापस कर दिया गया।',
  'Orders': 'ऑर्डर',
  'Order {number} · {version}': 'ऑर्डर {number} · {version}',
  '{count} loyalty points': '{count} लॉयल्टी पॉइंट',
  '{count} star': '{count} स्टार',
  '{count} stars': '{count} स्टार',
  'The payment response was incomplete. Please try again.':
      'भुगतान की जानकारी अधूरी थी। कृपया फिर से कोशिश करें।',
  'Any moment': 'बस अभी',
  'until ready': 'तैयार होने तक',
  'until arrival': 'पहुँचने तक',
  'Track': 'ट्रैक करें',
  'Coupon {code}': 'कूपन {code}',
  'Active': 'चालू',
  'Past': 'पिछले ऑर्डर',
  'Order delayed': 'मेरा ऑर्डर देर से है',
  'My order is late': 'मेरा ऑर्डर देर से है',
  'Something is missing': 'कुछ सामान नहीं आया',
  'I got the wrong item': 'मुझे गलत आइटम मिला',
  'Problem with the food': 'खाने में समस्या',
  'Payment problem': 'भुगतान में समस्या',
  'Refund question': 'रिफ़ंड से जुड़ा सवाल',
  'Delivery problem': 'डिलीवरी में समस्या',
  'Cancellation help': 'ऑर्डर रद्द करने में मदद',
  'Problem with the app': 'ऐप में समस्या',
  'Something else': 'कोई दूसरी समस्या',
  'Open': 'खुला',
  'In progress': 'जारी है',
  'Waiting on you': 'आपके जवाब का इंतज़ार',
  'Escalated': 'आगे भेजा गया',
  'Resolved': 'समस्या सुलझ गई',
  'Closed': 'बंद',
  'raised {time}': '{time} को भेजा',
  'Home': 'घर',
  'Work': 'ऑफ़िस',
  'Hotel': 'होटल',
  'Other': 'अन्य',
  '₹75 OFF': '₹75 की छूट',
  '₹150 OFF': '₹150 की छूट',
  '20% OFF': '20% की छूट',
  '10% OFF': '10% की छूट',
  '15% OFF': '15% की छूट',
  'Flat discount': 'सीधी छूट',
  'Free delivery': 'मुफ़्त डिलीवरी',
  'Percent discount': 'प्रतिशत छूट',
  'Days': 'दिन',
  'Hours': 'घंटे',
  'Minutes': 'मिनट',
  'Chicken Dum Biryani': 'चिकन दम बिरयानी',
  'Mutton Dum Biryani': 'मटन दम बिरयानी',
  'Subz Handi Biryani': 'सब्ज़ हांडी बिरयानी',
  'Egg Biryani': 'अंडा बिरयानी',
  'Tandoori Chicken': 'तंदूरी चिकन',
  'Bihari Chicken Masala': 'बिहारी चिकन मसाला',
  'Butter Chicken': 'बटर चिकन',
  'Chicken Tikka': 'चिकन टिक्का',
  'Champaran Handi Mutton': 'चंपारण हांडी मटन',
  'Mutton Curry': 'मटन करी',
  'Chicken Tikka Roll': 'चिकन टिक्का रोल',
  'Egg Chicken Roll': 'एग चिकन रोल',
  'Paneer Tikka Roll': 'पनीर टिक्का रोल',
  'Chicken Hakka Noodles': 'चिकन हक्का नूडल्स',
  'Veg Fried Rice': 'वेज फ्राइड राइस',
  'Chilli Chicken': 'चिली चिकन',
  'Veg Manchurian': 'वेज मंचूरियन',
  'Chicken Seekh Kebab': 'चिकन सीख कबाब',
  'Paneer Tikka': 'पनीर टिक्का',
  'Onion Pakoda': 'प्याज़ पकौड़ा',
  'Paneer Butter Masala': 'पनीर बटर मसाला',
  'Dal Tadka': 'दाल तड़का',
  'Aloo Chokha with Rice': 'आलू चोखा और चावल',
  'Tandoori Roti': 'तंदूरी रोटी',
  'Butter Naan': 'बटर नान',
  'Laccha Paratha': 'लच्छा पराठा',
  'Coca-Cola': 'कोका-कोला',
  'Sweet Lassi': 'मीठी लस्सी',
  'Masala Chaas': 'मसाला छाछ',
  'Packaged Drinking Water 1L': 'पैक्ड पीने का पानी 1 लीटर',
  'Gulab Jamun (2 pcs)': 'गुलाब जामुन (2 पीस)',
  'Rice Kheer': 'चावल की खीर',
  'Litti Chokha (4 pcs)': 'लिट्टी चोखा (4 पीस)',
  'Sattu Paratha (2 pcs)': 'सत्तू पराठा (2 पीस)',
  'Poori Sabzi': 'पूरी सब्ज़ी',
  'Solo Biryani Combo': 'सोलो बिरयानी कॉम्बो',
  'Family Feast Box': 'फैमिली फीस्ट बॉक्स',
  'Veg Thali Box': 'वेज थाली बॉक्स',
  'Half (Serves 1)': 'आधा (1 व्यक्ति के लिए)',
  'Full (Serves 2)': 'पूरा (2 लोगों के लिए)',
  'Family (Serves 4)': 'फैमिली (4 लोगों के लिए)',
  'Half (2 pcs)': 'आधा (2 पीस)',
  'Full (4 pcs)': 'पूरा (4 पीस)',
  'Half (Serves 2)': 'आधा (2 लोगों के लिए)',
  'Full (Serves 4)': 'पूरा (4 लोगों के लिए)',
  '6 pieces': '6 पीस',
  '12 pieces': '12 पीस',
  'Dry': 'सूखा',
  'Gravy': 'ग्रेवी वाला',
  '4 pieces': '4 पीस',
  '8 pieces': '8 पीस',
  '250 ml': '250 मिली',
  '600 ml': '600 मिली',
  '1.25 L': '1.25 लीटर',
  'Regular (300 ml)': 'रेगुलर (300 मिली)',
  'Large (500 ml)': 'लार्ज (500 मिली)',
  'Regular': 'रेगुलर',
  'Large': 'लार्ज',
  'Extra gravy': 'अतिरिक्त ग्रेवी',
  'Green salad': 'हरा सलाद',
  'Masala papad': 'मसाला पापड़',
  'Boiled egg': 'उबला अंडा',
  'Gulab jamun (2)': 'गुलाब जामुन (2)',
  'Boondi raita': 'बूंदी रायता',
  'Mirchi ka salan': 'मिर्ची का सालन',
  'Extra chicken leg': 'अतिरिक्त चिकन लेग पीस',
  'Extra mutton pieces': 'अतिरिक्त मटन पीस',
  'Extra rice portion': 'अतिरिक्त चावल',
  'Extra chicken': 'अतिरिक्त चिकन',
  'Extra cheese': 'अतिरिक्त चीज़',
  'Double egg': 'दो अंडे',
  'Extra onions': 'अतिरिक्त प्याज़',
  'No onion': 'प्याज़ न डालें',
  'No garlic': 'लहसुन न डालें',
  'No coriander': 'धनिया न डालें',
  'Less oil': 'कम तेल',
  'Tandoori roti (2)': 'तंदूरी रोटी (2)',
  'Butter naan (2)': 'बटर नान (2)',
  'Laccha paratha (1)': 'लच्छा पराठा (1)',
  'Steamed rice': 'भाप के चावल',
  'Bihari masala': 'बिहारी मसाला',
  'Butter gravy': 'मक्खन वाली ग्रेवी',
  'Kadhai style': 'कड़ाही अंदाज़',
  'Coca-Cola 250ml': 'कोका-कोला 250 मिली',
  'Sprite 250ml': 'स्प्राइट 250 मिली',
  'Fried onions': 'तले प्याज़',
  'Roasted cashew': 'भुने काजू',
  'Fresh coriander': 'ताज़ा धनिया',
  'Lemon wedge': 'नींबू की फाँक',
  'Green chutney': 'हरी चटनी',
  'Too many requests. Please try again later.':
      'बहुत ज़्यादा अनुरोध हुए। कृपया थोड़ी देर बाद फिर कोशिश करें।',
  'Sign in with your work account': 'अपने काम के खाते से साइन इन करें',
  'For kitchen, delivery and management accounts. Customers should use their mobile number instead.':
      'किचन, डिलीवरी और मैनेजमेंट खातों के लिए। ग्राहकों को अपने मोबाइल नंबर से साइन इन करना चाहिए।',
  'Forgotten your password? Ask your manager to send a reset link from the admin dashboard.':
      'पासवर्ड भूल गए? अपने मैनेजर से एडमिन डैशबोर्ड द्वारा रीसेट लिंक भेजने को कहें।',
  'Enter your mobile number and we will send you a one-time code.':
      'अपना मोबाइल नंबर दर्ज करें। हम आपको एक बार इस्तेमाल होने वाला कोड भेजेंगे।',
  'By continuing you agree to our terms of service and privacy policy.':
      'आगे बढ़कर आप हमारी सेवा की शर्तों और गोपनीयता नीति से सहमत होते हैं।',
  'Want to deliver with us? Apply as a delivery partner':
      'हमारे साथ डिलीवरी करना चाहते हैं? डिलीवरी पार्टनर बनने के लिए आवेदन करें',
  'Enter the {count}-digit code.': '{count} अंकों का कोड दर्ज करें।',
  'That code is incorrect or has expired.':
      'यह कोड गलत है या इसकी समय-सीमा समाप्त हो गई है।',
  'Enter the code': 'कोड दर्ज करें',
  'Sent to {phone}': '{phone} पर भेजा गया',
  'Resend code in {seconds}s': '{seconds} सेकंड बाद कोड दोबारा भेजें',
  'Location permission is off. You can still type your address.':
      'लोकेशन की अनुमति बंद है। आप फिर भी अपना पता लिख सकते हैं।',
  'We need to pin your location so the kitchen knows where to send your food.':
      'आपकी लोकेशन पिन करना ज़रूरी है, ताकि किचन को डिलीवरी का पता मिल सके।',
  'Address saved.': 'पता सहेज लिया गया।',
  'Address saved, but we do not deliver there yet.':
      'पता सहेज लिया गया, लेकिन वहाँ अभी डिलीवरी उपलब्ध नहीं है।',
  'Please enter the house or building': 'कृपया मकान या इमारत का पता दर्ज करें',
  'Who should we hand the order to?': 'ऑर्डर किसे सौंपना है?',
  'Location pinned': 'लोकेशन पिन हो गई',
  'Pin your location': 'अपनी लोकेशन पिन करें',
  'We use this to check whether we deliver to you.':
      'हम इसका इस्तेमाल यह जाँचने के लिए करते हैं कि आपके पते पर डिलीवरी उपलब्ध है या नहीं।',
  'We do not deliver to this location yet. You can still order for self pickup.':
      'इस जगह पर अभी डिलीवरी उपलब्ध नहीं है। आप फिर भी खुद आकर ऑर्डर ले सकते हैं।',
  'We deliver here': 'यहाँ डिलीवरी उपलब्ध है',
  'Cash on delivery is not available in this area.':
      'इस इलाके में कैश ऑन डिलीवरी उपलब्ध नहीं है।',
  'Save this address as': 'इस पते को इस नाम से सहेजें',
  'Add a delivery address': 'डिलीवरी का पता जोड़ें',
  'Sign in to set your address': 'पता जोड़ने के लिए साइन इन करें',
  'Saved address unavailable': 'सहेजा हुआ पता उपलब्ध नहीं है',
  'Choose a delivery location after sign in':
      'साइन इन करने के बाद डिलीवरी की जगह चुनें',
  'Tap to choose an address': 'पता चुनने के लिए टैप करें',
  'Tap to choose where to deliver': 'डिलीवरी की जगह चुनने के लिए टैप करें',
  'Search for biryani, litti, thali…': 'बिरयानी, लिट्टी, थाली खोजें…',
  'Hungry, {name}? Search the menu': 'भूख लगी है, {name}? मेन्यू में खोजें',
  'A table full of good things': 'आपके पसंदीदा स्वादों से भरी मेज़',
  'A little more\nto look forward to.': 'कुछ और स्वादिष्ट\nआपके इंतज़ार में।',
  'Find your kind of good': 'अपनी पसंद का स्वाद खोजें',
  'Choose what sounds right today.': 'आज जो खाने का मन हो, वह चुनें।',
  'Filter': 'फ़िल्टर',
  'Reset': 'रीसेट करें',
  'Show dishes': 'व्यंजन दिखाएँ',
  'Good food, shared better.': 'अच्छा खाना, साथ मिलकर और बेहतर।',
  'Start a group, invite your people, and let everyone add their favourites.':
      'ग्रुप शुरू करें, अपने लोगों को बुलाएँ और सभी को अपने पसंदीदा व्यंजन जोड़ने दें।',
  'This group order expired. Start a new group to order together.':
      'इस ग्रुप ऑर्डर की समय-सीमा समाप्त हो गई। साथ ऑर्डर करने के लिए नया ग्रुप शुरू करें।',
  'This group order has been closed.': 'यह ग्रुप ऑर्डर बंद हो चुका है।',
  'Waiting for items': 'आइटम का इंतज़ार है',
  'Review {count} items': '{count} आइटम देखें',
  'Share a code': 'कोड साझा करें',
  'Invite your friends to join.': 'अपने दोस्तों को शामिल होने के लिए बुलाएँ।',
  'Pick your favourites': 'अपने पसंदीदा चुनें',
  'Everyone adds to their own list.': 'हर कोई अपनी सूची में आइटम जोड़ता है।',
  'One checkout': 'एक ही चेकआउट',
  'The host reviews and places the order.': 'होस्ट ऑर्डर देखकर उसे पूरा करेगा।',
  'This code stays active for 2 hours.': 'यह कोड 2 घंटे तक सक्रिय रहेगा।',
  'Add something from the menu to get started.':
      'शुरू करने के लिए मेन्यू से कुछ जोड़ें।',
  'Choosing something tasty…': 'कुछ स्वादिष्ट चुन रहे हैं…',
  'Your group is ready': 'आपका ग्रुप तैयार है',
  'You’re in the group': 'आप ग्रुप में शामिल हैं',
  'Add a favourite and share the invite code.':
      'अपना पसंदीदा जोड़ें और आमंत्रण कोड साझा करें।',
  'Browse the menu and add your picks. The host will check out for everyone.':
      'मेन्यू देखें और अपनी पसंद जोड़ें। होस्ट सभी के लिए ऑर्डर पूरा करेगा।',
  'Almost there': 'बस एक कदम और',
  'Tell us your name so our kitchen and delivery partner know who the order is for.':
      'अपना नाम बताएँ, ताकि हमारी किचन टीम और डिलीवरी पार्टनर जान सकें कि ऑर्डर किसके लिए है।',
  'Optional offers only. Order-critical updates are separate. You can change this any time in your profile.':
      'यह केवल वैकल्पिक ऑफ़र के लिए है। ज़रूरी ऑर्डर अपडेट अलग से आते हैं। आप इसे प्रोफ़ाइल में कभी भी बदल सकते हैं।',
  'How should we reach you?': 'हम आपसे कैसे संपर्क करें?',
  'Occasional messages about discounts and additions to the menu.':
      'छूट और मेन्यू में नए व्यंजनों के बारे में कभी-कभार संदेश।',
  'Your access': 'आपकी पहुँच',
  'Bites Box customer': 'बाइट्स बॉक्स ग्राहक',
  '15% off Chinese, 3–6 PM': 'दोपहर 3–6 बजे चीनी खाने पर 15% की छूट',
  'Free delivery on orders above ₹499':
      '₹499 से ऊपर के ऑर्डर पर मुफ़्त डिलीवरी',
  '10% off desserts on Sundays': 'रविवार को मिठाइयों पर 10% की छूट',
  'Wallet balance': 'वॉलेट बैलेंस',
  'Tap to retry': 'दोबारा कोशिश करने के लिए टैप करें',
  'All notifications are already read': 'सभी सूचनाएँ पहले से पढ़ी जा चुकी हैं',
  '{count} notification marked as read': '{count} सूचना पढ़ी हुई कर दी गई',
  '{count} notifications marked as read': '{count} सूचनाएँ पढ़ी हुई कर दी गईं',
  'You will be refunded {amount}.': 'आपको {amount} वापस मिलेंगे।',
  'This cannot be undone.': 'इसे वापस नहीं किया जा सकता।',
  'Yes, cancel': 'हाँ, रद्द करें',
  'Refund: {amount}': 'रिफ़ंड: {amount}',
  'No refund applies': 'कोई रिफ़ंड लागू नहीं है',
  'Cancellation fee: {amount}': 'रद्दीकरण शुल्क: {amount}',
  'Our team will review this cancellation.':
      'हमारी टीम इस रद्दीकरण की समीक्षा करेगी।',
  'Applied. You save {amount}.': 'लागू हुआ। आपकी बचत {amount} है।',
  'Min order {amount}': 'न्यूनतम ऑर्डर {amount}',
  'Up to {amount}': '{amount} तक की छूट',
  'Till {date}': '{date} तक',
  'Apply and save {amount}': 'लागू करें और {amount} बचाएँ',
  'Apply to my cart': 'मेरी कार्ट पर लागू करें',
  'Coupon applied. You saved {amount}.': 'कूपन लागू हुआ। आपने {amount} बचाए।',
  'Saves about {amount} on this order': 'इस ऑर्डर पर लगभग {amount} की बचत',
  'Applied': 'लागू',
  'Saving {amount}': '{amount} की बचत',
  'Add {amount} more for free delivery':
      'मुफ़्त डिलीवरी के लिए {amount} और जोड़ें',
  'Add {amount} more to get free delivery on this order.':
      'इस ऑर्डर पर मुफ़्त डिलीवरी पाने के लिए {amount} और जोड़ें।',
  'from our kitchen': 'हमारी किचन से',
  '{distance} from our kitchen': 'हमारी किचन से {distance}',
  'Ready {time}': '{time} पर तैयार',
  'Arriving {time}': '{time} पर पहुँचेगा',
  'Are you sure?': 'क्या आप सुनिश्चित हैं?',
  'Payment not completed': 'भुगतान पूरा नहीं हुआ',
  'Our kitchen has not received this order yet. Pay {amount} to confirm it. You will not be charged twice.':
      'किचन को अभी आपका ऑर्डर नहीं मिला है। पुष्टि के लिए {amount} का भुगतान करें। आपसे दोबारा शुल्क नहीं लिया जाएगा।',
  'Pay {amount}': '{amount} का भुगतान करें',
  'Share your delivery OTP': 'अपना डिलीवरी OTP साझा करें',
  'Your OTP was sent by SMS. Give it to the delivery partner only when you have your order in hand.':
      'आपका OTP SMS से भेजा गया है। इसे डिलीवरी पार्टनर को तभी बताएँ जब ऑर्डर आपके हाथ में हो।',
  'about {count} min away': 'लगभग {count} मिनट दूर',
  'On the way to you': 'आपकी ओर आ रहा है',
  '{distance} away': '{distance} दूर',
  'Live location is unavailable right now.': 'अभी लाइव लोकेशन उपलब्ध नहीं है।',
  'Note: {instructions}': 'निर्देश: {instructions}',
  'We will let you know the moment it is ready.':
      'तैयार होते ही हम आपको बताएँगे।',
  'Cash collected on delivery.': 'डिलीवरी पर नकद लिया जाएगा।',
  'Please have {amount} ready.': 'कृपया {amount} तैयार रखें।',
  'Awaiting confirmation': 'पुष्टि की प्रतीक्षा',
  'Refunds': 'रिफ़ंड',
  'To your Bites Box wallet': 'आपके बाइट्स बॉक्स वॉलेट में',
  'To your original payment method': 'आपके मूल भुगतान तरीके पर',
  'Bank refunds usually appear within 5 to 7 working days.':
      'बैंक रिफ़ंड आमतौर पर 5 से 7 कार्यदिवस में दिखाई देता है।',
  'Order updates': 'ऑर्डर अपडेट',
  '{count} items': '{count} आइटम',
  '{count} item': '{count} आइटम',
  '{count} refunded': '{count} वापस किए गए',
  'Tasty': 'स्वादिष्ट',
  'What is this about?': 'आप किस बारे में बात करना चाहते हैं?',
  'INVITE YOUR PEOPLE': 'अपने लोगों को आमंत्रित करें',
  '{name} · Host': '{name} · मेज़बान',
  '{count} orders with us': 'हमारे साथ {count} ऑर्डर',
  '{amount} refunded': '{amount} का रिफंड हुआ',
  '{count} in your box': 'आपके बॉक्स में {count}',
  '{count} in cart': 'कार्ट में {count}',
  'Serves {count}': '{count} लोगों के लिए',
  'Scheduled for {time}': 'निर्धारित समय: {time}',
  'Continue · {amount}': 'आगे बढ़ें · {amount}',
  'Balance {amount}': 'बैलेंस {amount}',
  'Well packed': 'अच्छी तरह पैक था',
  'Hot and fresh': 'गरम और ताज़ा',
  'Prepared fresh in our kitchen': 'हमारी किचन में ताज़ा तैयार किया गया',
  'Quick delivery': 'तेज़ डिलीवरी',
  'Good portion': 'अच्छी मात्रा',
  'Value for money': 'पैसे वसूल',
  'Arrived cold': 'ठंडा पहुँचा',
  'Too late': 'बहुत देर हुई',
  'Spillage': 'खाना गिरा हुआ था',
  'Small portion': 'मात्रा कम थी',
  'Too salty': 'बहुत नमकीन था',
  'Not as described': 'बताए गए जैसा नहीं था',
  'Poor': 'खराब',
  'Not great': 'खास अच्छा नहीं',
  'Fine': 'ठीक-ठाक',
  'Good': 'अच्छा',
  'Excellent': 'बेहतरीन',
  'Enter a valid 10-digit mobile number.':
      'कृपया 10 अंकों का सही मोबाइल नंबर डालें।',
  'Our team will review this and decide on any refund or credit.':
      'हमारी टीम इसकी समीक्षा करके रिफंड या क्रेडिट पर निर्णय लेगी।',
  'Placed': 'ऑर्डर मिला',
  'Accepted': 'स्वीकार किया गया',
  'Preparing': 'तैयार किया जा रहा है',
  'included': 'शामिल',
  'You can pick up to {max} from {group}.':
      '{group} में से अधिकतम {max} चुनें।',
  'An item is unavailable — tap to fix':
      'एक आइटम उपलब्ध नहीं है — ठीक करने के लिए टैप करें',
  'View cart': 'कार्ट देखें',
  'In your box': 'आपके बॉक्स में',
  'Currently unavailable': 'अभी उपलब्ध नहीं',
  '{count} items in your group': 'आपके ग्रुप में {count} आइटम',
  'Bill details': 'बिल की जानकारी',
  'Why is tax added twice?': 'टैक्स दो बार क्यों जोड़ा गया है?',
  'Included': 'शामिल',
  'You saved {amount} on this order': 'इस ऑर्डर पर आपने {amount} बचाए',
  'Add money to your wallet': 'अपने वॉलेट में पैसे जोड़ें',
  'Available balance': 'उपलब्ध बैलेंस',
  'Your wallet is on hold. Please contact support.':
      'आपका वॉलेट रोक पर है। कृपया सहायता टीम से संपर्क करें।',
  'Applied to your order total automatically at checkout.':
      'चेकआउट पर यह राशि अपने आप ऑर्डर के कुल में लग जाएगी।',
  'Opening secure checkout…': 'सुरक्षित चेकआउट खुल रहा है…',
  'Add money': 'पैसे जोड़ें',
  'Secure checkout · Add ₹100–₹10,000 · Use wallet at Bites Box':
      'सुरक्षित चेकआउट · ₹100–₹10,000 जोड़ें · बाइट्स बॉक्स में वॉलेट इस्तेमाल करें',
  'While your wallet is on hold you can still pay by card, UPI or cash.':
      'वॉलेट रोक पर होने के दौरान भी आप कार्ड, UPI या नकद से भुगतान कर सकते हैं।',
  'Transactions': 'लेन-देन',
  'Payment cancelled. Your wallet was not charged.':
      'भुगतान रद्द हुआ। आपके वॉलेट से पैसे नहीं कटे।',
  'The payment could not be completed. Please try again.':
      'भुगतान पूरा नहीं हो सका। कृपया फिर कोशिश करें।',
  '{amount} added to your wallet': '{amount} आपके वॉलेट में जोड़े गए',
  'Payment is processing. Refresh your wallet shortly.':
      'भुगतान प्रोसेस हो रहा है। थोड़ी देर में वॉलेट रीफ़्रेश करें।',
  'Choose an amount within the allowed range': 'दी गई सीमा के भीतर राशि चुनें',
  'Use up to two decimal places': 'अधिकतम दो दशमलव अंक इस्तेमाल करें',
  'Choose an amount. Your balance updates after secure payment confirmation.':
      'राशि चुनें। सुरक्षित भुगतान की पुष्टि के बाद आपका बैलेंस अपडेट होगा।',
  'Quick add': 'जल्दी जोड़ें',
  'Continue': 'आगे बढ़ें',
  'Continue to payment': 'भुगतान के लिए आगे बढ़ें',
  'Payments are securely processed by Razorpay.':
      'भुगतान Razorpay द्वारा सुरक्षित रूप से प्रोसेस किए जाते हैं।',
  'This request is {status}.': 'यह अनुरोध {status} है।',
  'Raise a new one if you still need help.':
      'अगर आपको अभी भी मदद चाहिए, तो नया अनुरोध भेजें।',
  'Which items?': 'कौन-से आइटम?',
  'Something was missing': 'कुछ सामान नहीं आया',
  'My order is very late': 'मेरा ऑर्डर बहुत देर से है',
  'Problem with the delivery': 'डिलीवरी में समस्या',
  'Something is wrong with this order': 'इस ऑर्डर में कुछ समस्या है',
  'Need to speak to someone right away?':
      'क्या आप अभी किसी से बात करना चाहते हैं?',
  'Our team will reply here shortly.': 'हमारी टीम यहाँ जल्द जवाब देगी।',
  'Pay when your order arrives': 'ऑर्डर पहुँचने पर भुगतान करें',
  'Welcome back': 'वापसी पर स्वागत है',
  'Fresh food, on its way.': 'ताज़ा खाना, बस पहुँचने वाला है।',
  'Your food is on its way to you.': 'आपका खाना आपकी ओर आ रहा है।',
  'Your delivery partner is outside. Share your OTP to receive the order.':
      'डिलीवरी पार्टनर बाहर है। ऑर्डर लेने के लिए अपना OTP बताएँ।',
  'Enjoy your meal.': 'अपने खाने का आनंद लें।',
  'This order is complete.': 'यह ऑर्डर पूरा हो गया है।',
  'Our kitchen could not take this order. Any payment is refunded.':
      'हमारी किचन यह ऑर्डर नहीं ले सकी। कोई भी भुगतान वापस कर दिया जाएगा।',
  'You cancelled this order.': 'आपने यह ऑर्डर रद्द किया।',
  'This order was cancelled by our team.': 'हमारी टीम ने यह ऑर्डर रद्द किया।',
  'We could not complete the delivery. Our team will be in touch.':
      'हम डिलीवरी पूरी नहीं कर सके। हमारी टीम आपसे संपर्क करेगी।',
  'Part of this order has been refunded.':
      'इस ऑर्डर की कुछ राशि वापस कर दी गई है।',
  'This order has been fully refunded.':
      'इस ऑर्डर की पूरी राशि वापस कर दी गई है।',
  'Delivery partner is outside': 'डिलीवरी पार्टनर बाहर है',
  'CASH': 'नकद',
  'Online': 'ऑनलाइन',
  'Cash on delivery': 'कैश ऑन डिलीवरी',
  'UPI': 'UPI',
  'Card': 'कार्ड',
  'Wallet': 'वॉलेट',
  'Bank transfer': 'बैंक ट्रांसफ़र',
  'ABOUT': 'परिचय',
  'TERMS': 'शर्तें',
  'PRIVACY': 'गोपनीयता',
  'CANCELLATION POLICY': 'रद्दीकरण नीति',
  'REFUND POLICY': 'रिफ़ंड नीति',
  'DELIVERY POLICY': 'डिलीवरी नीति',
  'GENERAL': 'सामान्य',
  'ORDERING': 'ऑर्डर',
  'PAYMENT': 'भुगतान',
  'DELIVERY': 'डिलीवरी',
  'FOOD': 'खाना',
  'ACCOUNT': 'खाता',
  'THE BITES BOX MENU': 'बाइट्स बॉक्स का मेन्यू',
  'Filter {count}': 'फ़िल्टर · {count}',
  'Show dishes ({count})': '{count} व्यंजन दिखाएँ',
  '{count} dish to discover': 'देखने के लिए {count} व्यंजन',
  '{count} dishes to discover': 'देखने के लिए {count} व्यंजन',
  'Pickup': 'पिकअप',
  '{code} applied': '{code} लागू हुआ',
  'Minimum ₹{minimum} · Maximum ₹{maximum}':
      'न्यूनतम ₹{minimum} · अधिकतम ₹{maximum}',
  'Enter a valid amount': 'मान्य राशि दर्ज करें',
  'Welcome to {brand}': '{brand} में आपका स्वागत है',
  'Sent to ': 'इस नंबर पर भेजा गया: ',
  'Choose a delivery date': 'डिलीवरी की तारीख चुनें',
  'Choose a delivery time': 'डिलीवरी का समय चुनें',
  'Please choose a slot at least 30 minutes from now.':
      'कृपया अभी से कम-से-कम 30 मिनट बाद का समय चुनें।',
  'Ready to collect in {duration}': '{duration} में पिकअप के लिए तैयार',
  'Arriving in about {duration}': 'लगभग {duration} में पहुँच जाएगा',
  'Cooking takes about {prep}, delivery about {delivery}.':
      'खाना बनने में लगभग {prep} और डिलीवरी में लगभग {delivery} लगेंगे।',
  'We will let you know the moment it is packed.':
      'पैक होते ही हम आपको बताएँगे।',
  'Paid {time}': '{time} को भुगतान हुआ',
  'Menu': 'मेन्यू',
  'You are offline': 'आप ऑफ़लाइन हैं',
  'Something went wrong': 'कुछ गड़बड़ हुई',
  'You appear to be offline. Check your connection and try again.':
      'आप ऑफ़लाइन लग रहे हैं। अपना इंटरनेट जाँचकर फिर कोशिश करें।',
  'That took too long. Please try again.':
      'इसमें बहुत समय लगा। कृपया फिर कोशिश करें।',
  'Too many attempts. Please wait a moment.':
      'बहुत बार कोशिश की गई। कृपया थोड़ी देर रुकें।',
  'Please sign in to continue.': 'आगे बढ़ने के लिए साइन इन करें।',
  'You do not have permission to do that.': 'आपको यह करने की अनुमति नहीं है।',
  'Something went wrong on our side. Please try again.':
      'हमारी ओर से कुछ गड़बड़ हुई। कृपया फिर कोशिश करें।',
  'Your session has expired. Please sign in again.':
      'आपका सत्र समाप्त हो गया है। कृपया फिर से साइन इन करें।',
  'Cancel': 'रद्द करें',
  'Confirm': 'पुष्टि करें',
  'Marking…': 'पढ़ा हुआ किया जा रहा है…',
  'More': 'और',
};

const Map<String, String> _hindiErrors = {
  'UNAUTHENTICATED': 'आगे बढ़ने के लिए साइन इन करें।',
  'PERMISSION_DENIED': 'आपको यह करने की अनुमति नहीं है।',
  'ACCOUNT_BLOCKED': 'यह खाता अभी उपलब्ध नहीं है। सहायता टीम से संपर्क करें।',
  'RATE_LIMITED': 'बहुत ज़्यादा अनुरोध हुए। कृपया थोड़ी देर बाद कोशिश करें।',
  'ITEM_NOT_FOUND': 'यह व्यंजन अब मेन्यू में उपलब्ध नहीं है।',
  'ITEM_UNAVAILABLE': 'यह व्यंजन अभी उपलब्ध नहीं है।',
  'VARIANT_REQUIRED': 'कृपया व्यंजन का आकार या मात्रा चुनें।',
  'VARIANT_NOT_FOUND': 'यह विकल्प अब उपलब्ध नहीं है। कृपया दूसरा चुनें।',
  'MODIFIER_INVALID': 'चुना हुआ विकल्प मान्य नहीं है। कृपया फिर चुनें।',
  'MODIFIER_UNAVAILABLE': 'चुना हुआ अतिरिक्त विकल्प अभी उपलब्ध नहीं है।',
  'MODIFIER_SELECTION_REQUIRED': 'कृपया सभी ज़रूरी विकल्प चुनें।',
  'MODIFIER_SELECTION_EXCEEDED': 'आपने ज़रूरत से ज़्यादा विकल्प चुने हैं।',
  'QUANTITY_LIMIT_EXCEEDED':
      'आप इस व्यंजन की तय सीमा से ज़्यादा मात्रा नहीं जोड़ सकते।',
  'INVALID_QUANTITY': 'कृपया मान्य मात्रा चुनें।',
  'CART_NOT_FOUND': 'आपकी कार्ट नहीं मिली। कृपया फिर कोशिश करें।',
  'CART_EMPTY': 'आगे बढ़ने से पहले अपनी कार्ट में आइटम जोड़ें।',
  'CART_ITEM_NOT_FOUND': 'यह आइटम आपकी कार्ट में नहीं मिला।',
  'GROUP_ALREADY_ACTIVE': 'आपका एक ग्रुप ऑर्डर पहले से सक्रिय है।',
  'GROUP_ALREADY_LEFT': 'आप इस ग्रुप ऑर्डर से पहले ही निकल चुके हैं।',
  'GROUP_CART_NOT_EMPTY':
      'ग्रुप ऑर्डर में शामिल होने से पहले अपनी कार्ट खाली करें।',
  'GROUP_CLOSED': 'यह ग्रुप ऑर्डर बंद हो चुका है।',
  'GROUP_CODE_INVALID': 'यह आमंत्रण कोड मान्य नहीं है। जाँचकर फिर कोशिश करें।',
  'GROUP_HOST_CANNOT_LEAVE': 'होस्ट ग्रुप ऑर्डर से नहीं निकल सकता।',
  'GROUP_HOST_CART_CLOSED':
      'होस्ट ने ग्रुप ऑर्डर का ऑर्डर देना शुरू कर दिया है।',
  'GROUP_NOT_FOUND': 'यह ग्रुप ऑर्डर अब उपलब्ध नहीं है।',
  'CHECKOUT_INVALID': 'चेकआउट की जानकारी जाँचें और फिर कोशिश करें।',
  'MIN_ORDER_NOT_MET': 'ऑर्डर की न्यूनतम राशि पूरी नहीं हुई है।',
  'ADDRESS_REQUIRED': 'ऑर्डर देने के लिए डिलीवरी का पता चुनें।',
  'ADDRESS_NOT_FOUND': 'यह डिलीवरी पता नहीं मिला। कृपया दूसरा चुनें।',
  'ADDRESS_NOT_SERVICEABLE': 'इस पते पर डिलीवरी उपलब्ध नहीं है।',
  'OUTSIDE_MAX_DISTANCE': 'यह पता हमारी डिलीवरी सीमा से बाहर है।',
  'PICKUP_UNAVAILABLE': 'अभी सेल्फ पिकअप उपलब्ध नहीं है।',
  'PICKUP_DISABLED': 'अभी सेल्फ पिकअप उपलब्ध नहीं है।',
  'SCHEDULE_REQUIRED': 'कृपया ऑर्डर का समय चुनें।',
  'SCHEDULE_TOO_SOON': 'कृपया कम-से-कम 30 मिनट बाद का समय चुनें।',
  'SCHEDULE_TOO_FAR': 'कृपया अगले 7 दिनों के भीतर का समय चुनें।',
  'SCHEDULING_DISABLED': 'अभी बाद के लिए ऑर्डर शेड्यूल नहीं किए जा सकते।',
  'RESTAURANT_CLOSED': 'रेस्टोरेंट अभी बंद है। कृपया खुलने पर फिर देखें।',
  'ORDERING_PAUSED': 'ऑर्डर कुछ समय के लिए रोक दिए गए हैं।',
  'OUTSIDE_TRADING_HOURS': 'अभी ऑर्डर देने का समय नहीं है।',
  'TOO_BUSY': 'किचन अभी बहुत व्यस्त है। कृपया थोड़ी देर बाद कोशिश करें।',
  'MAINTENANCE_MODE': 'ऑर्डर देना कुछ समय के लिए उपलब्ध नहीं है।',
  'COUPON_INVALID': 'यह कूपन कोड मान्य नहीं है।',
  'COUPON_INACTIVE': 'यह कूपन अभी सक्रिय नहीं है।',
  'COUPON_EXPIRED': 'इस कूपन की समय-सीमा समाप्त हो गई है।',
  'COUPON_NOT_STARTED': 'यह कूपन अभी शुरू नहीं हुआ है।',
  'COUPON_EXHAUSTED': 'इस कूपन के सभी इस्तेमाल पूरे हो चुके हैं।',
  'COUPON_ALREADY_USED': 'आप इस कूपन का इस्तेमाल पहले ही कर चुके हैं।',
  'COUPON_NOT_ELIGIBLE': 'यह कूपन आपके खाते पर लागू नहीं होता।',
  'COUPON_NOT_APPLICABLE': 'यह कूपन आपकी कार्ट पर लागू नहीं होता।',
  'COUPON_FIRST_ORDER_ONLY': 'यह कूपन केवल पहले ऑर्डर पर लागू है।',
  'COUPON_MIN_ORDER_NOT_MET': 'इस कूपन के लिए ऑर्डर की न्यूनतम राशि पूरी करें।',
  'COUPON_NO_ELIGIBLE_ITEMS': 'इस कूपन के लिए योग्य आइटम कार्ट में नहीं हैं।',
  'COUPON_NOT_VALID_TODAY': 'यह कूपन आज मान्य नहीं है।',
  'COUPON_NOT_VALID_NOW': 'यह कूपन अभी मान्य नहीं है।',
  'COUPON_PAYMENT_RESTRICTED': 'यह कूपन चुने गए भुगतान तरीके पर लागू नहीं है।',
  'COUPON_RULE_NOT_MET': 'इस कूपन की शर्तें पूरी नहीं हुई हैं।',
  'BETTER_OFFER_APPLIED': 'आपकी कार्ट पर इससे बेहतर ऑफ़र पहले से लागू है।',
  'ORDER_NOT_FOUND': 'यह ऑर्डर नहीं मिला।',
  'ORDER_ITEM_NOT_FOUND': 'यह ऑर्डर आइटम नहीं मिला।',
  'ORDER_ALREADY_CREATED': 'यह ऑर्डर पहले ही दिया जा चुका है।',
  'INVALID_ORDER_TRANSITION': 'यह ऑर्डर अब इस कार्रवाई की अनुमति नहीं देता।',
  'CANCELLATION_NOT_ALLOWED': 'इस चरण पर ऑर्डर रद्द नहीं किया जा सकता।',
  'CANCELLATION_LIMIT_REACHED': 'ऑर्डर रद्द करने की सीमा पूरी हो गई है।',
  'ITEM_CANCEL_NOT_ALLOWED': 'इस आइटम को अब रद्द नहीं किया जा सकता।',
  'LAST_ITEM_CANNOT_BE_CANCELLED':
      'ऑर्डर का आख़िरी आइटम रद्द नहीं किया जा सकता।',
  'PAYMENT_NOT_FOUND': 'भुगतान की जानकारी नहीं मिली।',
  'PAYMENT_FAILED': 'भुगतान पूरा नहीं हुआ। कृपया फिर कोशिश करें।',
  'PAYMENT_ALREADY_CAPTURED': 'इस भुगतान की पुष्टि पहले ही हो चुकी है।',
  'PAYMENT_SIGNATURE_INVALID':
      'भुगतान सत्यापित नहीं हो सका। सहायता टीम से संपर्क करें।',
  'PAYMENT_AMOUNT_MISMATCH':
      'भुगतान की राशि मेल नहीं खाती। कृपया सहायता टीम से संपर्क करें।',
  'PAYMENT_NOT_REQUIRED': 'इस ऑर्डर के लिए भुगतान की ज़रूरत नहीं है।',
  'GATEWAY_ERROR': 'भुगतान सेवा अभी उपलब्ध नहीं है। कृपया फिर कोशिश करें।',
  'COD_UNAVAILABLE': 'इस ऑर्डर पर कैश ऑन डिलीवरी उपलब्ध नहीं है।',
  'COD_LIMIT_EXCEEDED': 'ऑर्डर की राशि कैश ऑन डिलीवरी की सीमा से ज़्यादा है।',
  'COD_MIN_ORDER_NOT_MET': 'कैश ऑन डिलीवरी के लिए न्यूनतम ऑर्डर पूरा करें।',
  'COD_AMOUNT_MISMATCH':
      'देय राशि मेल नहीं खाती। कृपया सहायता टीम से संपर्क करें।',
  'INSUFFICIENT_WALLET_BALANCE': 'आपके वॉलेट में पर्याप्त बैलेंस नहीं है।',
  'WALLET_FROZEN': 'आपका वॉलेट रोक पर है। सहायता टीम से संपर्क करें।',
  'INSUFFICIENT_LOYALTY_POINTS': 'आपके पास पर्याप्त लॉयल्टी पॉइंट नहीं हैं।',
  'REFUND_NOT_FOUND': 'रिफ़ंड की जानकारी नहीं मिली।',
  'REFUND_NOT_ALLOWED': 'यह रिफ़ंड अभी उपलब्ध नहीं है।',
  'REFUND_NOT_PENDING': 'यह रिफ़ंड अब लंबित नहीं है।',
  'REFUND_ITEMS_REQUIRED': 'रिफ़ंड के लिए आइटम चुनें।',
  'INVALID_REFUND_AMOUNT': 'रिफ़ंड की राशि मान्य नहीं है।',
  'REFUND_AMOUNT_EXCEEDS_REFUNDABLE':
      'रिफ़ंड की राशि उपलब्ध रिफ़ंड से ज़्यादा है।',
  'REFUND_QUANTITY_EXCEEDED': 'रिफ़ंड के लिए चुनी गई मात्रा बहुत ज़्यादा है।',
  'NOT_A_DELIVERY_PARTNER': 'यह सुविधा केवल डिलीवरी पार्टनर के लिए है।',
  'RIDER_NOT_ACTIVE': 'डिलीवरी पार्टनर खाता सक्रिय नहीं है।',
  'NO_DELIVERY_PARTNER': 'अभी कोई डिलीवरी पार्टनर उपलब्ध नहीं है।',
  'ACTIVE_DELIVERIES_PENDING': 'पहले से सक्रिय डिलीवरी पूरी करें।',
  'ASSIGNMENT_NOT_FOUND': 'डिलीवरी असाइनमेंट नहीं मिला।',
  'ASSIGNMENT_EXPIRED': 'इस डिलीवरी असाइनमेंट की समय-सीमा समाप्त हो गई है।',
  'DELIVERY_OTP_REQUIRED': 'डिलीवरी पूरी करने के लिए OTP ज़रूरी है।',
  'DELIVERY_OTP_INVALID': 'डिलीवरी OTP गलत है। कृपया फिर जाँचें।',
  'DELIVERY_OTP_UNAVAILABLE': 'डिलीवरी OTP अभी उपलब्ध नहीं है।',
  'PICKUP_CODE_INVALID': 'पिकअप कोड गलत है। कृपया फिर जाँचें।',
  'PICKUP_CODE_UNAVAILABLE': 'पिकअप कोड अभी उपलब्ध नहीं है।',
  'TOO_MANY_ATTEMPTS': 'बहुत बार कोशिश की गई। कृपया थोड़ी देर रुकें।',
  'TICKET_NOT_FOUND': 'सहायता अनुरोध नहीं मिला।',
  'REVIEW_NOT_ALLOWED': 'इस ऑर्डर के लिए अभी रेटिंग नहीं दी जा सकती।',
  'REVIEW_ALREADY_SUBMITTED': 'आप इस ऑर्डर की रेटिंग पहले ही दे चुके हैं।',
  'CUSTOMER_NOT_FOUND': 'ग्राहक की जानकारी नहीं मिली।',
  'INVOICE_NOT_AVAILABLE': 'इस ऑर्डर का बिल अभी उपलब्ध नहीं है।',
  'REORDER_UNAVAILABLE': 'इस ऑर्डर के आइटम अभी दोबारा उपलब्ध नहीं हैं।',
  'INVALID_AMOUNT': 'कृपया मान्य राशि दर्ज करें।',
  'VALIDATION_ERROR': 'दर्ज की गई जानकारी जाँचें और फिर कोशिश करें।',
  'NETWORK_ERROR': 'आप ऑफ़लाइन लग रहे हैं। अपना इंटरनेट जाँचकर फिर कोशिश करें।',
  'TIMEOUT': 'इसमें बहुत समय लगा। कृपया फिर कोशिश करें।',
  'UNKNOWN': 'हमारी ओर से कुछ गड़बड़ हुई। कृपया फिर कोशिश करें।',
};
