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
