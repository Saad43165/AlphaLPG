import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/backend.dart';
import '../services/location_tracker.dart';

enum AcceptResult { ok, taken, offline, error }

enum StartResult {
  ok,
  needsLocation,
  needsLocationSettings,
  locationOff,
  error,
}

/// The signed-in rider's live view of the business: who they are, jobs they
/// can take, jobs they hold, and what they have delivered.
class RiderSession extends ChangeNotifier {
  RiderSession(this.backend, {this.prefs}) {
    final t = prefs?.getString('theme');
    themeMode.value = switch (t) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    backend.auth.addListener(_onAuth);
    backend.tracker.addListener(notifyListeners);
    _subs.add(
      backend.catalog.watchSettings().listen((s) {
        settings = s;
        notifyListeners();
      }),
    );
    _onAuth();
  }

  final RiderBackend backend;
  final SharedPreferences? prefs;
  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  final _subs = <StreamSubscription<dynamic>>[];
  final _riderSubs = <StreamSubscription<dynamic>>[];

  AppSettings settings = const AppSettings();
  String? _uid;
  RiderProfile? profile;
  bool profileLoaded = false;
  List<LpgOrder> available = const [];
  List<LpgOrder> jobs = const [];
  List<LpgOrder> history = const [];

  /// Set when location sharing could not start for a delivery that is on the way.
  String? trackingProblem;

  String? get uid => _uid;
  bool get signedIn => _uid != null;
  bool get isRider => profile != null && profile!.active;
  bool get online => profile?.online ?? false;
  LocationTracker get tracker => backend.tracker;

  // ---- Settings -------------------------------------------------------------

  void setThemeMode(ThemeMode m) {
    themeMode.value = m;
    prefs?.setString('theme', m.name);
  }

  // ---- Stats ----------------------------------------------------------------

  DateTime get _startOfToday {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  List<LpgOrder> get deliveredToday => [
    for (final o in history)
      if (o.status == OrderStatus.delivered &&
          (o.timeOf(OrderStatus.delivered) ?? o.updatedAt ?? DateTime(0))
              .isAfter(_startOfToday))
        o,
  ];

  int get cashToday =>
      deliveredToday.fold(0, (n, o) => n + (o.cashCollected ?? 0));
  int get emptiesToday =>
      deliveredToday.fold(0, (n, o) => n + (o.emptiesCollected ?? 0));

  // ---- Sign-in state ---------------------------------------------------------

  void _onAuth() {
    final uid = backend.auth.uid;
    if (uid == _uid) return;
    for (final s in _riderSubs) {
      s.cancel();
    }
    _riderSubs.clear();
    backend.tracker.stop();
    _uid = uid;
    profile = null;
    profileLoaded = false;
    available = jobs = history = const [];
    trackingProblem = null;
    if (uid != null) {
      _riderSubs.add(
        backend.riders
            .watchRider(uid)
            .listen(
              (p) {
                final wasRider = isRider;
                profile = p;
                profileLoaded = true;
                if (isRider && !wasRider) _listenToWork(uid);
                if (!isRider) {
                  // Blocked or removed: drop everything.
                  available = jobs = history = const [];
                }
                notifyListeners();
              },
              onError: (_) {
                profileLoaded = true;
                notifyListeners();
              },
            ),
      );
    }
    notifyListeners();
  }

  void _listenToWork(String uid) {
    _riderSubs.add(
      backend.orders.watchAvailable().listen((o) {
        available = o;
        notifyListeners();
      }, onError: (_) {}),
    );
    _riderSubs.add(
      backend.orders.watchRiderOrders(uid).listen((o) {
        jobs = [...o]
          ..sort(
            (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
              b.createdAt ?? DateTime(0),
            ),
          );
        _syncTracking();
        notifyListeners();
      }, onError: (_) {}),
    );
    _riderSubs.add(
      backend.orders.watchRiderHistory(uid).listen((o) {
        history = o;
        notifyListeners();
      }, onError: (_) {}),
    );
  }

  /// Keeps location sharing in step with the order that is on the way, also
  /// after the app was closed and reopened mid-delivery.
  Future<void> _syncTracking() async {
    LpgOrder? onTheWay;
    for (final o in jobs) {
      if (o.status == OrderStatus.outForDelivery) onTheWay = o;
    }
    if (onTheWay == null) {
      if (tracker.isTracking) await tracker.stop();
      trackingProblem = null;
      return;
    }
    if (tracker.orderId == onTheWay.id) return;
    final access = await tracker.ensureAccess();
    if (access != TrackerAccess.granted) {
      trackingProblem =
          'Location is off, so the customer cannot see you on the map.';
      notifyListeners();
      return;
    }
    trackingProblem = null;
    await tracker.start(onTheWay.id, backend.orders);
  }

  /// Re-checks location access and restarts sharing from scratch.
  Future<void> retryTracking() async {
    await tracker.stop();
    await _syncTracking();
  }

  // ---- Actions ---------------------------------------------------------------

  Future<void> setOnline(bool value) async {
    final id = _uid;
    if (id == null) return;
    await backend.riders.setOnline(id, value);
  }

  Future<AcceptResult> accept(LpgOrder order) async {
    final p = profile;
    if (p == null || !isRider) return AcceptResult.error;
    if (!p.online) return AcceptResult.offline;
    try {
      final ok = await backend.orders.acceptOrder(
        order.id,
        riderId: p.uid,
        name: p.name,
        phone: p.phone,
      );
      return ok ? AcceptResult.ok : AcceptResult.taken;
    } catch (_) {
      return AcceptResult.error;
    }
  }

  Future<StartResult> start(LpgOrder order) async {
    final id = _uid;
    if (id == null) return StartResult.error;
    final access = await tracker.ensureAccess();
    switch (access) {
      case TrackerAccess.granted:
        break;
      case TrackerAccess.denied:
        return StartResult.needsLocation;
      case TrackerAccess.deniedForever:
        return StartResult.needsLocationSettings;
      case TrackerAccess.serviceOff:
        return StartResult.locationOff;
    }
    try {
      await backend.orders.startDelivery(order.id, id);
      await tracker.start(order.id, backend.orders);
      return StartResult.ok;
    } catch (_) {
      return StartResult.error;
    }
  }

  /// "I've arrived": the customer sees their rider is at the door.
  Future<bool> arrived(LpgOrder order) async {
    final id = _uid;
    if (id == null) return false;
    try {
      await backend.orders.markArrived(order.id, id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Hands an assigned job back to the shop so another rider can take it.
  Future<bool> release(LpgOrder order) async {
    final id = _uid;
    if (id == null) return false;
    try {
      await backend.orders.releaseJob(order.id, id);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> complete(
    LpgOrder order, {
    required int cash,
    required int empties,
  }) async {
    final id = _uid;
    if (id == null) return false;
    try {
      await backend.orders.completeDelivery(
        order.id,
        id,
        cashCollected: cash,
        emptiesCollected: empties,
      );
      if (tracker.orderId == order.id) await tracker.stop();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    await tracker.stop();
    await backend.auth.signOut();
  }

  @override
  void dispose() {
    backend.auth.removeListener(_onAuth);
    backend.tracker.removeListener(notifyListeners);
    for (final s in [..._subs, ..._riderSubs]) {
      s.cancel();
    }
    themeMode.dispose();
    super.dispose();
  }
}
