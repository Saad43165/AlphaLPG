import 'package:alpha_ui/alpha_ui.dart';
import 'package:alpha_core/alpha_core.dart' show LpgOrder;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/chat_screen.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/status_screens.dart';
import 'services/backend.dart';
import 'state/session.dart';

class RiderApp extends StatefulWidget {
  const RiderApp({super.key, required this.backend, this.prefs});
  final RiderBackend backend;
  final SharedPreferences? prefs;

  @override
  State<RiderApp> createState() => _RiderAppState();
}

class _RiderAppState extends State<RiderApp> {
  late final RiderSession _session = RiderSession(
    widget.backend,
    prefs: widget.prefs,
  );
  final _nav = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Tapping a message notification opens that chat.
    Alerts.onTap = (payload) {
      if (!payload.startsWith('chat:')) return;
      final id = payload.substring(5);
      LpgOrder? order;
      for (final o in _session.jobs) {
        if (o.id == id) order = o;
      }
      final target = order;
      if (target != null) {
        _nav.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => ChangeNotifierProvider.value(
              value: _session,
              child: JobChatScreen(order: target),
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
        title: 'Alpha LPG Rider',
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
    final s = context.watch<RiderSession>();
    if (!s.signedIn) return const LoginScreen();
    if (!s.profileLoaded) return const LoadingScreen();
    if (!s.isRider) return const NotRiderScreen();
    return const HomeShell();
  }
}
