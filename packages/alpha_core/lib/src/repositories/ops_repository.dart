import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ops_models.dart';
import 'memory_store.dart';

/// Shop operations kept for the owner: customer cylinder ledger, rider cash
/// handovers, the audit log and app error reports.
abstract interface class OpsRepository {
  factory OpsRepository.firestore(FirebaseFirestore db) = _FirestoreOps;
  factory OpsRepository.memory(MemoryStore store) = _MemoryOps;

  static const ledgerPath = 'ledger';
  static const handoversPath = 'handovers';
  static const auditPath = 'audit';
  static const errorsPath = 'errors';

  // Customer ledger (admin).
  Stream<List<LedgerEntry>> watchLedger({int limit = 400});
  Future<void> addLedger(LedgerEntry e);

  // Rider cash handovers (admin writes; the rider can read their own).
  Stream<List<CashHandover>> watchHandovers({int limit = 300});
  Stream<List<CashHandover>> watchRiderHandovers(String riderId);
  Future<void> addHandover(CashHandover h);

  // Audit log (admin writes, owner reads).
  Stream<List<AuditEntry>> watchAudit({int limit = 200});
  Future<void> addAudit(AuditEntry e);

  // Admin team (owner manages; everyone reads their own role).
  Stream<List<AdminUser>> watchAdmins();
  Stream<AdminUser?> watchAdmin(String uid);
  Future<void> saveAdmin(AdminUser a);
  Future<void> removeAdmin(String uid);

  // Error reports (any signed-in app writes, admin reads).
  Stream<List<ErrorEntry>> watchErrors({int limit = 100});
  Future<void> reportError(ErrorEntry e);
}

class _FirestoreOps implements OpsRepository {
  _FirestoreOps(this._db);
  final FirebaseFirestore _db;

  Stream<List<T>> _recent<T>(
    String path,
    int limit,
    String orderField,
    T Function(String, Map<String, dynamic>) from,
  ) => _db
      .collection(path)
      .orderBy(orderField, descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => [for (final d in s.docs) from(d.id, d.data())]);

  @override
  Stream<List<LedgerEntry>> watchLedger({int limit = 400}) =>
      _recent(OpsRepository.ledgerPath, limit, 'at', LedgerEntry.fromMap);

  @override
  Future<void> addLedger(LedgerEntry e) => _db
      .collection(OpsRepository.ledgerPath)
      .add({...e.toMap(), 'at': FieldValue.serverTimestamp()});

  @override
  Stream<List<CashHandover>> watchHandovers({int limit = 300}) =>
      _recent(OpsRepository.handoversPath, limit, 'at', CashHandover.fromMap);

  @override
  Stream<List<CashHandover>> watchRiderHandovers(String riderId) => _db
      .collection(OpsRepository.handoversPath)
      .where('riderId', isEqualTo: riderId)
      .snapshots()
      .map((s) {
        final l = [
          for (final d in s.docs) CashHandover.fromMap(d.id, d.data()),
        ]..sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)));
        return l;
      });

  @override
  Future<void> addHandover(CashHandover h) => _db
      .collection(OpsRepository.handoversPath)
      .add({...h.toMap(), 'at': FieldValue.serverTimestamp()});

  @override
  Stream<List<AuditEntry>> watchAudit({int limit = 200}) =>
      _recent(OpsRepository.auditPath, limit, 'at', AuditEntry.fromMap);

  @override
  Future<void> addAudit(AuditEntry e) => _db
      .collection(OpsRepository.auditPath)
      .add({...e.toMap(), 'at': FieldValue.serverTimestamp()});

  @override
  Stream<List<AdminUser>> watchAdmins() => _db
      .collection('admins')
      .snapshots()
      .map((s) => [for (final d in s.docs) AdminUser.fromMap(d.id, d.data())]);

  @override
  Stream<AdminUser?> watchAdmin(String uid) => _db
      .collection('admins')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? AdminUser.fromMap(d.id, d.data()!) : null);

  @override
  Future<void> saveAdmin(AdminUser a) =>
      _db.collection('admins').doc(a.uid).set({
        'email': a.email,
        'name': a.name,
        'role': a.role,
        'createdAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> removeAdmin(String uid) =>
      _db.collection('admins').doc(uid).delete();

  @override
  Stream<List<ErrorEntry>> watchErrors({int limit = 100}) =>
      _recent(OpsRepository.errorsPath, limit, 'at', ErrorEntry.fromMap);

  @override
  Future<void> reportError(ErrorEntry e) => _db
      .collection(OpsRepository.errorsPath)
      .add({...e.toMap(), 'at': FieldValue.serverTimestamp()});
}

class _MemoryOps implements OpsRepository {
  _MemoryOps(this._s);
  final MemoryStore _s;

  Stream<List<T>> _all<T>(
    String path,
    int limit,
    T Function(String, Map<String, dynamic>) from,
    DateTime? Function(T) at,
  ) => _s.watch(path, (docs) {
    final l = [for (final e in docs.entries) from(e.key, e.value)]
      ..sort((a, b) => (at(b) ?? DateTime(0)).compareTo(at(a) ?? DateTime(0)));
    return l.take(limit).toList();
  });

  Future<void> _add(String path, Map<String, dynamic> m) async =>
      _s.set(path, _s.newId(), {...m, 'at': DateTime.now()});

  @override
  Stream<List<LedgerEntry>> watchLedger({int limit = 400}) =>
      _all(OpsRepository.ledgerPath, limit, LedgerEntry.fromMap, (e) => e.at);

  @override
  Future<void> addLedger(LedgerEntry e) =>
      _add(OpsRepository.ledgerPath, e.toMap());

  @override
  Stream<List<CashHandover>> watchHandovers({int limit = 300}) => _all(
    OpsRepository.handoversPath,
    limit,
    CashHandover.fromMap,
    (e) => e.at,
  );

  @override
  Stream<List<CashHandover>> watchRiderHandovers(String riderId) =>
      watchHandovers().map(
        (l) => [
          for (final h in l)
            if (h.riderId == riderId) h,
        ],
      );

  @override
  Future<void> addHandover(CashHandover h) =>
      _add(OpsRepository.handoversPath, h.toMap());

  @override
  Stream<List<AuditEntry>> watchAudit({int limit = 200}) =>
      _all(OpsRepository.auditPath, limit, AuditEntry.fromMap, (e) => e.at);

  @override
  Future<void> addAudit(AuditEntry e) =>
      _add(OpsRepository.auditPath, e.toMap());

  @override
  Stream<List<AdminUser>> watchAdmins() => _s.watch(
    'admins',
    (docs) => [for (final e in docs.entries) AdminUser.fromMap(e.key, e.value)],
  );

  @override
  Stream<AdminUser?> watchAdmin(String uid) => _s.watch('admins', (docs) {
    final d = docs[uid];
    return d == null ? null : AdminUser.fromMap(uid, d);
  });

  @override
  Future<void> saveAdmin(AdminUser a) async => _s.set('admins', a.uid, {
    'email': a.email,
    'name': a.name,
    'role': a.role,
    'createdAt': DateTime.now(),
  });

  @override
  Future<void> removeAdmin(String uid) async => _s.delete('admins', uid);

  @override
  Stream<List<ErrorEntry>> watchErrors({int limit = 100}) =>
      _all(OpsRepository.errorsPath, limit, ErrorEntry.fromMap, (e) => e.at);

  @override
  Future<void> reportError(ErrorEntry e) =>
      _add(OpsRepository.errorsPath, e.toMap());
}
