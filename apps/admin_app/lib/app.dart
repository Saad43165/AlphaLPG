import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alpha_core/alpha_core.dart' show LpgOrder;

import 'screens/chat_screen.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/status_screens.dart';
import 'services/backend.dart';
import 'state/session.dart';

class AdminApp extends StatefulWidget {
  const AdminApp({super.key, required this.backend, this.prefs});
  final AdminBackend backend;
  final SharedPreferences? prefs;

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final AdminSession _session = AdminSession(
    widget.backend,
    prefs: widget.prefs,
  );
  final _nav = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Tapping a message notification opens that order's chat.
    Alerts.onTap = (payload) {
      final isOrder = payload.startsWith('order:');
      if (!isOrder && !payload.startsWith('chat:')) return;
      final id = payload.substring(isOrder ? 6 : 5);
      LpgOrder? order;
      for (final o in _session.orders) {
        if (o.id == id) order = o;
      }
      final target = order;
      if (target != null) {
        _nav.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => ChangeNotifierProvider.value(
              value: _session,
              child: isOrder
                  ? OrderDetailScreen(orderId: target.id)
                  : OrderChatScreen(order: target),
            ),
          ),
        );
      }
    };
  }

  final _light = Brand.theme(Brightness.light);
  final _dark = Brand.theme(Brightness.dark);

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: _session,
    child: ValueListenableBuilder<ThemeMode>(
      valueListenable: _session.themeMode,
      builder: (context, mode, _) => MaterialApp(
        navigatorKey: _nav,
        title: 'Alpha LPG Admin',
        debugShowCheckedModeBanner: false,
        theme: _light,
        darkTheme: _dark,
        themeMode: mode,
        home: const _Root(),
      ),
    ),
  );
}

/// Chooses the screen from the sign-in state.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    if (!s.signedIn) return const LoginScreen();
    if (s.isAdmin == null) return const LoadingScreen();
    if (s.isAdmin != true) return const NotAdminScreen();
    return const HomeShell();
  }
}
