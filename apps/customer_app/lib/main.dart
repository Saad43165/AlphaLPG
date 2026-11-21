import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config/env.dart';
import 'services/location_service.dart';
import 'services/backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await Backend.init();
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
      location: Env.fakeLocation ? FakeLocationService() : null,
      showOnboarding: !(prefs?.getBool('onboarded') ?? false),
    ),
  );
}
