import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'router.dart';
import 'services/backend.dart';
import 'state/app_state.dart';
import 'state/cart.dart';
import 'theme/brand.dart';

class AlphaApp extends StatefulWidget {
  const AlphaApp({
    super.key,
    required this.backend,
    this.prefs,
    this.showOnboarding = false,
  });
  final Backend backend;
  final SharedPreferences? prefs;
  final bool showOnboarding;

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

  @override
  void dispose() {
    _router.dispose();
    _state.dispose();
    _cart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider.value(value: widget.backend),
      ChangeNotifierProvider.value(value: _state),
      ChangeNotifierProvider.value(value: _cart),
    ],
    child: MaterialApp.router(
      title: 'Alpha LPG',
      debugShowCheckedModeBanner: false,
      theme: Brand.theme(),
      routerConfig: _router,
    ),
  );
}
