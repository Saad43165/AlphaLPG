import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';
import '../models/rider.dart';
import 'memory_store.dart';

abstract interface class RiderRepository {
  factory RiderRepository.firestore(FirebaseFirestore db) = _FirestoreRiders;
  factory RiderRepository.memory(MemoryStore store) = _MemoryRiders;

  /// Null when this account is not set up as a rider.
  Stream<RiderProfile?> watchRider(String uid);

  /// The rider's own on-shift switch.
  Future<void> setOnline(String uid, bool online);

  /// Owner / admin only (enforced by security rules).
  Future<void> saveRider(RiderProfile rider);
  Stream<List<RiderProfile>> watchAllRiders();

  /// Admin: switch a rider's account on or off.
  Future<void> setActive(String uid, bool active);
}

class _FirestoreRiders implements RiderRepository {
  _FirestoreRiders(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.riders);

  @override
  Stream<RiderProfile?> watchRider(String uid) => _col
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? RiderProfile.fromMap(d.id, d.data()!) : null);

  @override
  Future<void> setOnline(String uid, bool online) => _col.doc(uid).update({
    'online': online,
    'lastSeen': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> saveRider(RiderProfile r) =>
      _col.doc(r.uid).set(r.toMap(), SetOptions(merge: true));

  @override
  Future<void> setActive(String uid, bool active) =>
      _col.doc(uid).update({'active': active, if (!active) 'online': false});

  @override
  Stream<List<RiderProfile>> watchAllRiders() => _col.snapshots().map(
    (s) => [for (final d in s.docs) RiderProfile.fromMap(d.id, d.data())],
  );
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
  Future<void> saveRider(RiderProfile r) async =>
      _s.set(FirestorePaths.riders, r.uid, r.toMap(), merge: true);

  @override
  Future<void> setActive(String uid, bool active) async => _s.update(
    FirestorePaths.riders,
    uid,
    (d) => {...d, 'active': active, if (!active) 'online': false},
  );

  @override
  Stream<List<RiderProfile>> watchAllRiders() => _s.watch(
    FirestorePaths.riders,
    (docs) => [
      for (final e in docs.entries) RiderProfile.fromMap(e.key, e.value),
    ],
  );
}
