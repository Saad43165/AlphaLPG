import 'package:go_router/go_router.dart';
import 'package:alpha_ui/alpha_ui.dart' show UpdateGate;
import 'package:material_ui/material_ui.dart' hide Text;

import 'l10n/text.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/lang.dart';
import 'router.dart';
import 'screens/splash_screen.dart';
import 'services/backend.dart';
import 'config/env.dart';
import 'services/geoapify.dart';
import 'services/location_service.dart';
import 'state/app_state.dart';
import 'state/cart.dart';
import 'state/order_watcher.dart';
import 'theme/brand.dart';

class AlphaApp extends StatefulWidget {
  const AlphaApp({
    super.key,
    required this.backend,
    this.prefs,
    this.showOnboarding = false,
    this.location,
    this.showSplash = false,
  });

  final Backend backend;
  final SharedPreferences? prefs;
  final bool showOnboarding;

  /// Defaults to the phone's GPS and geocoder; tests pass a fake.
  final LocationService? location;
  final bool showSplash;

  @override
  State<AlphaApp> createState() => _AlphaAppState();
}

class _AlphaAppState extends State<AlphaApp> {
  late final AppState _state = AppState(
    widget.backend,
    prefs: widget.prefs,
    onboarded: !widget.showOnboarding,
  );
  late final Cart _cart = Cart(prefs: widget.prefs);
  late final GoRouter _router = buildRouter(_state);
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final OrderWatcher _watcher = OrderWatcher(widget.backend, _state);
  late final LocationService _location =
      widget.location ?? defaultLocationService(Env.geoapifyKey);
  late bool _splash = widget.showSplash;
  final _light = Brand.theme(Brightness.light);
  final _dark = Brand.theme(Brightness.dark);

  @override
  void initState() {
    super.initState();
    _watcher; // starts watching orders (notifications) once signed in
    Alerts.onTap = (payload) => _router.push(payload);
    _state.inAppNotice = (title, body, route) {
      final m = _messenger.currentState;
      if (m == null) return;
      m.hideCurrentSnackBar();
      m.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          persist: false,
          showCloseIcon: true,
          closeIconColor: Colors.white,
          content: Text('$title\n$body'),
          action: SnackBarAction(
            label: tr('VIEW'),
            textColor: Colors.white,
            onPressed: () => _router.push(route),
          ),
        ),
      );
    };
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = await Alerts.launchPayload();
      if (p != null && mounted) _router.push(p);
    });
  }

  @override
  void dispose() {
    _watcher.dispose();
    _router.dispose();
    _state.dispose();
    _cart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider.value(value: widget.backend),
      Provider<LocationService>.value(value: _location),
      ChangeNotifierProvider.value(value: _state),
      ChangeNotifierProvider.value(value: _state.chat),
      ChangeNotifierProvider.value(value: _cart),
    ],
    child: ValueListenableBuilder<ThemeMode>(
      valueListenable: _state.themeMode,
      builder: (context, mode, _) => MaterialApp.router(
        scaffoldMessengerKey: _messenger,
        title: 'Alpha LPG',
        debugShowCheckedModeBanner: false,
        theme: _light,
        darkTheme: _dark,
        themeMode: mode,
        routerConfig: _router,
        builder: (context, child) => ValueListenableBuilder<bool>(
          valueListenable: Lang.urdu,
          builder: (context, urdu, _) => Directionality(
            textDirection: urdu ? TextDirection.rtl : TextDirection.ltr,
            child: ListenableBuilder(
              listenable: _state,
              builder: (context, _) => UpdateGate(
                minBuild: _state.settings.minBuildCustomer,
                phone: _state.settings.phone,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    child ?? const SizedBox.shrink(),
                    if (_splash)
                      SplashScreen(
                        onFinished: () => setState(() => _splash = false),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
