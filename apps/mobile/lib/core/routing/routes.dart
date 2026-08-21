/// Every route path in one place, so navigation is never a magic string.
abstract final class Routes {
  // Onboarding
  static const splash = '/';
  static const signIn = '/sign-in';
  static const verify = '/verify';
  static const staffSignIn = '/staff-sign-in';
  static const riderSignup = '/rider-signup';
  static const profileSetup = '/profile-setup';

  // Customer shell tabs
  static const home = '/home';
  static const menu = '/menu';
  static const orders = '/orders';
  static const account = '/account';

  // Customer detail screens
  static const search = '/search';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const offers = '/offers';
  static const addresses = '/addresses';
  static const addressEditor = '/addresses/edit';
  static const wallet = '/wallet';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const support = '/support';
  static const newTicket = '/support/new';

  static String product(String id) => '/product/$id';
  static String order(String id) => '/order/$id';
  static String ticket(String id) => '/support/$id';

  // Kitchen
  static const kitchen = '/kitchen';
  static const kitchenAvailability = '/kitchen/availability';

  // Delivery
  static const rider = '/rider';
  static const riderEarnings = '/rider/earnings';
  static const riderProfile = '/rider/profile';
  static const riderOnboarding = '/rider/onboarding';

  static String riderDelivery(String assignmentId) =>
      '/rider/delivery/$assignmentId';

  /// Routes a signed-out visitor may browse. Everything else redirects to sign-in.
  static bool isGuestBrowsable(String location) {
    return location == home ||
        location == menu ||
        location == search ||
        location.startsWith('/product/');
  }

  /// Routes that belong to the onboarding flow.
  static bool isOnboarding(String location) {
    return location == splash ||
        location == signIn ||
        location == verify ||
        location == staffSignIn ||
        location == riderSignup;
  }
}
