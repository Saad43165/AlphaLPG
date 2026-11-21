import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/backend.dart';

import 'package:alpha_ui/alpha_ui.dart' show Alerts, KeepAlive;

import '../services/location_tracker.dart';
import '../utils/order_x.dart';

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
    chat.addListener(notifyListeners);
    _subs.add(
      backend.catalog.watchSettings().listen((s) {
        settings = s;
        notifyListeners();
      }),
    );
    _onAuth();
  }

  final RiderBackend backend;

  /// Unread counts, previews and "Seen" for the chats of my jobs.
  late final ChatInbox chat = ChatInbox(backend.orders, MessageRole.rider);
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
  List<CashHandover> handovers = const [];

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
    _knownAvailable = _knownJobs = null;
    for (final s in _jobMessageSubs.values) {
      s.cancel();
    }
    _jobMessageSubs.clear();
    _messagesSeen.clear();
    chat.follow(const []);
    _beat?.cancel();
    _beat = null;
    notice = null;
    if (uid == null) KeepAlive.stop();
    if (uid != null) {
      _riderSubs.add(
        backend.riders
            .watchRider(uid)
            .listen(
              (p) {
                final wasRider = isRider;
                final wasOnline = online;
                profile = p;
                profileLoaded = true;
                // Someone else (the shop) ended this rider's shift.
                if (wasOnline && !online && wasRider && !_selfToggled) {
                  notice = (p != null && !p.active)
                      ? 'Your account was switched off by Alpha LPG.'
                      : 'Alpha LPG switched you offline. Go online again when you are ready.';
                }
                _syncHeartbeat();
                _syncKeepAlive();
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

  // ---- Phone alerts -----------------------------------------------------------

  Set<String>? _knownAvailable;
  Set<String>? _knownJobs;
  final _jobMessageSubs = <String, StreamSubscription<List<OrderMessage>>>{};
  final _messagesSeen = <String, int>{};

  void _alertAvailable(List<LpgOrder> list) {
    final ids = {for (final o in list) o.id};
    final known = _knownAvailable;
    _knownAvailable = ids;
    if (known == null || !online) return;
    for (final o in list.where((o) => !known.contains(o.id))) {
      Alerts.show(
        id: 100 + (o.id.hashCode & 0xffff),
        title: 'New order available',
        body: '${o.itemsLine} · ${o.areaLine}. First rider to accept gets it.',
      );
    }
  }

  void _alertJobs(List<LpgOrder> list) {
    final ids = {for (final o in list) o.id};
    chat.follow(ids);
    final known = _knownJobs;
    _knownJobs = ids;
    if (known != null) {
      for (final o in list.where((o) => !known.contains(o.id))) {
        Alerts.show(
          id: 70000 + (o.id.hashCode & 0xffff),
          title: 'New job for you',
          body: '${o.customerName} · ${o.itemsLine} · ${o.areaLine}',
        );
      }
    }
    // Messages from the customer or the shop on the jobs I hold.
    for (final o in list) {
      _jobMessageSubs.putIfAbsent(
        o.id,
        () => backend.orders.watchMessages(o.id).listen((msgs) {
          final seen = _messagesSeen[o.id];
          _messagesSeen[o.id] = msgs.length;
          if (seen == null || msgs.length <= seen) return;
          for (final m in msgs.skip(seen)) {
            if (m.role == MessageRole.rider) continue;
            Alerts.show(
              id: 140000 + (o.id.hashCode & 0xffff),
              title: m.role == MessageRole.customer
                  ? '${o.customerName}'
                  : 'Alpha LPG',
              body: m.text,
              payload: 'chat:${o.id}',
            );
          }
        }, onError: (_) {}),
      );
    }
    for (final id in _jobMessageSubs.keys.toList()) {
      if (!ids.contains(id)) _jobMessageSubs.remove(id)?.cancel();
    }
  }

  /// Online riders keep a quiet service running so jobs can alert them even
  /// with the phone in a pocket.
  void _syncKeepAlive() {
    if (online || jobs.isNotEmpty) {
      KeepAlive.start(
        title: online ? 'You are online' : 'Delivery in progress',
        text: 'New jobs and messages will alert you.',
      );
    } else {
      KeepAlive.stop();
    }
  }

  void _listenToWork(String uid) {
    Alerts.init();
    Alerts.askPermission();
    _riderSubs.add(
      backend.orders.watchAvailable().listen((o) {
        available = o;
        _alertAvailable(o);
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
        _alertJobs(jobs);
        _syncTracking();
        _syncKeepAlive();
        notifyListeners();
      }, onError: (_) {}),
    );
    _riderSubs.add(
      backend.ops.watchRiderHandovers(uid).listen((h) {
        handovers = h;
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

  /// A message for the rider ("the shop switched you offline"), shown once.
  String? notice;
  bool _selfToggled = false;
  Timer? _beat;

  void dismissNotice() {
    notice = null;
    notifyListeners();
  }

  /// Goes on or off shift. Returns a message if it did not work.
  Future<String?> setOnline(bool value) async {
    final id = _uid;
    if (id == null) return 'Please sign in again.';
    _selfToggled = true;
    notice = null;
    try {
      await backend.riders.setOnline(id, value);
      if (value) {
        // Ask for location now, so the shop can see which rider is nearest.
        tracker.ensureAccess().then((_) => _beatNow(id)).catchError((_) {});
      }
      return null;
    } catch (e) {
      _selfToggled = false;
      return '$e'.contains('permission-denied')
          ? 'Alpha LPG has not allowed this account to go online. Ask the shop to check your rider account.'
          : 'Could not change your status. Check your internet and try again.';
    } finally {
      // The profile stream will report the change; keep the flag until then.
      Future<void>.delayed(
        const Duration(seconds: 3),
        () => _selfToggled = false,
      );
    }
  }

  Future<void> _beatNow(String u) async {
    final p = await tracker.quickPosition();
    try {
      await backend.riders.heartbeat(u, lat: p?.lat, lng: p?.lng);
    } catch (_) {}
  }

  /// While on shift, tell the shop and customers every minute that this
  /// phone is still here. Stops when offline.
  void _syncHeartbeat() {
    final id = _uid;
    if (id != null && online && isRider) {
      _beat ??= Timer.periodic(const Duration(seconds: 60), (_) {
        final u = _uid;
        if (u != null && online) _beatNow(u);
      });
    } else {
      _beat?.cancel();
      _beat = null;
    }
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

  /// Plain-words reason the last [complete] failed, if known.
  String? completeError;

  Future<bool> complete(
    LpgOrder order, {
    required int cash,
    required int empties,
  }) async {
    final id = _uid;
    if (id == null) return false;
    if (order.awaitingOnlinePayment) {
      completeError = 'Alpha LPG has not confirmed this online payment yet.';
      return false;
    }
    try {
      await backend.orders.completeDelivery(
        order.id,
        id,
        cashCollected: cash,
        emptiesCollected: empties,
        // Only cash-on-delivery money settles the order by itself; for a
        // wallet or bank order the shop confirms the transfer.
        markPaid:
            order.paymentMethod == PaymentMethod.cashOnDelivery &&
            order.paymentStatus != PaymentStatus.paid,
      );
      if (tracker.orderId == order.id) await tracker.stop();
      completeError = null;
      return true;
    } catch (e) {
      completeError = '$e'.contains('permission-denied')
          ? 'The shop has not published the latest database rules yet, so deliveries cannot be saved. Ask Alpha LPG to publish them.'
          : null;
      return false;
    }
  }

  /// Delivery photo, saved after the delivery itself.
  Future<void> addProof(LpgOrder order, String data) async {
    final id = _uid;
    if (id == null) return;
    try {
      await backend.orders.addDeliveryProof(order.id, uid: id, data: data);
    } catch (_) {}
  }

  Future<void> signOut() async {
    await tracker.stop();
    await backend.auth.signOut();
  }

  @override
  void dispose() {
    chat.dispose();
    _beat?.cancel();
    backend.auth.removeListener(_onAuth);
    backend.tracker.removeListener(notifyListeners);
    for (final s in [..._subs, ..._riderSubs]) {
      s.cancel();
    }
    themeMode.dispose();
    super.dispose();
  }
}
