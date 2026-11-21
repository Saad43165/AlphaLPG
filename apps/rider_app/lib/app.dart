import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
