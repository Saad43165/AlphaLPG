import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'screens/status_screens.dart';
import 'services/backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    runApp(SetupNeededApp(error: e));
    return;
  }
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {}
  await AppInfo.load();
  if (Firebase.apps.isNotEmpty) {
    // Crashes go to the shop's error log (Admin app > More > App errors).
    ErrorReporter.install((message, stack, version) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await OpsRepository.firestore(FirebaseFirestore.instance).reportError(
        ErrorEntry(
          app: 'admin',
          version: version,
          uid: uid,
          message: message,
          stack: stack,
        ),
      );
    });
  }
  runApp(
    AdminApp(
      backend: AdminBackend.firebase(
        FirebaseFirestore.instance,
        FirebaseAuth.instance,
      ),
      prefs: prefs,
    ),
  );
}
