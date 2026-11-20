import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';
import '../models/address.dart';
import '../models/customer_profile.dart';
import 'memory_store.dart';

abstract interface class ProfileRepository {
  factory ProfileRepository.firestore(FirebaseFirestore db) =
      _FirestoreProfiles;
  factory ProfileRepository.memory(MemoryStore store) = _MemoryProfiles;

  Stream<CustomerProfile?> watchProfile(String uid);
  Future<void> saveProfile(CustomerProfile p, {bool isNew = false});
  Stream<List<Address>> watchAddresses(String uid);

  /// Creates (empty id) or updates an address; returns it with its id.
  Future<Address> saveAddress(String uid, Address a);
  Future<void> deleteAddress(String uid, String id);
}

class _FirestoreProfiles implements ProfileRepository {
  _FirestoreProfiles(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection(FirestorePaths.customers).doc(uid);

  CollectionReference<Map<String, dynamic>> _addresses(String uid) =>
      _db.collection(FirestorePaths.addresses(uid));

  @override
  Stream<CustomerProfile?> watchProfile(String uid) => _doc(uid)
      .snapshots()
      .map((d) => d.exists ? CustomerProfile.fromMap(d.id, d.data()!) : null);

  @override
  Future<void> saveProfile(CustomerProfile p, {bool isNew = false}) =>
      _doc(p.uid).set({
        ...p.toMap(),
        if (isNew) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  @override
  Stream<List<Address>> watchAddresses(String uid) => _addresses(uid)
      .orderBy('createdAt')
      .snapshots()
      .map((s) => [for (final d in s.docs) Address.fromMap(d.id, d.data())]);

  @override
  Future<Address> saveAddress(String uid, Address a) async {
    if (a.id.isEmpty) {
      final ref = await _addresses(uid)
          .add({...a.toMap(), 'createdAt': FieldValue.serverTimestamp()});
      return a.copyWith(id: ref.id);
    }
    await _addresses(uid).doc(a.id).set(a.toMap(), SetOptions(merge: true));
    return a;
  }

  @override
  Future<void> deleteAddress(String uid, String id) =>
      _addresses(uid).doc(id).delete();
}

class _MemoryProfiles implements ProfileRepository {
  _MemoryProfiles(this._s);
  final MemoryStore _s;

  @override
  Stream<CustomerProfile?> watchProfile(String uid) =>
      _s.watch(FirestorePaths.customers, (docs) {
        final d = docs[uid];
        return d == null ? null : CustomerProfile.fromMap(uid, d);
      });

  @override
  Future<void> saveProfile(CustomerProfile p, {bool isNew = false}) async =>
      _s.set(FirestorePaths.customers, p.uid, {
        ...p.toMap(),
        if (isNew) 'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      }, merge: true);

  @override
  Stream<List<Address>> watchAddresses(String uid) =>
      _s.watch(FirestorePaths.addresses(uid), (docs) {
        final entries = docs.entries.toList()
          ..sort(
            (a, b) => (a.value['createdAt'] as DateTime).compareTo(
              b.value['createdAt'] as DateTime,
            ),
          );
        return [for (final e in entries) Address.fromMap(e.key, e.value)];
      });

  @override
  Future<Address> saveAddress(String uid, Address a) async {
    final path = FirestorePaths.addresses(uid);
    final id = a.id.isEmpty ? _s.newId() : a.id;
    _s.set(path, id, {
      ...a.toMap(),
      'createdAt': _s.get(path, id)?['createdAt'] ?? DateTime.now(),
    });
    return a.copyWith(id: id);
  }

  @override
  Future<void> deleteAddress(String uid, String id) async =>
      _s.delete(FirestorePaths.addresses(uid), id);
}
