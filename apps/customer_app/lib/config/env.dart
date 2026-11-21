/// Build-time switches.
///
/// `flutter run --dart-define=DEMO=true` runs the app without Firebase using
/// an in-memory database and a fake OTP (123456). The app also falls back to
/// demo mode automatically when Firebase has not been configured yet.
abstract final class Env {
  static const forceDemo = bool.fromEnvironment('DEMO');
  static const demoOtp = '123456';

  /// Geoapify map/search key. Supply with
  /// `--dart-define-from-file=config/keys.json` (that file is git-ignored).
  static const geoapifyKey = String.fromEnvironment('GEOAPIFY_KEY');

  /// Screenshots/demos on machines without GPS or map access.
  static const fakeLocation = bool.fromEnvironment('FAKE_LOCATION');
}

/// Shown in Settings and the drawer. Keep in sync with pubspec.yaml.
const kAppVersion = '1.4.1';
