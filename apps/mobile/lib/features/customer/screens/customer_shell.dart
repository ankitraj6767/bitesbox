import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/brand_tokens.dart';
import '../providers/cart_controller.dart';
import '../providers/customer_providers.dart';

/// The customer tab bar: Home, Menu, Orders, Account.
///
/// A guest sees the same tabs — browsing is deliberately open — and only hits a
/// sign-in wall when they try to order.
class CustomerShell extends ConsumerWidget {
  const CustomerShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final cartCount = ref.watch(cartUnitCountProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      body: shell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: brand.surface,
          border: Border(top: BorderSide(color: brand.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _onDestinationSelected,
            backgroundColor: brand.surface,
            surfaceTintColor: Colors.transparent,
            indicatorColor: brand.primary.withValues(alpha: 0.12),
            height: 64,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: cartCount > 0,
                  label: Text('$cartCount'),
                  backgroundColor: brand.primary,
                  child: const Icon(Icons.restaurant_menu_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: cartCount > 0,
                  label: Text('$cartCount'),
                  backgroundColor: brand.primary,
                  child: const Icon(Icons.restaurant_menu_rounded),
                ),
                label: 'Menu',
              ),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  backgroundColor: brand.primary,
                  child: const Icon(Icons.person_outline_rounded),
                ),
                selectedIcon: const Icon(Icons.person_rounded),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onDestinationSelected(int index) {
    // Tapping the current tab again pops it back to its root, which is what
    // customers expect after drilling into a category.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }
}
