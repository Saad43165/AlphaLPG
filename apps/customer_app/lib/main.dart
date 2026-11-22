import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'l10n/lang.dart';
import 'screens/not_configured_screen.dart';
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
  await AppInfo.load();
  UiText.tr = Lang.translate;
  if (Firebase.apps.isNotEmpty) {
    // Crashes go to the shop's error log (Admin app > More > App errors).
    ErrorReporter.install((message, stack, version) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await OpsRepository.firestore(FirebaseFirestore.instance).reportError(
        ErrorEntry(
          app: 'customer',
          version: version,
          uid: uid,
          message: message,
          stack: stack,
        ),
      );
    });
  }
  runApp(
    AlphaApp(
      backend: backend,
      prefs: prefs,
      showSplash: true,
      showOnboarding: !(prefs?.getBool('onboarded') ?? false),
    ),
  );
}
