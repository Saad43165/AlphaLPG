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

  /// Why the last upload failed (null while things are working).
  String? get lastError => null;

  /// When sharing began for the current order.
  DateTime? get startedAt => null;

  /// Asks for location permission if needed.
  Future<TrackerAccess> ensureAccess();

  /// A quick, cheap position (last known), or null. Used so the shop can see
  /// which rider is nearest to a new order.
  Future<({double lat, double lng})?> quickPosition() async => null;

  Future<void> start(String orderId, OrderRepository orders);
  Future<void> stop();
  Future<void> openSettings();
}

class GeolocatorTracker extends LocationTracker {
  StreamSubscription<Position>? _sub;
  Timer? _watchdog;
  String? _orderId;
  OrderRepository? _orders;
  DateTime? _lastShared;
  DateTime? _startedAt;
  String? _lastError;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  /// At most one update this often (saves battery, data and database writes).
  static const _minGap = Duration(seconds: 6);

  @override
  String? get orderId => _orderId;
  @override
  DateTime? get lastShared => _lastShared;
  @override
  String? get lastError => _lastError;
  @override
  DateTime? get startedAt => _startedAt;

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
        // 0: report even when standing still (a customer watching a rider
        // parked at a shop should still see a live dot).
        distanceFilter: 0,
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
        distanceFilter: 0,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high);
  }

  /// Sends one position. Records the reason when it fails, so the rider's
  /// screen can say so instead of pretending it works.
  Future<void> _send(Position p) async {
    final id = _orderId;
    final orders = _orders;
    if (id == null || orders == null) return;
    _lastSent = DateTime.now();
    try {
      await orders.publishRiderLocation(
        id,
        RiderLocation(
          lat: p.latitude,
          lng: p.longitude,
          heading: p.heading.isNaN ? 0 : p.heading,
          speedKmh: p.speed.isNaN || p.speed < 0 ? 0 : p.speed * 3.6,
          accuracy: p.accuracy,
        ),
      );
      _lastShared = DateTime.now();
      _lastError = null;
    } catch (e) {
      final text = '$e';
      _lastError = text.contains('permission-denied')
          ? 'The server refused the location. Ask the shop to check the rules.'
          : text.contains('unavailable') || text.contains('network')
          ? 'No internet connection, retrying.'
          : 'Could not send your location, retrying.';
    }
    notifyListeners();
  }

  @override
  Future<void> start(String orderId, OrderRepository orders) async {
    if (_orderId == orderId && _sub != null) return;
    await stop();
    _orderId = orderId;
    _orders = orders;
    _startedAt = DateTime.now();
    _lastError = null;
    notifyListeners();

    // First a quick fix so the customer's map lights up straight away ...
    unawaited(() async {
      try {
        final first =
            await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 20),
              ),
            );
        await _send(first);
      } catch (_) {
        // The live stream below will deliver the first position.
      }
    }());

    // ... then keep going with the live stream.
    _sub = Geolocator.getPositionStream(locationSettings: _settings).listen(
      (p) {
        if (DateTime.now().difference(_lastSent) >= _minGap) _send(p);
      },
      onError: (_) {
        _lastError = 'Your phone is not giving a location. Is GPS on?';
        notifyListeners();
      },
    );

    // A watchdog: if the stream goes quiet (some phones do this while the
    // rider is standing still), ask for a position directly.
    _watchdog = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (DateTime.now().difference(_lastSent) < const Duration(seconds: 14)) {
        return;
      }
      try {
        await _send(
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          ),
        );
      } catch (_) {
        if (_lastError == null && _lastShared == null) {
          _lastError =
              'Still looking for your position. Go outside if you are indoors.';
          notifyListeners();
        }
      }
    });
  }

  @override
  Future<void> stop() async {
    _watchdog?.cancel();
    _watchdog = null;
    await _sub?.cancel();
    _sub = null;
    final had = _orderId != null;
    _orderId = null;
    _orders = null;
    _startedAt = null;
    _lastError = null;
    _lastShared = null;
    if (had) notifyListeners();
  }

  @override
  Future<({double lat, double lng})?> quickPosition() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      return p == null ? null : (lat: p.latitude, lng: p.longitude);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();
}
