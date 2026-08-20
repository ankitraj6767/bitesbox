import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/customer/data/address_models.dart';
import '../../features/customer/screens/account_screen.dart';
import '../../features/customer/screens/address_editor_screen.dart';
import '../../features/customer/screens/addresses_screen.dart';
import '../../features/customer/screens/cart_screen.dart';
import '../../features/customer/screens/checkout_screen.dart';
import '../../features/customer/screens/customer_shell.dart';
import '../../features/customer/screens/home_screen.dart';
import '../../features/customer/screens/menu_screen.dart';
import '../../features/customer/screens/notifications_screen.dart';
import '../../features/customer/screens/offers_screen.dart';
import '../../features/customer/screens/order_tracking_screen.dart';
import '../../features/customer/screens/orders_screen.dart';
import '../../features/customer/screens/otp_screen.dart';
import '../../features/customer/screens/product_screen.dart';
import '../../features/customer/screens/profile_screen.dart';
import '../../features/customer/screens/profile_setup_screen.dart';
import '../../features/customer/screens/search_screen.dart';
import '../../features/customer/screens/sign_in_screen.dart';
import '../../features/customer/screens/splash_screen.dart';
import '../../features/customer/screens/staff_sign_in_screen.dart';
import '../../features/customer/screens/support_screens.dart';
import '../../features/customer/screens/wallet_screen.dart';
import '../../features/delivery/screens/rider_delivery_screen.dart';
import '../../features/delivery/screens/rider_earnings_screen.dart';
import '../../features/delivery/screens/rider_home_screen.dart';
import '../../features/delivery/screens/rider_onboarding_screen.dart';
import '../../features/delivery/screens/rider_profile_screen.dart';
import '../../features/kitchen/screens/kitchen_availability_screen.dart';
import '../../features/kitchen/screens/kitchen_queue_screen.dart';
import '../../features/kitchen/screens/kitchen_shell.dart';
import '../auth/session.dart';
import '../providers/core_providers.dart';
import 'routes.dart';

/// One router, three shells.
///
/// Which shell a user lands in follows from their primary role. That is a
/// convenience, not a security boundary: the database independently enforces
/// every read and write, so loading a different shell gains a tampered client
/// nothing.
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.signIn, builder: (_, __) => const SignInScreen()),
      GoRoute(
        path: Routes.verify,
        builder: (_, state) => OtpScreen(phone: state.extra as String? ?? ''),
      ),
      GoRoute(path: Routes.staffSignIn, builder: (_, __) => const StaffSignInScreen()),
      GoRoute(path: Routes.profileSetup, builder: (_, __) => const ProfileSetupScreen()),

      // ── Customer shell ──
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) => CustomerShell(shell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.menu, builder: (_, __) => const MenuScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.orders, builder: (_, __) => const OrdersScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.account, builder: (_, __) => const AccountScreen()),
            ],
          ),
        ],
      ),

      // ── Customer detail screens ──
      GoRoute(path: Routes.search, builder: (_, __) => const SearchScreen()),
      GoRoute(
        path: '/product/:id',
        builder: (_, state) => ProductScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.cart, builder: (_, __) => const CartScreen()),
      GoRoute(path: Routes.checkout, builder: (_, __) => const CheckoutScreen()),
      GoRoute(path: Routes.offers, builder: (_, __) => const OffersScreen()),
      GoRoute(path: Routes.addresses, builder: (_, __) => const AddressesScreen()),
      GoRoute(
        path: Routes.addressEditor,
        // `extra` carries the address being edited; absent means "add new".
        builder: (_, state) => AddressEditorScreen(
          address: state.extra is CustomerAddress ? state.extra as CustomerAddress : null,
        ),
      ),
      GoRoute(path: Routes.wallet, builder: (_, __) => const WalletScreen()),
      GoRoute(
        path: Routes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(path: Routes.profile, builder: (_, __) => const ProfileScreen()),
      GoRoute(path: Routes.newTicket, builder: (_, __) => const NewTicketScreen()),
      GoRoute(path: Routes.support, builder: (_, __) => const SupportListScreen()),
      GoRoute(
        path: '/support/:id',
        builder: (_, state) => SupportThreadScreen(ticketId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/order/:id',
        builder: (_, state) => OrderTrackingScreen(orderId: state.pathParameters['id']!),
      ),

      // ── Kitchen shell ──
      ShellRoute(
        builder: (_, __, child) => KitchenShell(child: child),
        routes: [
          GoRoute(path: Routes.kitchen, builder: (_, __) => const KitchenQueueScreen()),
          GoRoute(
            path: Routes.kitchenAvailability,
            builder: (_, __) => const KitchenAvailabilityScreen(),
          ),
        ],
      ),

      // ── Delivery shell ──
      // The rider screens carry their own chrome (RiderScaffold) rather than a
      // ShellRoute, because the active-delivery screen deliberately drops the
      // bottom navigation to keep a single obvious action on screen.
      GoRoute(path: Routes.rider, builder: (_, __) => const RiderHomeScreen()),
      GoRoute(
        path: Routes.riderEarnings,
        builder: (_, __) => const RiderEarningsScreen(),
      ),
      GoRoute(
        path: Routes.riderProfile,
        builder: (_, __) => const RiderProfileScreen(),
      ),
      // Deliberately outside the rider nav bar: a rider who is not yet active has
      // nothing to navigate between, and the checklist is a task to finish rather
      // than a tab to live in.
      GoRoute(
        path: Routes.riderOnboarding,
        builder: (_, __) => const RiderOnboardingScreen(),
      ),
      GoRoute(
        path: '/rider/delivery/:assignmentId',
        builder: (_, state) => RiderDeliveryScreen(
          assignmentId: state.pathParameters['assignmentId']!,
        ),
      ),
    ],
    errorBuilder: (_, state) => _RouteNotFound(location: state.uri.toString()),
  );
});

