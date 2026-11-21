import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/order_x.dart';
import 'catalogue_screen.dart';
import 'more_screen.dart';
import 'order_detail_screen.dart';
import 'orders_screen.dart';
import 'riders_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final badge = s.newCount + s.toVerifyCount;
    final alert = s.newOrderAlert;
    if (alert != null) {
      s.clearAlert();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Sound and buzz so a new order is noticed, then a tappable banner.
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 8),
              behavior: SnackBarBehavior.floating,
              content: Text(
                'New order: ${alert.customerName} · ${rs(alert.total)}',
              ),
              action: SnackBarAction(
                label: 'OPEN',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OrderDetailScreen(orderId: alert.id),
                  ),
                ),
              ),
            ),
          );
      });
    }
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          OrdersScreen(),
          RidersScreen(),
          CatalogueScreen(),
          MoreScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: const Icon(
              Icons.receipt_long_rounded,
              color: Brand.blueDark,
            ),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.two_wheeler_outlined),
            selectedIcon: Icon(Icons.two_wheeler, color: Brand.blueDark),
            label: 'Riders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.propane_tank_outlined),
            selectedIcon: Icon(Icons.propane_tank, color: Brand.blueDark),
            label: 'Shop',
          ),
          const NavigationDestination(
            icon: Icon(Icons.menu_rounded),
            selectedIcon: Icon(Icons.menu_rounded, color: Brand.blueDark),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
