import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Phone notifications for the Alpha LPG apps (order updates, messages, new
/// jobs). Works on Firebase's free plan: the app itself listens to the
/// database and raises the notification, and a small "keep alive" service
/// stops Android from putting the app to sleep while something is going on.
///
/// Everything here fails quietly (tests, web, missing permission).
abstract final class Alerts {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Called with the notification's payload (e.g. `/orders/abc`) when tapped.
  static void Function(String payload)? onTap;

  static Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (r) {
          final p = r.payload;
          if (p != null && p.isNotEmpty) onTap?.call(p);
        },
      );
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          'orders',
          'Orders and messages',
          description: 'Order updates, messages and new jobs',
          importance: Importance.high,
        ),
      );
      _ready = true;
    } catch (_) {}
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Asks for the Android 13+ notification permission (once is enough).
  static Future<void> askPermission() async {
    if (kIsWeb) return;
    try {
      await _android?.requestNotificationsPermission();
    } catch (_) {}
  }

  /// The payload of the notification that opened the app, if any.
  static Future<String?> launchPayload() async {
    if (kIsWeb) return null;
    try {
      final d = await _plugin.getNotificationAppLaunchDetails();
      if (d?.didNotificationLaunchApp ?? false) {
        return d?.notificationResponse?.payload;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_ready) await init();
    if (!_ready) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'orders',
            'Orders and messages',
            channelDescription: 'Order updates, messages and new jobs',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
        payload: payload,
      );
    } catch (_) {}
  }
}

/// A quiet ongoing notification that keeps the app alive in the background
/// so [Alerts] can fire while the phone is in your pocket.
abstract final class KeepAlive {
  static bool _inited = false;

  static void _init() {
    if (_inited) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'keepalive',
        channelName: 'Staying connected',
        channelDescription: 'Keeps the app connected so you get updates.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _inited = true;
  }

  static Future<void> start({
    required String title,
    required String text,
  }) async {
    if (kIsWeb) return;
    try {
      _init();
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 7101,
          serviceTypes: [ForegroundServiceTypes.dataSync],
          notificationTitle: title,
          notificationText: text,
          callback: _idleEntry,
        );
      }
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (kIsWeb) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
void _idleEntry() => FlutterForegroundTask.setTaskHandler(_IdleHandler());

class _IdleHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// In-app message at the bottom of the screen. Always goes away by itself
/// after [seconds] (also on phones where the system would keep it open), and
/// can be closed with the ✕.
void showAppMessage(
  BuildContext context,
  String message, {
  bool error = false,
  int seconds = 4,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xFFB3261E) : null,
      duration: Duration(seconds: seconds),
      persist: false,
      showCloseIcon: true,
      closeIconColor: Colors.white,
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onAction ?? () {},
            ),
    ),
  );
}
