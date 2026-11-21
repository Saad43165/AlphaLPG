import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'screens/not_configured_screen.dart';
import 'config/env.dart';
import 'services/location_service.dart';
import 'services/backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final Backend backend;
  try {
    backend = await Backend.init();
  } catch (e) {
    runApp(const NotConfiguredApp());
    return;
  }
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    // Cart simply won't persist between launches.
  }
  runApp(
    AlphaApp(
      backend: backend,
      prefs: prefs,
      showSplash: true,
      location: Env.fakeLocation
          ? FakeLocationService()
          : null, // null → Geoapify if a key was supplied
      showOnboarding: !(prefs?.getBool('onboarded') ?? false),
    ),
  );
}
