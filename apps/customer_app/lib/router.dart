import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'screens/account/account_screen.dart';
import 'screens/location/location_picker_screen.dart';
import 'screens/account/addresses_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/auth/setup_screen.dart';
import 'screens/business/bulk_quote_screen.dart';
import 'screens/orders/payment_screen.dart';
import 'screens/cart/cart_screen.dart';
import 'screens/cart/checkout_screen.dart';
import 'screens/cart/order_placed_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/info/about_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/info/help_screen.dart';
import 'screens/info/legal_screen.dart';
import 'screens/info/safety_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/orders/chat_screen.dart';
import 'screens/orders/invoice_screen.dart';
import 'screens/orders/order_detail_screen.dart';
import 'screens/orders/orders_screen.dart';
import 'services/backend.dart';
import 'state/app_state.dart';
import 'theme/brand.dart';
import 'utils/haptics.dart';
import 'widgets/app_drawer.dart';
import 'widgets/live.dart';
import 'widgets/push_drawer.dart';

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
      routes: [
        GoRoute(
          path: 'chat',
          builder: (_, s) => OrderChatScreen(orderId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: 'payment',
          builder: (_, s) => PaymentScreen(orderId: s.pathParameters['id']!),
        ),
      ],
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
    GoRoute(path: '/privacy', builder: (_, _) => const PrivacyScreen()),
    GoRoute(path: '/terms', builder: (_, _) => const TermsScreen()),
    GoRoute(path: '/welcome', builder: (_, _) => const OnboardingScreen()),
  ],
);

class _Shell extends StatelessWidget {
  const _Shell(this.shell);
  final StatefulNavigationShell shell;

  void _go(int i) {
    Haptics.select();
    shell.goBranch(i, initialLocation: i == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.select<AppState, String?>((s) => s.uid);
    Widget bar(int active) => _FloatingNav(
      index: shell.currentIndex,
      onTap: _go,
      items: [
        const _NavItem(
          'Order',
          Icons.local_fire_department_outlined,
          Icons.local_fire_department_rounded,
        ),
        _NavItem(
          'My orders',
          Icons.receipt_long_outlined,
          Icons.receipt_long_rounded,
          badge: active,
        ),
        const _NavItem(
          'Account',
          Icons.person_outline_rounded,
          Icons.person_rounded,
        ),
      ],
    );
    return PushDrawerHost(
      drawer: const AppDrawer(),
      child: Scaffold(
        body: shell,
        // Transparent so the floating pill sits over the page background.
        bottomNavigationBar: uid == null
            ? bar(0)
            : Live<List<LpgOrder>>(
                cacheKey: 'nav-$uid',
                stream: () =>
                    context.read<Backend>().orders.watchCustomerOrders(uid),
                builder: (context, snap) => bar(
                  (snap.data ?? const <LpgOrder>[])
                      .where((o) => o.status.isActive)
                      .length,
                ),
              ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.selectedIcon, {this.badge = 0});
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int badge;
}

/// A rounded bar with a sliding highlight under the current tab and a count
/// of active orders on "My orders".
class _FloatingNav extends StatelessWidget {
  const _FloatingNav({
    required this.index,
    required this.onTap,
    required this.items,
  });
  final int index;
  final ValueChanged<int> onTap;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      color: pal.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: pal.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: pal.isDark ? 0.4 : 0.1),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth / items.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      left: w * index,
                      top: 0,
                      bottom: 0,
                      width: w,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Brand.blueDark, Brand.blue],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Brand.blue.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _NavButton(
                              item: items[i],
                              selected: i == index,
                              onTap: () => onTap(i),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final color = selected ? Colors.white : pal.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: item.badge > 0,
              label: Text('${item.badge}'),
              backgroundColor: Brand.cylinderRed,
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                size: 24,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
