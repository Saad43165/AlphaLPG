// PLACEHOLDER: replace by running, from this folder:
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=<your-firebase-project-id> --android-package-name=pk.alphalpg.rider
// Until then the app shows a "Firebase is not set up" screen (it has no demo mode).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase is not configured. Run `flutterfire configure`.',
  );
}
