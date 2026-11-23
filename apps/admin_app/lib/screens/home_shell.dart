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
        showAppMessage(
          context,
          'New order: ${alert.customerName} · ${rs(alert.total)}',
          seconds: 8,
          actionLabel: 'OPEN',
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OrderDetailScreen(orderId: alert.id),
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
            selectedIcon: Icon(
              Icons.receipt_long_rounded,
              color: context.pal.blue,
            ),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(
              Icons.local_shipping_rounded,
              color: context.pal.blue,
            ),
            label: 'Riders',
          ),
          NavigationDestination(
            icon: Icon(Icons.propane_tank_outlined),
            selectedIcon: Icon(Icons.propane_tank, color: context.pal.blue),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_rounded),
            selectedIcon: Icon(Icons.menu_rounded, color: context.pal.blue),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
