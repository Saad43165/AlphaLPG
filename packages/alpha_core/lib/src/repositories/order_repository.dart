import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import 'memory_store.dart';

abstract interface class OrderRepository {
  factory OrderRepository.firestore(FirebaseFirestore db) = _FirestoreOrders;
  factory OrderRepository.memory(MemoryStore store) = _MemoryOrders;

  /// Creates the order as [OrderStatus.placed] and returns its id. In
  /// production the `onOrderCreated` Cloud Function then re-prices it and
  /// assigns a sequential order number.
  Future<String> place(LpgOrder order);
  Stream<LpgOrder?> watchOrder(String id);
  Stream<List<LpgOrder>> watchCustomerOrders(String uid, {int limit = 50});

  /// Customer cancellation (only while `placed`, enforced by rules).
  Future<void> cancelByCustomer(LpgOrder o, String reason);

  // Admin / rider operations (used by the upcoming apps).
  Stream<List<LpgOrder>> watchByStatus(List<OrderStatus> statuses);
  Stream<List<LpgOrder>> watchRiderOrders(String riderId);
  Future<void> assignRider(
    String orderId,
    String adminId, {
    required String riderId,
    required String name,
    required String phone,
  });
  Future<void> updateStatus(
    String orderId,
    OrderStatus status,
    String by, {
    String note = '',
  });
}

/// "AL-261120-K3F9" — replaced by a sequential number server-side.
String provisionalOrderNumber(String id, DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'AL-${two(t.year % 100)}${two(t.month)}${two(t.day)}-'
      '${id.substring(id.length - 4).toUpperCase()}';
}

Map<String, dynamic> _newOrderData(String id, LpgOrder order, DateTime now) => {
  ...order.toMap(),
  'orderNumber': provisionalOrderNumber(id, now),
  'status': OrderStatus.placed.name,
  'history': [
    StatusEvent(
      status: OrderStatus.placed,
      at: now,
      by: order.customerId,
    ).toMap(),
  ],
};

class _FirestoreOrders implements OrderRepository {
  _FirestoreOrders(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection(FirestorePaths.orders);

  List<LpgOrder> _list(QuerySnapshot<Map<String, dynamic>> s) => [
    for (final d in s.docs) LpgOrder.fromMap(d.id, d.data()),
  ];

  @override
  Future<String> place(LpgOrder order) async {
    final ref = _orders.doc();
    await ref.set({
      ..._newOrderData(ref.id, order, DateTime.now()),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Stream<LpgOrder?> watchOrder(String id) => _orders
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? LpgOrder.fromMap(d.id, d.data()!) : null);

  @override
  Stream<List<LpgOrder>> watchCustomerOrders(String uid, {int limit = 50}) =>
      _orders
          .where('customerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(_list);

  @override
  Future<void> cancelByCustomer(LpgOrder o, String reason) => _setStatus(
    o.id,
    OrderStatus.cancelled,
    o.customerId,
    extra: {'cancelReason': reason},
    note: reason,
  );

  @override
  Stream<List<LpgOrder>> watchByStatus(List<OrderStatus> statuses) => _orders
      .where('status', whereIn: [for (final s in statuses) s.name])
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(_list);

  @override
  Stream<List<LpgOrder>> watchRiderOrders(String riderId) => _orders
      .where('riderId', isEqualTo: riderId)
      .where(
        'status',
        whereIn: [OrderStatus.assigned.name, OrderStatus.outForDelivery.name],
      )
      .snapshots()
      .map(_list);

  @override
  Future<void> assignRider(
    String orderId,
    String adminId, {
    required String riderId,
    required String name,
    required String phone,
  }) => _setStatus(
    orderId,
    OrderStatus.assigned,
    adminId,
    extra: {'riderId': riderId, 'riderName': name, 'riderPhone': phone},
  );

  @override
  Future<void> updateStatus(
    String orderId,
    OrderStatus status,
    String by, {
    String note = '',
  }) => _setStatus(orderId, status, by, note: note);

  Future<void> _setStatus(
    String id,
    OrderStatus status,
    String by, {
    Map<String, dynamic> extra = const {},
    String note = '',
  }) => _orders.doc(id).update({
    ...extra,
    'status': status.name,
    'history': FieldValue.arrayUnion([
      StatusEvent(
        status: status,
        at: DateTime.now(),
        by: by,
        note: note,
      ).toMap(),
    ]),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

class _MemoryOrders implements OrderRepository {
  _MemoryOrders(this._s);
  final MemoryStore _s;
  static const _path = FirestorePaths.orders;

  List<LpgOrder> _sorted(Iterable<MapEntry<String, Map<String, dynamic>>> e) =>
      [for (final d in e) LpgOrder.fromMap(d.key, d.value)]
        ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));

  @override
  Future<String> place(LpgOrder order) async {
    final id = _s.newId();
    final now = DateTime.now();
    _s.set(_path, id, {
      ..._newOrderData(id, order, now),
      'createdAt': now,
      'updatedAt': now,
    });
    return id;
  }

  @override
  Stream<LpgOrder?> watchOrder(String id) => _s.watch(_path, (docs) {
    final d = docs[id];
    return d == null ? null : LpgOrder.fromMap(id, d);
  });

  @override
  Stream<List<LpgOrder>> watchCustomerOrders(String uid, {int limit = 50}) =>
      _s.watch(
        _path,
        (docs) =>
            _sorted(docs.entries.where((e) => e.value['customerId'] == uid))
                .take(limit)
                .toList(),
      );

  @override
  Future<void> cancelByCustomer(LpgOrder o, String reason) async => _setStatus(
    o.id,
    OrderStatus.cancelled,
    o.customerId,
    extra: {'cancelReason': reason},
    note: reason,
  );

  @override
  Stream<List<LpgOrder>> watchByStatus(List<OrderStatus> statuses) {
    final names = {for (final s in statuses) s.name};
    return _s.watch(
      _path,
      (docs) =>
          _sorted(docs.entries.where((e) => names.contains(e.value['status']))),
    );
  }

  @override
  Stream<List<LpgOrder>> watchRiderOrders(String riderId) => _s.watch(
    _path,
    (docs) => _sorted(
      docs.entries.where(
        (e) =>
            e.value['riderId'] == riderId &&
            (e.value['status'] == OrderStatus.assigned.name ||
                e.value['status'] == OrderStatus.outForDelivery.name),
      ),
    ),
  );

  @override
  Future<void> assignRider(
    String orderId,
    String adminId, {
    required String riderId,
    required String name,
    required String phone,
  }) async => _setStatus(
    orderId,
    OrderStatus.assigned,
    adminId,
    extra: {'riderId': riderId, 'riderName': name, 'riderPhone': phone},
  );

  @override
  Future<void> updateStatus(
    String orderId,
    OrderStatus status,
    String by, {
    String note = '',
  }) async => _setStatus(orderId, status, by, note: note);

  void _setStatus(
    String id,
    OrderStatus status,
    String by, {
    Map<String, dynamic> extra = const {},
    String note = '',
  }) => _s.update(
    _path,
    id,
    (d) => {
      ...d,
      ...extra,
      'status': status.name,
      'history': [
        ...(d['history'] as List),
        StatusEvent(
          status: status,
          at: DateTime.now(),
          by: by,
          note: note,
        ).toMap(),
      ],
      'updatedAt': DateTime.now(),
    },
  );
}
