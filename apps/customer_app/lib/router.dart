import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'screens/account/account_screen.dart';
import 'screens/location/location_picker_screen.dart';
import 'screens/account/addresses_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/auth/setup_screen.dart';
import 'screens/business/bulk_quote_screen.dart';
import 'screens/cart/cart_screen.dart';
import 'screens/cart/checkout_screen.dart';
import 'screens/cart/order_placed_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/info/about_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/info/help_screen.dart';
import 'screens/info/safety_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/orders/invoice_screen.dart';
import 'screens/orders/order_detail_screen.dart';
import 'screens/orders/orders_screen.dart';
import 'state/app_state.dart';

/// Paths that need a signed-in customer.
const _protected = [
  '/checkout',
  '/orders/',
  '/account/',
  '/order-placed',
  '/invoice',
  '/location',
];

GoRouter buildRouter(AppState state) => GoRouter(
  refreshListenable: state.routeSignal,
  redirect: (context, s) {
    final path = s.uri.path;
    if (!state.onboarded) return path == '/welcome' ? null : '/welcome';
    if (path == '/welcome') return '/';
    final needsAuth = _protected.any(path.startsWith);
    if (needsAuth && !state.signedIn) {
      return '/login?from=${Uri.encodeComponent(s.uri.toString())}';
    }
    if (state.signedIn && path == '/login') {
      return s.uri.queryParameters['from'] ?? '/';
    }
    if (state.needsProfile && path != '/setup' && path != '/location') {
      return '/setup';
    }
    return null;
  },
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, s, shell) => _Shell(shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/login',
      builder: (_, s) => LoginScreen(from: s.uri.queryParameters['from']),
    ),
    GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
    GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
    GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
    GoRoute(
      path: '/order-placed/:id',
      builder: (_, s) => OrderPlacedScreen(orderId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/orders/:id',
      builder: (_, s) => OrderDetailScreen(orderId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/account/edit',
      builder: (_, _) => const ProfileSetupScreen(editing: true),
    ),
    GoRoute(
      path: '/account/addresses',
      builder: (_, _) => const AddressesScreen(),
    ),
    GoRoute(
      path: '/location',
      builder: (_, s) => LocationPickerScreen(initial: s.extra as Address?),
    ),
    GoRoute(path: '/bulk-quote', builder: (_, _) => const BulkQuoteScreen()),
    GoRoute(path: '/safety', builder: (_, _) => const SafetyScreen()),
    GoRoute(
      path: '/safety/poster',
      builder: (_, _) => const SafetyPosterScreen(),
    ),
    GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(
      path: '/invoice',
      builder: (_, s) => InvoiceScreen(order: s.extra! as LpgOrder),
    ),
    GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
    GoRoute(path: '/welcome', builder: (_, _) => const OnboardingScreen()),
  ],
);

class _Shell extends StatelessWidget {
  const _Shell(this.shell);
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.local_fire_department_outlined),
          selectedIcon: Icon(Icons.local_fire_department),
          label: 'Order',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'My orders',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Account',
        ),
      ],
    ),
  );
}