/// Decides where a request may actually go.
String? _redirect(Ref ref, GoRouterState state) {
  final sessionState = ref.read(sessionProvider);
  final location = state.uri.path;

  // Hold on the splash while the session resolves, so we never flash the wrong
  // shell at a returning rider or kitchen tablet.
  if (sessionState.isLoading && !sessionState.hasValue) {
    return location == Routes.splash ? null : Routes.splash;
  }

  final session = sessionState.valueOrNull ?? const AppSession.guest();

  if (session.isGuest) {
    if (Routes.isOnboarding(location) && location != Routes.splash) return null;
    if (Routes.isGuestBrowsable(location)) return null;
    // A guest tapping the splash lands on the menu: browsing first, sign-in later.
    return location == Routes.splash ? Routes.home : Routes.signIn;
  }

  // A customer must finish their profile before they can order.
  if (session.needsProfileSetup && location != Routes.profileSetup) {
    return Routes.profileSetup;
  }

  final landing = _landingFor(session);

  if (Routes.isOnboarding(location)) return landing;
  if (location == Routes.profileSetup && !session.needsProfileSetup) return landing;

  // Riders and kitchen staff have no customer tabs; keep them in their own shell.
  if (session.isRider && !location.startsWith('/rider')) return Routes.rider;

  if (session.prefersKitchenShell && !session.isRider) {
    final allowed = location.startsWith('/kitchen') ||
        location.startsWith('/order/') ||
        location == Routes.profile;
    if (!allowed) return Routes.kitchen;
  }

  return null;
}

String _landingFor(AppSession session) {
  if (session.isRider) return Routes.rider;
  if (session.prefersKitchenShell) return Routes.kitchen;
  return Routes.home;
}

/// Bridges Riverpod's session state to GoRouter's refresh mechanism.
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(this._ref) {
    _subscription = _ref.listen(
      sessionProvider,
      (_, __) => notifyListeners(),
      fireImmediately: false,
    );
  }

  final Ref _ref;
  late final ProviderSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 44),
              const SizedBox(height: 16),
              Text(
                'We could not open $location',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go(Routes.home),
                child: const Text('Go to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
