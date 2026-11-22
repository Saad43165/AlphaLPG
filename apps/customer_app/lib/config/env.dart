/// Build-time settings.
abstract final class Env {
  /// Used only by the automated tests' in-memory sign-in.
  static const demoOtp = '123456';

  /// Geoapify map/search key. Supply with
  /// `--dart-define-from-file=config/keys.json` (that file is git-ignored).
  static const geoapifyKey = String.fromEnvironment('GEOAPIFY_KEY');
}

/// Shown in Settings and the drawer. Keep in sync with pubspec.yaml.
const kAppVersion = '1.8.0';
