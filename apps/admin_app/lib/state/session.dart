import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

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
    _onAuth();
  }

  final AdminBackend backend;
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

  int get newCount => orders.where((o) => o.status == OrderStatus.placed).length;
  int get activeCount => orders
      .where(
        (o) =>
            o.status == OrderStatus.confirmed ||
            o.status == OrderStatus.assigned ||
            o.status == OrderStatus.outForDelivery,
      )
      .length;
  int get toVerifyCount => orders.where((o) => o.awaitingPaymentCheck).length;

  Iterable<LpgOrder> get _deliveredToday => orders.where(
    (o) =>
        o.status == OrderStatus.delivered &&
        (o.timeOf(OrderStatus.delivered) ?? o.updatedAt ?? DateTime(0))
            .isAfter(_today),
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

  Future<String?> confirm(LpgOrder o) =>
      _run(() => backend.orders.updateStatus(o.id, OrderStatus.confirmed, uid!));

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

  Future<String?> markDelivered(LpgOrder o) =>
      _run(() => backend.orders.updateStatus(o.id, OrderStatus.delivered, uid!));

  Future<String?> markPaid(LpgOrder o) =>
      _run(() => backend.orders.markPaid(o.id, uid!));

  Future<String?> saveProduct(Product p) =>
      _run(() => backend.catalog.saveProduct(p));
  Future<String?> saveSettings(AppSettings s) =>
      _run(() => backend.catalog.saveSettings(s));
  Future<String?> loadDefaults() => _run(backend.catalog.seed);

  Future<String?> setQuoteStatus(QuoteRequest q, String status) =>
      _run(() => backend.quotes.setStatus(q.id, status));

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
    return e is Exception && s.startsWith('Exception: ')
        ? s.substring(11)
        : s;
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

  void _startData() {
    void listen<T>(Stream<T> s, void Function(T) on) => _subs.add(
      s.listen((v) {
        on(v);
        notifyListeners();
      }, onError: (Object e) {
        error = _friendly(e);
        notifyListeners();
      }),
    );
    listen(backend.orders.watchRecent(), (v) {
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
  }

  void _stop() {
    _adminSub?.cancel();
    _adminSub = null;
    _stopData();
  }

  Future<void> signOut() => backend.auth.signOut();

  @override
  void dispose() {
    backend.auth.removeListener(_onAuth);
    _stop();
    themeMode.dispose();
    super.dispose();
  }
}
