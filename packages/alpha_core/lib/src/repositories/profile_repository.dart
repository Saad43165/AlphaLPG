import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';
import '../models/address.dart';
import '../models/blocked_customer.dart';
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

  /// Is this customer blocked from ordering? (null when not blocked.)
  Stream<BlockedCustomer?> watchBlocked(String uid);

  /// Admin: everyone currently blocked.
  Stream<List<BlockedCustomer>> watchAllBlocked();

  /// Admin: all customers, newest first.
  Stream<List<CustomerProfile>> watchCustomers({int limit = 400});

  /// Admin: block ([blocked] true) or unblock a customer.
  Future<void> setBlocked(
    CustomerProfile customer, {
    required bool blocked,
    String reason = '',
  });

  /// Removes the customer's profile and saved locations ("delete my
  /// account"). Past orders are kept for the shop's records.
  Future<void> deleteAccountData(String uid);
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
  Stream<BlockedCustomer?> watchBlocked(String uid) => _db
      .collection(FirestorePaths.blocked)
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? BlockedCustomer.fromMap(uid, d.data()!) : null);

  @override
  Stream<List<BlockedCustomer>> watchAllBlocked() => _db
      .collection(FirestorePaths.blocked)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs) BlockedCustomer.fromMap(d.id, d.data()),
        ],
      );

  @override
  Stream<List<CustomerProfile>> watchCustomers({int limit = 400}) => _db
      .collection(FirestorePaths.customers)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs) CustomerProfile.fromMap(d.id, d.data()),
        ],
      );

  @override
  Future<void> setBlocked(
    CustomerProfile customer, {
    required bool blocked,
    String reason = '',
  }) {
    final ref = _db.collection(FirestorePaths.blocked).doc(customer.uid);
    return blocked
        ? ref.set({
            'name': customer.name,
            'phone': customer.phone,
            'reason': reason,
            'at': FieldValue.serverTimestamp(),
          })
        : ref.delete();
  }

  @override
  Future<void> deleteAccountData(String uid) async {
    final addrs = await _addresses(uid).get();
    for (final d in addrs.docs) {
      await d.reference.delete();
    }
    await _doc(uid).delete();
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

  @override
  Stream<BlockedCustomer?> watchBlocked(String uid) =>
      _s.watch(FirestorePaths.blocked, (docs) {
        final d = docs[uid];
        return d == null ? null : BlockedCustomer.fromMap(uid, d);
      });

  @override
  Stream<List<BlockedCustomer>> watchAllBlocked() => _s.watch(
    FirestorePaths.blocked,
    (docs) => [
      for (final e in docs.entries) BlockedCustomer.fromMap(e.key, e.value),
    ],
  );

  @override
  Stream<List<CustomerProfile>> watchCustomers({int limit = 400}) => _s.watch(
    FirestorePaths.customers,
    (docs) => [
      for (final e in docs.entries) CustomerProfile.fromMap(e.key, e.value),
    ],
  );

  @override
  Future<void> setBlocked(
    CustomerProfile customer, {
    required bool blocked,
    String reason = '',
  }) async {
    if (blocked) {
      _s.set(FirestorePaths.blocked, customer.uid, {
        'name': customer.name,
        'phone': customer.phone,
        'reason': reason,
        'at': DateTime.now(),
      });
    } else {
      _s.delete(FirestorePaths.blocked, customer.uid);
    }
  }

  @override
  Future<void> deleteAccountData(String uid) async {
    final path = FirestorePaths.addresses(uid);
    final ids = await _s.watch(path, (docs) => docs.keys.toList()).first;
    for (final id in ids) {
      _s.delete(path, id);
    }
    _s.delete(FirestorePaths.customers, uid);
  }
}
