import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'brand.dart';
import 'chat.dart' show UiText;

/// This app's version and build number (the +N in pubspec `version`).
class AppInfo {
  const AppInfo(this.version, this.build);
  final String version;
  final int build;

  /// "1.5.0+7"
  String get label => '$version+$build';

  static AppInfo current = const AppInfo('0.0.0', 0);

  /// Reads the installed version. Never throws (tests, demo mode).
  static Future<AppInfo> load() async {
    try {
      final p = await PackageInfo.fromPlatform();
      return current = AppInfo(p.version, int.tryParse(p.buildNumber) ?? 0);
    } catch (_) {
      return current;
    }
  }
}

/// Blocks the app with an "update needed" screen when this build is older
/// than the minimum the shop set in its settings (0 = no minimum).
class UpdateGate extends StatelessWidget {
  const UpdateGate({
    super.key,
    required this.minBuild,
    required this.child,
    this.currentBuild,
    this.phone = '',
  });

  final int minBuild;
  final int? currentBuild;
  final Widget child;

  /// Shown so the user can ask for the new version.
  final String phone;

  @override
  Widget build(BuildContext context) {
    final mine = currentBuild ?? AppInfo.current.build;
    if (minBuild <= 0 || mine >= minBuild) return child;
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.card,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.system_update_rounded,
                  size: 72,
                  color: Brand.blueDark,
                ),
                const SizedBox(height: 20),
                Text(
                  UiText.tr('Please update the app'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  UiText.tr(
                    'This version is too old to work properly. Ask Alpha LPG for the new version{}',
                  ).replaceFirst('{}', phone.isEmpty ? '.' : ' (call $phone).'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: pal.muted,
                    height: 1.45,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sends crashes to the shop's error log (at most a few per run, no repeats).
abstract final class ErrorReporter {
  static final _seen = <String>{};
  static var _count = 0;
  static const _max = 5;

  /// [send] writes one report; it must never throw.
  static void install(
    Future<void> Function(String message, String stack, String version) send,
  ) {
    void report(Object error, StackTrace? stack) {
      final message = '$error'.split('\n').first;
      // A dropped connection (a map tile or a photo that did not download) is
      // the phone's internet, not a bug in the app: do not fill the log.
      if (isNetworkNoise('$error')) return;
      final key = message.length > 120 ? message.substring(0, 120) : message;
      if (_count >= _max || !_seen.add(key)) return;
      _count++;
      unawaited(
        send(
          message.length > 480 ? message.substring(0, 480) : message,
          '${stack ?? ''}'.length > 1900
              ? '${stack ?? ''}'.substring(0, 1900)
              : '${stack ?? ''}',
          AppInfo.current.label,
        ).catchError((_) {}),
      );
    }

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      report(details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack);
      return false;
    };
  }

  /// True for plain "the internet dropped" errors.
  @visibleForTesting
  static bool isNetworkNoise(String text) =>
      text.contains('SocketException') ||
      text.contains('HandshakeException') ||
      text.contains('Connection reset') ||
      text.contains('Connection failed') ||
      text.contains('Failed host lookup') ||
      text.contains('TimeoutException') ||
      text.contains('Connection closed');

  @visibleForTesting
  static void reset() {
    _seen.clear();
    _count = 0;
  }
}
