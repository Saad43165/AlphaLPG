import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
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
