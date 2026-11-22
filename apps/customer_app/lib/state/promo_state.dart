import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/foundation.dart';

import '../l10n/lang.dart';
import '../services/backend.dart';
import 'app_state.dart';

/// Discount code, reward points, invite code, refill plan and the shop's
/// public rating: everything the "extras" of the app need.
class PromoState extends ChangeNotifier {
  PromoState(this._backend, this._app) {
    _app.addListener(_onApp);
    _stats = _backend.promo.watchStats().listen((s) {
      stats = s;
      notifyListeners();
    }, onError: (_) {});
    _onApp();
  }

  final Backend _backend;
  final AppState _app;

  String? _uid;
  StreamSubscription<LoyaltyAccount>? _loyaltySub;
  StreamSubscription<RefillPlan?>? _planSub;
  StreamSubscription<PublicStats>? _stats;

  PublicStats stats = const PublicStats();
  LoyaltyAccount loyalty = const LoyaltyAccount();
  RefillPlan? plan;
  String? referralCode;

  /// The code on the checkout right now (shop coupon or a friend's code).
  Coupon? coupon;
  bool usePoints = false;
  bool checking = false;

  void _onApp() {
    final uid = _app.uid;
    if (uid == _uid) return;
    _loyaltySub?.cancel();
    _planSub?.cancel();
    _uid = uid;
    loyalty = const LoyaltyAccount();
    plan = null;
    referralCode = null;
    clear();
    if (uid == null) {
      notifyListeners();
      return;
    }
    _loyaltySub = _backend.promo.watchLoyalty(uid).listen((l) {
      loyalty = l;
      notifyListeners();
    }, onError: (_) {});
    _planSub = _backend.promo.watchPlan(uid).listen((p) {
      plan = p;
      _app.planDue = p != null && p.active ? p.nextDue : null;
      notifyListeners();
    }, onError: (_) {});
    _backend.promo
        .myReferralCode(uid)
        .then((c) {
          referralCode = c;
          notifyListeners();
        })
        .catchError((_) {});
  }

  /// Forget the code and points (after an order, or when the customer removes them).
  void clear() {
    coupon = null;
    usePoints = false;
    checking = false;
  }

  void removeCode() {
    coupon = null;
    notifyListeners();
  }

  void setUsePoints(bool v) {
    usePoints = v;
    notifyListeners();
  }

  /// Checks a typed code. Returns a message when it cannot be used.
  Future<String?> applyCode(String raw, int subtotal) async {
    final uid = _uid;
    final code = Coupon.clean(raw);
    if (code.isEmpty) return null;
    if (uid == null) return tr('Sign in to use a code.');
    checking = true;
    notifyListeners();
    try {
      if (code.startsWith('REF-')) {
        final owner = await _backend.promo.referralOwner(code);
        if (owner == null) return tr('That invite code is not valid.');
        if (owner == uid) return tr('You cannot use your own invite code.');
        if (await _backend.promo.alreadyUsed(code, uid)) {
          return tr('You already used a friend\'s invite code.');
        }
        coupon = Coupon(
          code: code,
          title: 'Friend discount',
          value: _app.settings.referralDiscount,
        );
        return null;
      }
      final c = await _backend.promo.findCoupon(code);
      if (c == null) return tr('That code is not valid.');
      if (await _backend.promo.alreadyUsed(code, uid)) {
        return tr('You already used this code.');
      }
      final problem = c.problem(subtotal);
      if (problem != null) return tr(problem);
      coupon = c;
      return null;
    } catch (_) {
      return tr('Could not check the code. Check your internet.');
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  /// The prices with the code and points the customer chose.
  PriceBreakdown priced(PriceBreakdown base) {
    final s = _app.settings;
    final cd = coupon == null ? 0 : coupon!.discountFor(base.subtotal);
    final pts = usePoints
        ? PriceBreakdown.maxPoints(base.subtotal, cd, loyalty.points, s)
        : 0;
    return base.withDiscounts(
      couponDiscount: cd,
      pointsUsed: pts,
      pointValue: s.pointValue,
    );
  }

  /// After an order: a due refill plan moves on to its next date.
  void afterOrder() {
    final uid = _uid;
    final p = plan;
    if (uid == null || p == null || !p.isDue()) return;
    _backend.promo
        .savePlan(
          uid,
          p.copyWith(nextDue: DateTime.now().add(Duration(days: p.everyDays))),
        )
        .catchError((_) {});
  }

  @override
  void dispose() {
    _app.removeListener(_onApp);
    _loyaltySub?.cancel();
    _planSub?.cancel();
    _stats?.cancel();
    super.dispose();
  }
}
