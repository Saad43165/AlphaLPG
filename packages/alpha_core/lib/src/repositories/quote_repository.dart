import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';
import '../models/quote_request.dart';
import 'memory_store.dart';

abstract interface class QuoteRepository {
  factory QuoteRepository.firestore(FirebaseFirestore db) = _FirestoreQuotes;
  factory QuoteRepository.memory(MemoryStore store) = _MemoryQuotes;

  Future<void> submit(QuoteRequest q);
  Stream<List<QuoteRequest>> watchForCustomer(String uid);

  /// Admin: every enquiry, newest first.
  Stream<List<QuoteRequest>> watchAll({int limit = 100});

  /// Admin: new → contacted → won / lost.
  Future<void> setStatus(String id, String status);
}

class _FirestoreQuotes implements QuoteRepository {
  _FirestoreQuotes(this._db);
  final FirebaseFirestore _db;

  @override
  Future<void> submit(QuoteRequest q) =>
      _db.collection(FirestorePaths.quoteRequests).add({
        ...q.toMap(),
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });

  @override
  Stream<List<QuoteRequest>> watchAll({int limit = 100}) => _db
      .collection(FirestorePaths.quoteRequests)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) QuoteRequest.fromMap(d.id, d.data())],
      );

  @override
  Future<void> setStatus(String id, String status) => _db
      .collection(FirestorePaths.quoteRequests)
      .doc(id)
      .update({'status': status});

  @override
  Stream<List<QuoteRequest>> watchForCustomer(String uid) => _db
      .collection(FirestorePaths.quoteRequests)
      .where('customerId', isEqualTo: uid)
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) QuoteRequest.fromMap(d.id, d.data())],
      );
}

class _MemoryQuotes implements QuoteRepository {
  _MemoryQuotes(this._s);
  final MemoryStore _s;

  @override
  Future<void> submit(QuoteRequest q) async => _s.set(
    FirestorePaths.quoteRequests,
    _s.newId(),
    {...q.toMap(), 'status': 'new', 'createdAt': DateTime.now()},
  );

  @override
  Stream<List<QuoteRequest>> watchAll({int limit = 100}) => _s.watch(
    FirestorePaths.quoteRequests,
    (docs) => [
      for (final e in docs.entries) QuoteRequest.fromMap(e.key, e.value),
    ],
  );

  @override
  Future<void> setStatus(String id, String status) async => _s.update(
    FirestorePaths.quoteRequests,
    id,
    (d) => {...d, 'status': status},
  );

  @override
  Stream<List<QuoteRequest>> watchForCustomer(String uid) => _s.watch(
    FirestorePaths.quoteRequests,
    (docs) => [
      for (final e in docs.entries)
        if (e.value['customerId'] == uid) QuoteRequest.fromMap(e.key, e.value),
    ],
  );
}
