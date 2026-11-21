// Firebase project: smarttasksmanager. Android only (pk.alphalpg.admin).
// Regenerate with `flutterfire configure --project=smarttasksmanager`.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError('Firebase is only set up for Android.');
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyBQg38DfCpOEkHZzJP5d7zAJkDDqJ6wBjA',
    appId: '1:797362725470:android:fae37a153e39c35deecacf',
    messagingSenderId: '797362725470',
    projectId: 'smarttasksmanager',
    storageBucket: 'smarttasksmanager.firebasestorage.app',
  );
}
