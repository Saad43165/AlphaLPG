import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alpha_ui/alpha_ui.dart' show Alerts, KeepAlive;

import '../services/backend.dart';
import '../utils/order_x.dart';

/// The owner's live view of the whole business.
class AdminSession extends ChangeNotifier {
  AdminSession(this.backend, {this.prefs}) {
    themeMode.value = switch (prefs?.getString('theme')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    backend.auth.addListener(_onAuth);
    chat.addListener(notifyListeners);
    _onAuth();
  }

  final AdminBackend backend;

  /// Unread counts, previews and "Seen" for chats on orders in progress.
  late final ChatInbox chat = ChatInbox(backend.orders, MessageRole.admin);
  final SharedPreferences? prefs;
  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  final _subs = <StreamSubscription<dynamic>>[];
  StreamSubscription<bool>? _adminSub;
  String? _uid;

  /// null until `admins/{uid}` has been checked.
  bool? isAdmin;
  String? error;

  List<LpgOrder> orders = const [];
  List<RiderProfile> riders = const [];
  List<QuoteRequest> quotes = const [];
  List<Product> products = const [];
  AppSettings settings = const AppSettings();

  /// False until the owner has loaded the catalogue and saved settings.
  bool storeReady = true;
  bool _hasProducts = true, _hasSettings = true;
  bool ordersLoaded = false;

  /// Set when a new order arrives while the app is open; the shell shows it.
  LpgOrder? newOrderAlert;
  final _knownIds = <String>{};

  void clearAlert() => newOrderAlert = null;

  String? get uid => _uid;
  bool get signedIn => _uid != null;

  void setThemeMode(ThemeMode m) {
    themeMode.value = m;
    prefs?.setString('theme', m.name);
  }

  // ---- Derived numbers --------------------------------------------------------

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  List<LpgOrder> ordersIn(Iterable<OrderStatus> s) => [
    for (final o in orders)
      if (s.contains(o.status)) o,
  ];

  int get newCount =>
      orders.where((o) => o.status == OrderStatus.placed).length;
  int get activeCount => orders
      .where(
        (o) =>
            o.status == OrderStatus.confirmed ||
            o.status == OrderStatus.assigned ||
            o.status == OrderStatus.outForDelivery,
      )
      .length;

  /// Online orders where the customer has sent a receipt to check.
  int get receiptsToCheckCount =>
      orders.where((o) => o.awaitingPaymentCheck && o.receiptAt != null).length;

  int get toVerifyCount => orders.where((o) => o.awaitingPaymentCheck).length;

  Iterable<LpgOrder> get _deliveredToday => orders.where(
    (o) =>
        o.status == OrderStatus.delivered &&
        (o.timeOf(OrderStatus.delivered) ?? o.updatedAt ?? DateTime(0)).isAfter(
          _today,
        ),
  );
  int get deliveredTodayCount => _deliveredToday.length;
  int get salesToday => _deliveredToday.fold(0, (n, o) => n + o.total);
  int get cashWithRiders => orders
      .where(
        (o) =>
            o.status == OrderStatus.delivered &&
            o.paymentMethod == PaymentMethod.cashOnDelivery,
      )
      .where((o) => (o.updatedAt ?? DateTime(0)).isAfter(_today))
      .fold(0, (n, o) => n + (o.cashCollected ?? 0));

  RiderProfile? riderById(String? id) {
    for (final r in riders) {
      if (r.uid == id) return r;
    }
    return null;
  }

  // ---- Actions (all return an error message, or null on success) ------------

  Future<String?> _run(Future<void> Function() job) async {
    try {
      await job();
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> confirm(LpgOrder o) => _run(
    () => backend.orders.updateStatus(o.id, OrderStatus.confirmed, uid!),
  );

  Future<String?> assign(LpgOrder o, RiderProfile r) => _run(
    () => backend.orders.assignRider(
      o.id,
      uid!,
      riderId: r.uid,
      name: r.name,
      phone: r.phone,
    ),
  );

  Future<String?> cancel(LpgOrder o, String reason) => _run(
    () => backend.orders.updateStatus(
      o.id,
      OrderStatus.cancelled,
      uid!,
      note: reason,
    ),
  );

  Future<String?> markDelivered(LpgOrder o) => _run(
    () => backend.orders.updateStatus(o.id, OrderStatus.delivered, uid!),
  );

  Future<String?> markPaid(LpgOrder o) =>
      _run(() => backend.orders.markPaid(o.id, uid!));

  Future<String?> sendPaymentRequest(LpgOrder o, PaymentRequest r) =>
      _run(() => backend.orders.sendPaymentRequest(o.id, r));

  /// Tell the customer what is wrong with their payment ('' clears it).
  Future<String?> setPaymentIssue(LpgOrder o, String issue) =>
      _run(() => backend.orders.setPaymentIssue(o.id, issue));

  Future<String?> saveProduct(Product p) =>
      _run(() => backend.catalog.saveProduct(p));

  /// Drag-to-reorder: renumbers the products and saves the ones that moved.
  Future<String?> moveProduct(int from, int to) => _run(() async {
    final list = [...products];
    if (to > from) to -= 1;
    final item = list.removeAt(from);
    list.insert(to, item);
    for (var i = 0; i < list.length; i++) {
      final p = list[i];
      if (p.sortOrder != i + 1) {
        await backend.catalog.saveProduct(
          Product.fromMap(p.id, {...p.toMap(), 'sortOrder': i + 1}),
        );
      }
    }
  });

  Future<String?> saveSettings(AppSettings s) =>
      _run(() => backend.catalog.saveSettings(s));
  Future<String?> loadDefaults() => _run(backend.catalog.seed);

  Future<String?> setQuoteStatus(QuoteRequest q, String status) =>
      _run(() => backend.quotes.setStatus(q.id, status));

  // ---- Shop and rider control ------------------------------------------------

  /// Riders whose app is really running and on shift.
  List<RiderProfile> get liveRiders => [
    for (final r in riders)
      if (r.isLive()) r,
  ];

  /// Open or close the shop for customers (takes effect at once everywhere).
  Future<String?> setShopOpen(bool open) => saveSettings(
    AppSettings.fromMap({...settings.toMap(), 'acceptingOrders': open}),
  );

  /// Puts a rider on or off shift from here. (Their phone then keeps the
  /// status fresh; if their app is not running they show as "No signal".)
  Future<String?> setRiderOnline(RiderProfile r, bool online) =>
      _run(() => backend.riders.setOnline(r.uid, online));

  /// Ends a rider's shift from here. They are told in their app.
  Future<String?> switchRiderOffline(RiderProfile r) =>
      _run(() => backend.riders.setOnline(r.uid, false));

  Future<String?> switchAllRidersOffline() => _run(() async {
    for (final r in riders.where((r) => r.online)) {
      await backend.riders.setOnline(r.uid, false);
    }
  });

  /// Change a rider's name, phone or vehicle.
  Future<String?> editRider(
    RiderProfile r, {
    required String name,
    required String phone,
    required String vehicle,
  }) => _run(
    () => backend.riders.saveRider(
      RiderProfile(
        uid: r.uid,
        name: name,
        phone: phone,
        vehicle: vehicle,
        active: r.active,
        online: r.online,
      ),
    ),
  );

  /// Jobs a rider is holding right now.
  List<LpgOrder> jobsOf(String riderUid) => [
    for (final o in orders)
      if (o.riderId == riderUid &&
          (o.status == OrderStatus.assigned ||
              o.status == OrderStatus.outForDelivery))
        o,
  ];

  /// Removes a rider. Refused while they still hold jobs.
  Future<String?> removeRider(RiderProfile r) async {
    if (jobsOf(r.uid).isNotEmpty) {
      return '${r.name} still has jobs. Take them back first.';
    }
    return _run(() => backend.riders.deleteRider(r.uid));
  }

  /// Takes an order back from its rider so it can be given to someone else.
  Future<String?> unassign(LpgOrder o) =>
      _run(() => backend.orders.unassignRider(o.id, uid!));

  Future<String?> setRiderActive(RiderProfile r, bool active) =>
      _run(() => backend.riders.setActive(r.uid, active));

  /// Creates the rider's login and profile.
  Future<String?> addRider({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String vehicle,
  }) => _run(() async {
    final riderUid = await backend.createRiderLogin(email, password);
    await backend.riders.saveRider(
      RiderProfile(uid: riderUid, name: name, phone: phone, vehicle: vehicle),
    );
  });

  String _friendly(Object e) {
    final s = '$e';
    if (s.contains('permission-denied')) {
      return 'Not allowed. Check that this account is listed in the admins collection and the rules are published.';
    }
    if (s.contains('unavailable') || s.contains('network')) {
      return 'No internet connection. Please try again.';
    }
    return e is Exception && s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  // ---- Wiring ---------------------------------------------------------------

  void _onAuth() {
    final next = backend.auth.uid;
    if (next == _uid) return;
    _uid = next;
    _stop();
    isAdmin = null;
    if (next == null) {
      notifyListeners();
      return;
    }
    _adminSub = backend.watchIsAdmin(next).listen((v) {
      final was = isAdmin;
      isAdmin = v;
      if (v && was != true) _startData();
      if (!v) _stopData();
      notifyListeners();
    }, onError: (_) {});
    notifyListeners();
  }

  // ---- Customer and rider messages on orders in progress -------------------

  final _receiptSeen = <String, DateTime>{};
  final _chatSubs = <String, StreamSubscription<List<OrderMessage>>>{};
  final _chatSeen = <String, int>{};

  void _watchChats(List<LpgOrder> list) {
    // Orders in progress, plus ones delivered in the last 2 days (a customer
    // may still report a problem or send a receipt).
    final recent = DateTime.now().subtract(const Duration(days: 2));
    final active = [
      for (final o in list)
        if (o.status.isActive ||
            (o.status == OrderStatus.delivered &&
                (o.updatedAt ?? DateTime(0)).isAfter(recent)))
          o,
    ];
    for (final o in active) {
      _chatSubs.putIfAbsent(
        o.id,
        () => backend.orders.watchMessages(o.id).listen((msgs) {
          final seen = _chatSeen[o.id];
          _chatSeen[o.id] = msgs.length;
          if (seen == null || msgs.length <= seen) return;
          for (final m in msgs.skip(seen)) {
            if (m.role == MessageRole.admin) continue;
            Alerts.show(
              id: 300000 + (o.id.hashCode & 0xffff),
              title: m.role == MessageRole.customer
                  ? '${o.customerName} (customer)'
                  : '${m.name} (rider)',
              body: '${m.text}  ·  ${o.displayNumber}',
              payload: 'chat:${o.id}',
            );
          }
        }, onError: (_) {}),
      );
    }
    final ids = {for (final o in active) o.id};
    chat.follow(ids);
    for (final id in _chatSubs.keys.toList()) {
      if (!ids.contains(id)) _chatSubs.remove(id)?.cancel();
    }
  }

  void _startData() {
    Alerts.init();
    Alerts.askPermission();
    KeepAlive.start(
      title: 'Alpha LPG Admin',
      text: 'You will be alerted about new orders and messages.',
    );
    void listen<T>(Stream<T> s, void Function(T) on) => _subs.add(
      s.listen(
        (v) {
          on(v);
          notifyListeners();
        },
        onError: (Object e) {
          error = _friendly(e);
          notifyListeners();
        },
      ),
    );
    listen(backend.orders.watchRecent(), (v) {
      // After the first load, a placed order we have not seen is "new".
      if (ordersLoaded) {
        for (final o in v) {
          if (o.status == OrderStatus.placed && !_knownIds.contains(o.id)) {
            newOrderAlert = o;
            Alerts.show(
              id: 200 + (o.id.hashCode & 0xffff),
              title: 'New order · ${rs(o.total)}',
              body: '${o.customerName} · ${o.itemsLine} · ${o.areaLine}',
            );
          }
        }
      }
      if (ordersLoaded) {
        for (final o in v) {
          final at = o.receiptAt;
          final before = _receiptSeen[o.id];
          if (at != null &&
              o.paymentStatus != PaymentStatus.paid &&
              (before == null
                  ? !_knownIds.contains(o.id)
                  : at.isAfter(before))) {
            Alerts.show(
              id: 400000 + (o.id.hashCode & 0xffff),
              title: 'Payment receipt received',
              body: '${o.customerName} · ${o.displayNumber} · ${rs(o.total)}',
              payload: 'order:${o.id}',
            );
          }
        }
      }
      for (final o in v) {
        final at = o.receiptAt;
        if (at != null) _receiptSeen[o.id] = at;
      }
      _watchChats(v);
      _knownIds
        ..clear()
        ..addAll(v.map((o) => o.id));
      orders = v;
      ordersLoaded = true;
    });
    listen(backend.riders.watchAllRiders(), (v) => riders = v);
    listen(backend.quotes.watchAll(), (v) => quotes = v);
    listen(backend.catalog.watchAllProducts(), (v) {
      products = v;
      _hasProducts = v.isNotEmpty;
      storeReady = _hasProducts && _hasSettings;
    });
    listen(backend.catalog.watchStoredSettings(), (v) {
      settings = v ?? const AppSettings();
      _hasSettings = v != null;
      storeReady = _hasProducts && _hasSettings;
    });
  }

  void _stopData() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    orders = const [];
    riders = const [];
    quotes = const [];
    products = const [];
    ordersLoaded = false;
    newOrderAlert = null;
    _knownIds.clear();
    for (final s in _chatSubs.values) {
      s.cancel();
    }
    _chatSubs.clear();
    _chatSeen.clear();
    chat.follow(const []);
    KeepAlive.stop();
  }

  void _stop() {
    _adminSub?.cancel();
    _adminSub = null;
    _stopData();
  }

  Future<void> signOut() => backend.auth.signOut();

  @override
  void dispose() {
    chat.dispose();
    backend.auth.removeListener(_onAuth);
    _stop();
    themeMode.dispose();
    super.dispose();
  }
}
