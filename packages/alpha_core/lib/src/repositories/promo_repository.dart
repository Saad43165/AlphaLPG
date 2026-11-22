import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';
import '../models/order.dart';
import '../models/promo.dart';
import 'memory_store.dart';

/// A customer's personal "invite a friend" code. Always the same for the same
/// account, so it never needs to be looked up first.
String referralCodeFor(String uid) {
  var h = 0x811C9DC5;
  for (final c in uid.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
  }
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final b = StringBuffer('REF-');
  for (var i = 0; i < 6; i++) {
    b.write(letters[h % letters.length]);
    h = (h ~/ letters.length) ^ (h << 3 & 0xFFFFFFFF);
    h &= 0xFFFFFFFF;
  }
  return b.toString();
}

/// Discount codes, reward points, invite codes, the public rating numbers and
/// refill plans. Points are only ever changed by the shop's app.
abstract interface class PromoRepository {
  factory PromoRepository.firestore(FirebaseFirestore db) = _FirestorePromo;
  factory PromoRepository.memory(MemoryStore store) = _MemoryPromo;

  /// A code the shop made, or null when there is none like it.
  Future<Coupon?> findCoupon(String code);

  /// Has this customer already used [code]?
  Future<bool> alreadyUsed(String code, String uid);

  /// Whose invite code this is (null if nobody's).
  Future<String?> referralOwner(String code);

  /// This customer's invite code (made on first use).
  Future<String> myReferralCode(String uid);

  Stream<List<Coupon>> watchCoupons();
  Future<void> saveCoupon(Coupon c);
  Future<void> deleteCoupon(String code);

  Stream<LoyaltyAccount> watchLoyalty(String uid);
  Stream<List<LoyaltyEntry>> watchLoyaltyEntries(String uid);

  /// Shop: give points for a delivered order (once), and the friend bonus.
  Future<void> awardDelivery(
    LpgOrder o, {
    required int points,
    String? referrerUid,
    int referrerPoints = 0,
  });

  /// Shop: take the points a customer spent on this order off the balance.
  Future<void> settleSpent(LpgOrder o);

  /// Shop: give spent points back after the order was cancelled.
  Future<void> refundSpent(LpgOrder o);

  Stream<PublicStats> watchStats();
  Future<void> publishStats(PublicStats s);

  Stream<RefillPlan?> watchPlan(String uid);
  Future<void> savePlan(String uid, RefillPlan p);
  Future<void> deletePlan(String uid);
}

class _FirestorePromo implements PromoRepository {
  _FirestorePromo(this._db);
  final FirebaseFirestore _db;

  @override
  Future<Coupon?> findCoupon(String code) async {
    final d = await _db.collection(FirestorePaths.coupons).doc(code).get();
    return d.exists ? Coupon.fromMap(d.id, d.data()!) : null;
  }

  @override
  Future<bool> alreadyUsed(String code, String uid) async =>
      (await _db.doc(FirestorePaths.couponUse(code, uid)).get()).exists;

  @override
  Future<String?> referralOwner(String code) async {
    final d = await _db
        .collection(FirestorePaths.referralCodes)
        .doc(code)
        .get();
    return d.data()?['uid'] as String?;
  }

  @override
  Future<String> myReferralCode(String uid) async {
    final code = referralCodeFor(uid);
    final ref = _db.collection(FirestorePaths.referralCodes).doc(code);
    try {
      if (!(await ref.get()).exists) {
        await ref.set({'uid': uid, 'at': FieldValue.serverTimestamp()});
      }
    } catch (_) {
      // Shown anyway; it is registered the next time the app has a connection.
    }
    return code;
  }

  @override
  Stream<List<Coupon>> watchCoupons() => _db
      .collection(FirestorePaths.coupons)
      .snapshots()
      .map(
        (s) =>
            [for (final d in s.docs) Coupon.fromMap(d.id, d.data())]
              ..sort((a, b) => a.code.compareTo(b.code)),
      );

  @override
  Future<void> saveCoupon(Coupon c) =>
      _db.collection(FirestorePaths.coupons).doc(c.code).set(c.toMap());

  @override
  Future<void> deleteCoupon(String code) =>
      _db.collection(FirestorePaths.coupons).doc(code).delete();

  @override
  Stream<LoyaltyAccount> watchLoyalty(String uid) => _db
      .doc(FirestorePaths.loyalty(uid))
      .snapshots()
      .map((d) => LoyaltyAccount.fromMap(d.data() ?? const {}));

