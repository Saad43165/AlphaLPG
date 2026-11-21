import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum TrackerAccess { granted, denied, deniedForever, serviceOff }

/// Shares the rider's position with the customer while an order is out for
/// delivery. Runs as a foreground service so it keeps working with the
/// screen off.
abstract class LocationTracker extends ChangeNotifier {
  /// The order currently being shared, or null.
  String? get orderId;
  bool get isTracking => orderId != null;

  /// When the last position reached the server.
  DateTime? get lastShared;

  /// Asks for location permission if needed.
  Future<TrackerAccess> ensureAccess();

  Future<void> start(String orderId, OrderRepository orders);
  Future<void> stop();
  Future<void> openSettings();
}

class GeolocatorTracker extends LocationTracker {
  StreamSubscription<Position>? _sub;
  String? _orderId;
  DateTime? _lastShared;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  /// At most one update this often (saves battery, data and database writes).
  static const _minGap = Duration(seconds: 6);

  @override
  String? get orderId => _orderId;
  @override
  DateTime? get lastShared => _lastShared;

  @override
  Future<TrackerAccess> ensureAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return TrackerAccess.serviceOff;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return switch (p) {
      LocationPermission.always ||
      LocationPermission.whileInUse => TrackerAccess.granted,
      LocationPermission.deniedForever => TrackerAccess.deniedForever,
      _ => TrackerAccess.denied,
    };
  }

  LocationSettings get _settings {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 6),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Alpha LPG delivery in progress',
          notificationText: 'Sharing your location with the customer.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }

  @override
  Future<void> start(String orderId, OrderRepository orders) async {
    if (_orderId == orderId) return;
    await stop();
    _orderId = orderId;
    notifyListeners();
    _sub = Geolocator.getPositionStream(locationSettings: _settings)
        .listen((p) async {
          final now = DateTime.now();
          if (now.difference(_lastSent) < _minGap) return;
          _lastSent = now;
          try {
            await orders.publishRiderLocation(
              orderId,
              RiderLocation(
                lat: p.latitude,
                lng: p.longitude,
                heading: p.heading.isNaN ? 0 : p.heading,
                speedKmh: p.speed.isNaN || p.speed < 0 ? 0 : p.speed * 3.6,
                accuracy: p.accuracy,
              ),
            );
            _lastShared = now;
            notifyListeners();
          } catch (_) {
            // Offline or rules not ready: the next update will try again.
          }
        }, onError: (_) {});
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    final had = _orderId != null;
    _orderId = null;
    if (had) notifyListeners();
  }

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();
}
