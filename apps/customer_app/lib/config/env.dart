/// Build-time switches.
///
/// `flutter run --dart-define=DEMO=true` runs the app without Firebase using
/// an in-memory database and a fake OTP (123456). The app also falls back to
/// demo mode automatically when Firebase has not been configured yet.
abstract final class Env {
  static const forceDemo = bool.fromEnvironment('DEMO');
  static const demoOtp = '123456';
}
