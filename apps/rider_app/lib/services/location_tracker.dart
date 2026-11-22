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

  /// Every order currently being shared (a rider can carry several).
  Set<String> get orderIds => orderId == null ? const {} : {orderId!};

  /// Share the position with exactly these orders: starts, adds, drops or
  /// stops as needed.
  Future<void> follow(Set<String> ids, OrderRepository orders) async {
    if (ids.isEmpty) {
      if (isTracking) await stop();
    } else if (orderId == null) {
      await start(ids.first, orders);
    }
  }

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
  static const _minGap = Duration(seconds: 8);

  /// While standing still, a fresh update is still sent this often (so the
  /// customer's dot stays "live"), but not every few seconds.
  static const _stillGap = Duration(seconds: 30);

  /// Moving less than this counts as standing still (metres).
  static const _moveMetres = 15.0;
  Position? _lastSentPos;

  /// Orders that get every position (the first one is also [orderId]).
  final _ids = <String>{};

  @override
  String? get orderId => _ids.isEmpty ? _orderId : _ids.first;
  @override
  Set<String> get orderIds => {..._ids};

  @override
  Future<void> follow(Set<String> ids, OrderRepository orders) async {
    if (ids.isEmpty) {
      if (isTracking) await stop();
      return;
    }
    if (_sub == null) {
      await start(ids.first, orders);
    }
    final added = ids.difference(_ids);
    _ids
      ..clear()
      ..addAll(ids);
    _orders = orders;
    notifyListeners();
    // A new customer gets a dot straight away, not after the next update.
    if (added.isNotEmpty && _lastSentPos != null) {
      unawaited(_send(_lastSentPos!, only: added));
    }
  }

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
        intervalDuration: const Duration(seconds: 8),
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
  Future<void> _send(Position p, {Set<String>? only}) async {
    final targets =
        only ?? (_ids.isEmpty && _orderId != null ? {_orderId!} : _ids);
    final orders = _orders;
    if (targets.isEmpty || orders == null) return;
    if (only == null) _lastSent = DateTime.now();
    try {
      final here = RiderLocation(
        lat: p.latitude,
        lng: p.longitude,
        heading: p.heading.isNaN ? 0 : p.heading,
        speedKmh: p.speed.isNaN || p.speed < 0 ? 0 : p.speed * 3.6,
        accuracy: p.accuracy,
      );
      // One position, every customer who is waiting for this rider.
      await Future.wait([
        for (final id in {...targets}) orders.publishRiderLocation(id, here),
      ]);
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
    if (_sub != null && _ids.contains(orderId)) return;
    await stop();
    _orderId = orderId;
    _ids
      ..clear()
      ..add(orderId);
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
        final since = DateTime.now().difference(_lastSent);
        final prev = _lastSentPos;
        final moved = prev == null
            ? double.infinity
            : Geolocator.distanceBetween(
                prev.latitude,
                prev.longitude,
                p.latitude,
                p.longitude,
              );
        // Send when moving, or every 30 s when standing still: far fewer
        // database writes (the free plan has a daily limit).
        if (since >= _minGap && (moved >= _moveMetres || since >= _stillGap)) {
          _lastSentPos = p;
          _send(p);
        }
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
    _ids.clear();
    _orders = null;
    _startedAt = null;
    _lastError = null;
    _lastShared = null;
    _lastSentPos = null;
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
