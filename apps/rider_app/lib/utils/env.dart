/// Build-time settings. Pass the map key with
/// `--dart-define-from-file=config/keys.json` (that file is git-ignored).
abstract final class Env {
  static const geoapifyKey = String.fromEnvironment('GEOAPIFY_KEY');
}
