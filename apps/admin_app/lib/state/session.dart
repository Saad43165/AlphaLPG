import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alpha_ui/alpha_ui.dart' show Alerts, KeepAlive;

import '../services/backend.dart';
import '../utils/order_x.dart';
import '../utils/payment_checks.dart';

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
  List<CustomerProfile> customers = const [];
  Map<String, BlockedCustomer> blocked = const {};
  List<LedgerEntry> ledger = const [];
  List<CashHandover> handovers = const [];
  List<AuditEntry> auditLog = const [];
  List<ErrorEntry> errorLog = const [];
  List<AdminUser> admins = const [];
  List<OrderReport> reports = const [];
  final _knownReports = <String>{};
  bool _reportsLoaded = false;

  int get openReportCount => reports.where((r) => r.isOpen).length;

  /// Delivered orders this rider was rated on, newest first.
  List<LpgOrder> ratingsOf(String riderId) => [
    for (final o in orders)
      if (o.riderId == riderId && o.rating != null) o,
  ];

  /// Average stars and how many ratings (null when none yet).
  (double, int)? ratingOf(String riderId) {
    final l = ratingsOf(riderId);
    if (l.isEmpty) return null;
    return (l.fold(0, (n, o) => n + o.rating!) / l.length, l.length);
  }

  // ---- Reward points, invite bonuses and the public rating numbers -----------

  final _rewardBusy = <String>{};
  List<Coupon> coupons = const [];
  String _publicStatsKey = '';

  /// Gives points for delivered orders, takes spent points off, gives them back
  /// after a cancel. Each step is done once (the order records that it was).
  void _processRewards(List<LpgOrder> list) {
    if (isAdmin != true) return;
    for (final o in list) {
      if (_rewardBusy.contains(o.id)) continue;
      Future<void>? job;
      final deliveredAt = o.timeOf(OrderStatus.delivered) ?? o.updatedAt;
      if (o.status == OrderStatus.delivered &&
          o.rewardedAt == null &&
          settings.pointsEnabled &&
          deliveredAt != null &&
          deliveredAt.millisecondsSinceEpoch >= settings.pointsSince) {
        job = _award(o);
      } else if (o.pointsUsed > 0 &&
          o.pointsSettledAt == null &&
          o.status != OrderStatus.cancelled) {
        job = backend.promo.settleSpent(o);
      } else if (o.status == OrderStatus.cancelled &&
          o.pointsSettledAt != null &&
          o.pointsRefundedAt == null) {
        job = backend.promo.refundSpent(o);
      }
      if (job == null) continue;
      _rewardBusy.add(o.id);
      job.catchError((_) {}).whenComplete(() => _rewardBusy.remove(o.id));
    }
  }

  Future<void> _award(LpgOrder o) async {
    final points = o.total ~/ 100 * settings.pointsPerHundred;
    String? referrer;
    if (o.couponCode.startsWith('REF-')) {
      referrer = await backend.promo.referralOwner(o.couponCode);
    }
    await backend.promo.awardDelivery(
      o,
      points: points,
      referrerUid: referrer,
      referrerPoints: referrer == null ? 0 : settings.referralBonusPoints,
    );
  }

  /// "4.8 stars from 120 reviews": the home screen of the customer app.
  void _publishPublicStats(List<LpgOrder> list) {
    if (isAdmin != true) return;
    final rated = [
      for (final o in list)
        if (o.status == OrderStatus.delivered && o.rating != null) o.rating!,
    ];
    final delivered = list
        .where((o) => o.status == OrderStatus.delivered)
        .length;
    final avg = rated.isEmpty
        ? 0.0
        : rated.fold(0, (a, b) => a + b) / rated.length;
    final key = '${avg.toStringAsFixed(2)}/${rated.length}/$delivered';
    if (key == _publicStatsKey) return;
    _publicStatsKey = key;
    backend.promo
        .publishStats(
          PublicStats(
            ratingAverage: avg,
            ratingCount: rated.length,
            deliveredCount: delivered,
          ),
        )
        .catchError((_) {});
  }

  /// Removes receipt and delivery pictures of finished orders older than
  /// [days]. Returns how many were removed, or an error message.
  Future<(int, String?)> archiveOldPhotos(int days) async {
    var total = 0;
    try {
      final before = DateTime.now().subtract(Duration(days: days));
      for (var i = 0; i < 25; i++) {
        final n = await backend.orders.archiveOldPhotos(before);
        total += n;
        if (n == 0) break;
      }
      _audit(
        'Cleared old photos',
        detail: '$total removed (older than $days days)',
      );
      return (total, null);
    } catch (e) {
      return (total, _friendly(e));
    }
  }

  Future<String?> saveCoupon(Coupon c) => _run(() async {
    await backend.promo.saveCoupon(c);
    _audit('Saved coupon', target: c.code);
  });

  Future<String?> deleteCoupon(Coupon c) => _run(() async {
    await backend.promo.deleteCoupon(c.code);
    _audit('Deleted coupon', target: c.code);
  });

  final _publishedStats = <String, String>{};

  /// Customers see each rider's stars; keep the public copy up to date.
  void _publishRiderStats() {
    for (final r in riders) {
      final st = ratingOf(r.uid);
      if (st == null) continue;
      final key = '${st.$1.toStringAsFixed(2)}/${st.$2}';
      if (_publishedStats[r.uid] == key) continue;
      _publishedStats[r.uid] = key;
      backend.orders
          .saveRiderStats(r.uid, double.parse(st.$1.toStringAsFixed(2)), st.$2)
          .catchError((_) {});
    }
  }

  /// This signed-in admin's record (null = the original owner / custom claim).
  AdminUser? me;

  /// Owners can do everything; staff cannot change settings, delete products,
  /// cancel paid orders or manage admins.
  bool get isOwner => me?.isOwner ?? true;
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

  /// Orders being delivered now (a scheduled order joins when its day comes).
  List<LpgOrder> get activeOrders => [
    for (final o in orders)
      if ((o.status == OrderStatus.confirmed ||
              o.status == OrderStatus.assigned ||
              o.status == OrderStatus.outForDelivery) &&
          !o.isUpcoming())
        o,
  ];
  int get activeCount => activeOrders.length;

  /// Scheduled orders whose day has not come yet, soonest first.
  List<LpgOrder> get upcomingOrders => [
    for (final o in orders)
      if (o.isUpcoming()) o,
  ]..sort((a, b) => a.scheduledFor!.compareTo(b.scheduledFor!));

  /// Scheduled orders for the next 24 hours.
  int get scheduledSoonCount => upcomingOrders
      .where(
        (o) => o.scheduledFor!.isBefore(
          DateTime.now().add(const Duration(hours: 24)),
        ),
      )
      .length;

  /// Online orders where the customer has sent a receipt to check.
  int get receiptsToCheckCount =>
      orders.where((o) => o.awaitingPaymentCheck && o.receiptAt != null).length;

  /// Online orders where the shop still has to send its account details.
  int get needDetailsCount =>
      orders.where((o) => o.payStage == PayStage.sendDetails).length;

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

  /// Writes who-did-what for the owner. Never blocks or fails the action.
  void _audit(String action, {String target = '', String detail = ''}) {
    final id = uid;
    if (id == null) return;
    backend.ops
        .addAudit(
          AuditEntry(
            by: id,
            byName: me?.name.isNotEmpty == true
                ? me!.name
                : (backend.auth.email ?? 'Owner'),
            action: action,
            target: target,
            detail: detail,
          ),
        )
        .catchError((_) {});
  }

  /// Takes (or gives back) counted stock for an order's cylinders.
  Future<void> _stock(LpgOrder o, int sign) async {
    for (final i in o.items) {
      try {
        await backend.catalog.adjustStock(i.productId, sign * i.quantity);
      } catch (_) {}
    }
  }

  Future<String?> confirm(LpgOrder o) => _run(() async {
    await backend.orders.updateStatus(o.id, OrderStatus.confirmed, uid!);
    await _stock(o, -1);
    _audit('Confirmed order', target: o.displayNumber);
  });

  Future<String?> assign(LpgOrder o, RiderProfile r) => _run(() async {
    if (!r.isLive()) {
      throw StateError(
        '${r.name} is offline. Only riders on shift can get orders.',
      );
    }
    await backend.orders.assignRider(
      o.id,
      uid!,
      riderId: r.uid,
      name: r.name,
      phone: r.phone,
    );
    _audit('Assigned rider', target: o.displayNumber, detail: r.name);
  });

  Future<String?> cancel(LpgOrder o, String reason) => _run(() async {
    await backend.orders.updateStatus(
      o.id,
      OrderStatus.cancelled,
      uid!,
      note: reason,
    );
    // Stock was taken when the order was confirmed.
    if (o.status != OrderStatus.placed) await _stock(o, 1);
    _audit('Cancelled order', target: o.displayNumber, detail: reason);
  });

  Future<String?> markDelivered(LpgOrder o) => _run(() async {
    await backend.orders.updateStatus(o.id, OrderStatus.delivered, uid!);
    _audit('Marked delivered', target: o.displayNumber);
  });

  Future<String?> markPaid(LpgOrder o) => _run(() async {
    await backend.orders.markPaid(o.id, uid!);
    _audit(
      'Marked paid',
      target: o.displayNumber,
      detail:
          '${o.paymentMethod.label} · Rs ${o.total} · TID ${o.paymentReference}',
    );
  });

  Future<String?> sendPaymentRequest(LpgOrder o, PaymentRequest r) =>
      _run(() async {
        await backend.orders.sendPaymentRequest(o.id, r);
        _audit(
          'Sent payment details',
          target: o.displayNumber,
          detail: '${r.method.label} · ${r.account}',
        );
      });

  /// Tell the customer what is wrong with their payment ('' clears it).
  Future<String?> setPaymentIssue(LpgOrder o, String issue) =>
      _run(() => backend.orders.setPaymentIssue(o.id, issue));

  Future<String?> setCustomerBlocked(
    CustomerProfile c, {
    required bool blocked,
    String reason = '',
  }) => _run(() async {
    await backend.profiles.setBlocked(c, blocked: blocked, reason: reason);
    _audit(
      blocked ? 'Blocked customer' : 'Unblocked customer',
      target: '${c.name} ${c.phone}',
      detail: reason,
    );
  });

  /// Deposit / empty-cylinder line for a customer.
  Future<String?> addLedger(
    CustomerProfile c,
    LedgerKind kind, {
    int amount = 0,
    int empties = 0,
    String note = '',
  }) => _run(() async {
    await backend.ops.addLedger(
      LedgerEntry(
        customerId: c.uid,
        customerName: c.name,
        kind: kind,
        amount: amount,
        empties: empties,
        note: note,
        by: uid!,
      ),
    );
    _audit(
      kind.label,
      target: c.name,
      detail: amount > 0 ? 'Rs $amount' : '$empties cylinder(s)',
    );
  });

  /// A rider hands in cash.
  Future<String?> addHandover(RiderProfile r, int amount, {String note = ''}) =>
      _run(() async {
        await backend.ops.addHandover(
          CashHandover(
            riderId: r.uid,
            riderName: r.name,
            amount: amount,
            note: note,
            by: uid!,
          ),
        );
        _audit(
          'Cash received from rider',
          target: r.name,
          detail: 'Rs $amount',
        );
      });

  /// Creates a staff login (email + password) with limited powers.
  Future<String?> addStaff({
    required String name,
    required String email,
    required String password,
  }) => _run(() async {
    final staffUid = await backend.createRiderLogin(email, password);
    await backend.ops.saveAdmin(
      AdminUser(uid: staffUid, email: email, name: name, role: 'staff'),
    );
    _audit('Added staff', target: name, detail: email);
  });

  Future<String?> removeStaff(AdminUser a) => _run(() async {
    await backend.ops.removeAdmin(a.uid);
    _audit('Removed staff', target: a.name, detail: a.email);
  });

  Future<String?> resolveReport(
    OrderReport r, {
    required String reply,
    bool resolved = true,
    String refund = 'none',
  }) => _run(() async {
    await backend.orders.resolveReport(
      r.id,
      reply: reply,
      resolved: resolved,
      refund: refund,
    );
    _audit(
      resolved ? 'Resolved customer report' : 'Reopened customer report',
      target: r.orderNumber,
      detail: reply,
    );
  });

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

  Future<String?> saveSettings(AppSettings s) => _run(() async {
    await backend.catalog.saveSettings(s);
    _audit('Changed shop settings');
  });
  Future<String?> loadDefaults() => _run(backend.catalog.seed);

  Future<String?> setQuoteStatus(QuoteRequest q, String status) =>
      _run(() => backend.quotes.setStatus(q.id, status));

  /// Sends the rate / details to the customer inside the app.
  Future<String?> sendQuoteReply(QuoteRequest q, String text) {
    return _run(() async {
      await backend.quotes.sendReply(q.id, text);
      _audit('Replied to bulk quote', target: q.businessName);
    });
  }

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
  Future<String?> setRiderOnline(RiderProfile r, bool online) => online
      ? _run(() => backend.riders.setOnline(r.uid, true))
      : switchRiderOffline(r);

  /// Ends a rider's shift from here. They are told in their app.
  Future<String?> switchRiderOffline(RiderProfile r) {
    final n = jobsOf(r.uid).where((o) => !o.isUpcoming()).length;
    if (n > 0) {
      return Future.value(
        '${r.name} is carrying $n order${n == 1 ? '' : 's'}. Take them back first, or wait until they are delivered.',
      );
    }
    return _run(() => backend.riders.setOnline(r.uid, false));
  }

  Future<String?> switchAllRidersOffline() async {
    final skipped = <String>[];
    final err = await _run(() async {
      for (final r in riders.where((r) => r.online)) {
        if (jobsOf(r.uid).any((o) => !o.isUpcoming())) {
          skipped.add(r.name);
          continue;
        }
        await backend.riders.setOnline(r.uid, false);
      }
    });
    if (err != null) return err;
    return skipped.isEmpty
        ? null
        : 'Switched off everyone except ${skipped.join(', ')}: they are carrying orders.';
  }

  /// Change a rider's name, phone or vehicle.
  Future<String?> editRider(
    RiderProfile r, {
    required String name,
    required String phone,
    required String vehicle,
    int capacity = 0,
  }) => _run(
    () => backend.riders.saveRider(
      RiderProfile(
        uid: r.uid,
        name: name,
        phone: phone,
        vehicle: vehicle,
        active: r.active,
        online: r.online,
        capacity: capacity,
      ),
    ),
  );

  /// Riders carrying an order whose phone has not reported for a while.
  List<RiderProfile> get silentRiders {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    return [
      for (final r in riders)
        if (r.active &&
            jobsOf(r.uid).isNotEmpty &&
            (r.lastSeen == null || r.lastSeen!.isBefore(cutoff)))
          r,
    ];
  }

  /// Online orders where the customer got the account details more than an
  /// hour ago and has still sent nothing.
  List<LpgOrder> get unpaidAfterDetails {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    return [
      for (final o in orders)
        if (o.paymentMethod.isPrepaid &&
            o.paymentStatus == PaymentStatus.pending &&
            o.status != OrderStatus.cancelled &&
            o.status != OrderStatus.delivered &&
            o.receiptAt == null &&
            o.paymentRequest?.sentAt != null &&
            o.paymentRequest!.sentAt!.isBefore(cutoff))
          o,
    ];
  }

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
  Future<String?> unassign(LpgOrder o) => _run(() async {
    if (o.status != OrderStatus.assigned) {
      throw StateError(
        'Only an order the rider has not started can be taken back.',
      );
    }
    await backend.orders.unassignRider(o.id, uid!);
    _audit(
      'Took order back from rider',
      target: o.displayNumber,
      detail: o.riderName ?? '',
    );
  });

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
    if (e is StateError) return e.message;
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
    // Chat only exists while an order is open.
    final active = [
      for (final o in list)
        if (o.status.isActive) o,
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

  final _waitAlerted = <String>{};
  Timer? _waitTimer;

  /// A customer with no delivered order yet: call them once to confirm the
  /// order before the first delivery.
  bool isNewCustomer(LpgOrder o) =>
      (o.status == OrderStatus.placed ||
          o.status == OrderStatus.confirmed ||
          o.status == OrderStatus.assigned) &&
      !orders.any(
        (x) =>
            x.customerId == o.customerId && x.status == OrderStatus.delivered,
      );

  /// Orders nobody has taken for [waitingMinutes] or more.
  static const waitingMinutes = 10;
  List<LpgOrder> get waitingForRider {
    final cutoff = DateTime.now().subtract(
      const Duration(minutes: waitingMinutes),
    );
    return [
      for (final o in orders)
        if ((o.status == OrderStatus.placed ||
                o.status == OrderStatus.confirmed) &&
            o.riderId == null &&
            !o.isUpcoming() &&
            // A scheduled order starts waiting when its window opens.
            (o.isScheduled
                ? o.scheduledFor!
                      .subtract(LpgOrder.scheduleLead)
                      .isBefore(cutoff)
                : (o.createdAt != null && o.createdAt!.isBefore(cutoff))))
          o,
    ];
  }

  int _lastWaiting = 0;

  void _checkWaiting() {
    final late = waitingForRider;
    for (final o in late) {
      if (_waitAlerted.add(o.id)) {
        Alerts.show(
          id: 500000 + (o.id.hashCode & 0xffff),
          title: 'No rider yet · ${o.displayNumber}',
          body:
              '${o.customerName} has waited $waitingMinutes+ minutes. Assign a rider.',
          payload: 'order:${o.id}',
        );
      }
    }
    // Repaint only when the list of waiting orders changed.
    if (late.length != _lastWaiting) {
      _lastWaiting = late.length;
      notifyListeners();
    }
  }

  // Payment warnings are worked out once per orders update, not per tile.
  List<LpgOrder>? _warnFor;
  Set<String> _warned = const {};

  /// Orders that have something worth checking before marking them paid.
  bool hasPaymentWarning(LpgOrder o) {
    if (!identical(_warnFor, orders)) {
      _warnFor = orders;
      _warned = {
        for (final x in orders)
          if (x.awaitingPaymentCheck && paymentWarnings(x, orders).isNotEmpty)
            x.id,
      };
    }
    return _warned.contains(o.id);
  }

  void _startData() {
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkWaiting(),
    );
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
    // Owner-only data: quietly ignored for staff (the rules refuse it).
    void quiet<T>(Stream<T> st, void Function(T) on) => _subs.add(
      st.listen((v) {
        on(v);
        notifyListeners();
      }, onError: (_) {}),
    );
    listen(backend.orders.watchRecent(), (v) {
      // After the first load, a placed order we have not seen is "new".
      if (ordersLoaded) {
        for (final o in v) {
          if (o.status == OrderStatus.placed && !_knownIds.contains(o.id)) {
            newOrderAlert = o;
            Alerts.show(
              id: 200 + (o.id.hashCode & 0xffff),
              title: o.isScheduled
                  ? 'Scheduled order · ${rs(o.total)} · ${DateFormat('EEE d MMM').format(o.scheduledFor!)} ${o.slotText}'
                  : o.paymentMethod.isPrepaid
                  ? 'New order · ${rs(o.total)} · send ${o.paymentMethod.label} details'
                  : 'New order · ${rs(o.total)}',
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
      _publishRiderStats();
      _processRewards(v);
      _publishPublicStats(v);
      ordersLoaded = true;
    });
    quiet(backend.promo.watchCoupons(), (v) {
      coupons = v;
    });
    listen(backend.riders.watchAllRiders(), (v) {
      riders = v;
      _publishRiderStats();
    });
    quiet(backend.orders.watchReports(), (v) {
      if (_reportsLoaded) {
        for (final r in v) {
          if (!_knownReports.contains(r.id)) {
            Alerts.show(
              id: 600000 + (r.id.hashCode & 0xffff),
              title: r.fromRider
                  ? 'Rider problem · ${r.orderNumber}'
                  : r.aboutRider
                  ? 'Rider reported · ${r.orderNumber}'
                  : 'Problem reported · ${r.orderNumber}',
              body: r.fromRider
                  ? '${r.riderName ?? 'Rider'}: ${r.reason}'
                  : '${r.customerName}: ${r.reason}',
              payload: 'order:${r.orderId}',
            );
          }
        }
      }
      _reportsLoaded = true;
      _knownReports
        ..clear()
        ..addAll(v.map((r) => r.id));
      reports = v;
    });
    listen(backend.profiles.watchCustomers(), (v) => customers = v);
    listen(backend.ops.watchLedger(), (v) => ledger = v);
    listen(backend.ops.watchHandovers(), (v) => handovers = v);
    listen(backend.ops.watchErrors(), (v) => errorLog = v);
    listen(backend.ops.watchAdmin(uid!), (v) => me = v);
    quiet(backend.ops.watchAudit(), (v) => auditLog = v);
    quiet(backend.ops.watchAdmins(), (v) => admins = v);
    listen(backend.profiles.watchAllBlocked(), (v) {
      blocked = {for (final b in v) b.uid: b};
    });
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
      _processRewards(orders);
    });
  }

  void _stopData() {
    _waitTimer?.cancel();
    _waitTimer = null;
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
