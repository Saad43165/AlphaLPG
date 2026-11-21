import 'package:cloud_firestore/cloud_firestore.dart';

import '../dates.dart';
import '../firestore_paths.dart';
import '../models/rider.dart';
import 'memory_store.dart';

abstract interface class RiderRepository {
  factory RiderRepository.firestore(FirebaseFirestore db) = _FirestoreRiders;
  factory RiderRepository.memory(MemoryStore store) = _MemoryRiders;

  /// Null when this account is not set up as a rider.
  Stream<RiderProfile?> watchRider(String uid);

  /// Goes on or off shift. The rider does this for themselves; the shop can
  /// also switch a rider off. Also updates the public presence record.
  Future<void> setOnline(String uid, bool online);

  /// "Still here": called every minute while a rider is online, so customers
  /// and the shop know the rider's app is really running.
  Future<void> heartbeat(String uid);

  /// Owner / admin only (enforced by security rules).
  Future<void> saveRider(RiderProfile rider);
  Stream<List<RiderProfile>> watchAllRiders();

  /// Admin: switch a rider's account on or off (off also ends their shift).
  Future<void> setActive(String uid, bool active);

  /// Admin: removes the rider record (the login itself stays in Firebase Auth
  /// but can no longer open the rider app).
  Future<void> deleteRider(String uid);

  /// How many riders are really on shift right now (online and recently seen).
  /// Public: the customer app uses it, and it reveals no personal details.
  Stream<int> watchLiveRiderCount();
}

bool _fresh(Object? lastSeen, [DateTime? now]) {
  final t = readDate(lastSeen);
  return t != null &&
      (now ?? DateTime.now()).difference(t) < const Duration(minutes: 3);
}

class _FirestoreRiders implements RiderRepository {
  _FirestoreRiders(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.riders);
  CollectionReference<Map<String, dynamic>> get _presence =>
      _db.collection(FirestorePaths.presence);

  @override
  Stream<RiderProfile?> watchRider(String uid) => _col
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? RiderProfile.fromMap(d.id, d.data()!) : null);

  @override
  Future<void> setOnline(String uid, bool online) async {
    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();
    batch.update(_col.doc(uid), {'online': online, 'lastSeen': now});
    batch.set(_presence.doc(uid), {'online': online, 'lastSeen': now});
    await batch.commit();
  }

  @override
  Future<void> heartbeat(String uid) async {
    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();
    batch.update(_col.doc(uid), {'lastSeen': now});
    batch.set(_presence.doc(uid), {'online': true, 'lastSeen': now});
    await batch.commit();
  }

  @override
  Future<void> saveRider(RiderProfile r) =>
      _col.doc(r.uid).set(r.toMap(), SetOptions(merge: true));

  @override
  Future<void> setActive(String uid, bool active) async {
    final batch = _db.batch();
    batch.update(_col.doc(uid), {'active': active, if (!active) 'online': false});
    if (!active) {
      batch.set(_presence.doc(uid), {
        'online': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> deleteRider(String uid) async {
    final batch = _db.batch();
    batch.delete(_col.doc(uid));
    batch.delete(_presence.doc(uid));
    await batch.commit();
  }

  @override
  Stream<List<RiderProfile>> watchAllRiders() => _col.snapshots().map(
    (s) => [for (final d in s.docs) RiderProfile.fromMap(d.id, d.data())],
  );

  @override
  Stream<int> watchLiveRiderCount() => _presence
      .where('online', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.where((d) => _fresh(d.data()['lastSeen'])).length);
}

class _MemoryRiders implements RiderRepository {
  _MemoryRiders(this._s);
  final MemoryStore _s;

  @override
  Stream<RiderProfile?> watchRider(String uid) =>
      _s.watch(FirestorePaths.riders, (docs) {
        final d = docs[uid];
        return d == null ? null : RiderProfile.fromMap(uid, d);
      });

  @override
  Future<void> setOnline(String uid, bool online) async => _s.update(
    FirestorePaths.riders,
    uid,
    (d) => {...d, 'online': online, 'lastSeen': DateTime.now()},
  );

  @override
  Future<void> heartbeat(String uid) async => _s.update(
    FirestorePaths.riders,
    uid,
    (d) => {...d, 'lastSeen': DateTime.now()},
  );

  @override
  Future<void> saveRider(RiderProfile r) async =>
      _s.set(FirestorePaths.riders, r.uid, r.toMap(), merge: true);

  @override
  Future<void> setActive(String uid, bool active) async => _s.update(
    FirestorePaths.riders,
    uid,
    (d) => {...d, 'active': active, if (!active) 'online': false},
  );

  @override
  Future<void> deleteRider(String uid) async =>
      _s.delete(FirestorePaths.riders, uid);

  @override
  Stream<List<RiderProfile>> watchAllRiders() => _s.watch(
    FirestorePaths.riders,
    (docs) => [
      for (final e in docs.entries) RiderProfile.fromMap(e.key, e.value),
    ],
  );

  @override
  Stream<int> watchLiveRiderCount() => _s.watch(
    FirestorePaths.riders,
    (docs) => docs.values
        .where(
          (d) =>
              d['active'] != false && d['online'] == true && _fresh(d['lastSeen']),
        )
        .length,
  );
}