  @override
  Stream<List<LoyaltyEntry>> watchLoyaltyEntries(String uid) => _db
      .collection(FirestorePaths.loyaltyEntries(uid))
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) LoyaltyEntry.fromMap(d.data())]
          ..sort(
            (a, b) =>
                (b.at ?? DateTime.now()).compareTo(a.at ?? DateTime.now()),
          ),
      );

  Future<void> _move(
    String uid,
    int delta,
    String reason,
    String orderId,
    Transaction tx,
    int currentPoints,
    int currentLifetime,
  ) async {
    final ref = _db.doc(FirestorePaths.loyalty(uid));
    final next = currentPoints + delta;
    tx.set(ref, {
      'points': next < 0 ? 0 : next,
      'lifetime': currentLifetime + (delta > 0 ? delta : 0),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    tx.set(_db.collection(FirestorePaths.loyaltyEntries(uid)).doc(), {
      'delta': delta,
      'reason': reason,
      'orderId': orderId,
      'at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> awardDelivery(
    LpgOrder o, {
    required int points,
    String? referrerUid,
    int referrerPoints = 0,
  }) => _db.runTransaction((tx) async {
    final oRef = _db.collection(FirestorePaths.orders).doc(o.id);
    final order = await tx.get(oRef);
    if (order.data()?['rewardedAt'] != null) return;
    final mine = await tx.get(_db.doc(FirestorePaths.loyalty(o.customerId)));
    final theirs = referrerUid == null || referrerPoints <= 0
        ? null
        : await tx.get(_db.doc(FirestorePaths.loyalty(referrerUid)));
    tx.update(oRef, {'rewardedAt': FieldValue.serverTimestamp()});
    if (points > 0) {
      await _move(
        o.customerId,
        points,
        'Delivery ${o.displayNumber}',
        o.id,
        tx,
        (mine.data()?['points'] as num?)?.toInt() ?? 0,
        (mine.data()?['lifetime'] as num?)?.toInt() ?? 0,
      );
    }
    if (theirs != null) {
      await _move(
        referrerUid!,
        referrerPoints,
        'A friend you invited got their first delivery',
        o.id,
        tx,
        (theirs.data()?['points'] as num?)?.toInt() ?? 0,
        (theirs.data()?['lifetime'] as num?)?.toInt() ?? 0,
      );
    }
  });

  @override
  Future<void> settleSpent(LpgOrder o) => _db.runTransaction((tx) async {
    final oRef = _db.collection(FirestorePaths.orders).doc(o.id);
    final order = await tx.get(oRef);
    if (order.data()?['pointsSettledAt'] != null) return;
    final mine = await tx.get(_db.doc(FirestorePaths.loyalty(o.customerId)));
    tx.update(oRef, {'pointsSettledAt': FieldValue.serverTimestamp()});
    await _move(
      o.customerId,
      -o.pointsUsed,
      'Used on order ${o.displayNumber}',
      o.id,
      tx,
      (mine.data()?['points'] as num?)?.toInt() ?? 0,
      (mine.data()?['lifetime'] as num?)?.toInt() ?? 0,
    );
  });

  @override
  Future<void> refundSpent(LpgOrder o) => _db.runTransaction((tx) async {
    final oRef = _db.collection(FirestorePaths.orders).doc(o.id);
    final order = await tx.get(oRef);
    final d = order.data();
    if (d == null ||
        d['pointsSettledAt'] == null ||
        d['pointsRefundedAt'] != null) {
      return;
    }
    final mine = await tx.get(_db.doc(FirestorePaths.loyalty(o.customerId)));
    tx.update(oRef, {'pointsRefundedAt': FieldValue.serverTimestamp()});
    await _move(
      o.customerId,
      o.pointsUsed,
      'Order ${o.displayNumber} was cancelled: points returned',
      o.id,
      tx,
      (mine.data()?['points'] as num?)?.toInt() ?? 0,
      (mine.data()?['lifetime'] as num?)?.toInt() ?? 0,
    );
  });

  @override
  Stream<PublicStats> watchStats() => _db
      .doc(FirestorePaths.statsDoc)
      .snapshots()
      .map((d) => PublicStats.fromMap(d.data() ?? const {}));

  @override
  Future<void> publishStats(PublicStats s) => _db
      .doc(FirestorePaths.statsDoc)
      .set({...s.toMap(), 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Stream<RefillPlan?> watchPlan(String uid) => _db
      .collection(FirestorePaths.plans)
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? RefillPlan.fromMap(d.data()!) : null);

  @override
  Future<void> savePlan(String uid, RefillPlan p) =>
      _db.collection(FirestorePaths.plans).doc(uid).set(p.toMap());

  @override
  Future<void> deletePlan(String uid) =>
      _db.collection(FirestorePaths.plans).doc(uid).delete();
}

class _MemoryPromo implements PromoRepository {
  _MemoryPromo(this._s);
  final MemoryStore _s;

  @override
  Future<Coupon?> findCoupon(String code) async {
    final d = _s.get(FirestorePaths.coupons, code);
    return d == null ? null : Coupon.fromMap(code, d);
  }

  @override
  Future<bool> alreadyUsed(String code, String uid) async {
    final path = FirestorePaths.couponUse(code, uid);
    final i = path.lastIndexOf('/');
    return _s.get(path.substring(0, i), path.substring(i + 1)) != null;
  }

  @override
  Future<String?> referralOwner(String code) async =>
      _s.get(FirestorePaths.referralCodes, code)?['uid'] as String?;

  @override
  Future<String> myReferralCode(String uid) async {
    final code = referralCodeFor(uid);
    _s.set(FirestorePaths.referralCodes, code, {
      'uid': uid,
      'at': DateTime.now(),
    });
    return code;
  }

  @override
  Stream<List<Coupon>> watchCoupons() => _s.watch(
    FirestorePaths.coupons,
    (docs) =>
        [for (final e in docs.entries) Coupon.fromMap(e.key, e.value)]
          ..sort((a, b) => a.code.compareTo(b.code)),
  );

  @override
  Future<void> saveCoupon(Coupon c) async =>
      _s.set(FirestorePaths.coupons, c.code, c.toMap());

  @override
  Future<void> deleteCoupon(String code) async =>
      _s.delete(FirestorePaths.coupons, code);

  @override
  Stream<LoyaltyAccount> watchLoyalty(String uid) => _s.watch(
    'loyalty',
    (docs) => LoyaltyAccount.fromMap(docs[uid] ?? const {}),
  );

  @override
  Stream<List<LoyaltyEntry>> watchLoyaltyEntries(String uid) => _s.watch(
    FirestorePaths.loyaltyEntries(uid),
    (docs) => [for (final d in docs.values) LoyaltyEntry.fromMap(d)]
      ..sort(
        (a, b) => (b.at ?? DateTime.now()).compareTo(a.at ?? DateTime.now()),
      ),
  );

  void _move(String uid, int delta, String reason, String orderId) {
    final cur = _s.get('loyalty', uid) ?? const {};
    final p = (cur['points'] as num?)?.toInt() ?? 0;
    final life = (cur['lifetime'] as num?)?.toInt() ?? 0;
    final next = p + delta;
    _s.set('loyalty', uid, {
      'points': next < 0 ? 0 : next,
      'lifetime': life + (delta > 0 ? delta : 0),
    });
    _s.set(FirestorePaths.loyaltyEntries(uid), _s.newId(), {
      'delta': delta,
      'reason': reason,
      'orderId': orderId,
      'at': DateTime.now(),
    });
  }

  @override
  Future<void> awardDelivery(
    LpgOrder o, {
    required int points,
    String? referrerUid,
    int referrerPoints = 0,
  }) async {
    final d = _s.get(FirestorePaths.orders, o.id);
    if (d == null || d['rewardedAt'] != null) return;
    _s.set(FirestorePaths.orders, o.id, {...d, 'rewardedAt': DateTime.now()});
    if (points > 0)
      _move(o.customerId, points, 'Delivery ${o.displayNumber}', o.id);
    if (referrerUid != null && referrerPoints > 0) {
      _move(
        referrerUid,
        referrerPoints,
        'A friend you invited got their first delivery',
        o.id,
      );
    }
  }

  @override
  Future<void> settleSpent(LpgOrder o) async {
    final d = _s.get(FirestorePaths.orders, o.id);
    if (d == null || d['pointsSettledAt'] != null) return;
    _s.set(FirestorePaths.orders, o.id, {
      ...d,
      'pointsSettledAt': DateTime.now(),
    });
    _move(
      o.customerId,
      -o.pointsUsed,
      'Used on order ${o.displayNumber}',
      o.id,
    );
  }

  @override
  Future<void> refundSpent(LpgOrder o) async {
    final d = _s.get(FirestorePaths.orders, o.id);
    if (d == null ||
        d['pointsSettledAt'] == null ||
        d['pointsRefundedAt'] != null) {
      return;
    }
    _s.set(FirestorePaths.orders, o.id, {
      ...d,
      'pointsRefundedAt': DateTime.now(),
    });
    _move(
      o.customerId,
      o.pointsUsed,
      'Order ${o.displayNumber} was cancelled: points returned',
      o.id,
    );
  }

  @override
  Stream<PublicStats> watchStats() => _s.watch(
    'stats',
    (docs) => PublicStats.fromMap(docs['public'] ?? const {}),
  );

  @override
  Future<void> publishStats(PublicStats s) async =>
      _s.set('stats', 'public', s.toMap());

  @override
  Stream<RefillPlan?> watchPlan(String uid) => _s.watch(
    FirestorePaths.plans,
    (docs) => docs[uid] == null ? null : RefillPlan.fromMap(docs[uid]!),
  );

  @override
  Future<void> savePlan(String uid, RefillPlan p) async =>
      _s.set(FirestorePaths.plans, uid, p.toMap());

  @override
  Future<void> deletePlan(String uid) async =>
      _s.delete(FirestorePaths.plans, uid);
}
