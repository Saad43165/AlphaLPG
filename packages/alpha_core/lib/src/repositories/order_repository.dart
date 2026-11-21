import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';
import '../models/order.dart';
import '../models/order_message.dart';
import '../models/order_status.dart';
import '../models/rider.dart';
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

  /// Customer adds / corrects the transaction ID of a prepaid order.
  Future<void> submitPaymentReference(String orderId, String reference);

  /// Customer rates a delivered order (once, enforced by rules).
  Future<void> rate(String orderId, int stars, String feedback);

  // Admin / rider operations (used by the upcoming apps).
  Stream<List<LpgOrder>> watchByStatus(List<OrderStatus> statuses);

  /// The newest orders of any status (admin dashboard and order board).
  Stream<List<LpgOrder>> watchRecent({int limit = 300});

  /// Admin: a wallet / bank payment has arrived (or cash was handed in).
  Future<void> markPaid(String orderId, String by);
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

  // ---- Rider workflow ----------------------------------------------------

  /// New orders nobody has taken yet (placed or confirmed, no rider).
  Stream<List<LpgOrder>> watchAvailable();

  /// A rider takes an order. Returns false if someone else got it first.
  Future<bool> acceptOrder(
    String orderId, {
    required String riderId,
    required String name,
    required String phone,
  });

  /// The rider has picked up the cylinders and is on the way.
  Future<void> startDelivery(String orderId, String riderId);

  /// The rider is at the customer's door.
  Future<void> markArrived(String orderId, String riderId);

  /// The rider cannot do an assigned job: it goes back to the shop (confirmed,
  /// no rider) so another rider can take it.
  Future<void> releaseJob(String orderId, String riderId);

  /// Delivered: records the cash taken at the door and empties collected.
  /// Cash marks a cash-on-delivery order as paid.
  Future<void> completeDelivery(
    String orderId,
    String riderId, {
    required int cashCollected,
    required int emptiesCollected,
  });

  /// A rider's finished and cancelled orders, newest first.
  Stream<List<LpgOrder>> watchRiderHistory(String riderId, {int limit = 100});

  // ---- Live tracking -----------------------------------------------------

  /// The assigned rider shares their position for this order.
  Future<void> publishRiderLocation(String orderId, RiderLocation location);

  /// The customer (or admin) watches the rider.
  Stream<RiderLocation?> watchRiderLocation(String orderId);

  // ---- Order chat ----------------------------------------------------------

  /// Messages on an order, oldest first.
  Stream<List<OrderMessage>> watchMessages(String orderId);

  /// Writes a message as the customer, the rider or the shop.
  Future<void> sendMessage(
    String orderId, {
    required String uid,
    required MessageRole role,
    required String name,
    required String text,
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

  /// Newest first, sorted here so no composite Firestore index is needed.
  /// An order whose server time has not arrived yet counts as the newest.
  List<LpgOrder> _newestFirst(QuerySnapshot<Map<String, dynamic>> s) {
    final now = DateTime.now();
    return _list(s)..sort(
      (a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now),
    );
  }

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
          .snapshots()
          .map((s) => _newestFirst(s).take(limit).toList());

  @override
  Future<void> cancelByCustomer(LpgOrder o, String reason) => _setStatus(
    o.id,
    OrderStatus.cancelled,
    o.customerId,
    extra: {'cancelReason': reason},
    note: reason,
  );

  @override
  Future<void> submitPaymentReference(String orderId, String reference) =>
      _orders.doc(orderId).update({
        'paymentReference': reference.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> rate(String orderId, int stars, String feedback) =>
      _orders.doc(orderId).update({
        'rating': stars.clamp(1, 5),
        'feedback': feedback,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Stream<List<LpgOrder>> watchByStatus(List<OrderStatus> statuses) => _orders
      .where('status', whereIn: [for (final s in statuses) s.name])
      .snapshots()
      .map(_newestFirst);

  @override
  Stream<List<LpgOrder>> watchRecent({int limit = 300}) => _orders
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(_list);

  @override
  Future<void> markPaid(String orderId, String by) => _orders.doc(orderId).update({
    'paymentStatus': PaymentStatus.paid.name,
    'updatedAt': FieldValue.serverTimestamp(),
  });

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

  @override
  Stream<List<LpgOrder>> watchAvailable() => _orders
      .where('riderId', isNull: true)
      .where(
        'status',
        whereIn: [OrderStatus.placed.name, OrderStatus.confirmed.name],
      )
      .snapshots()
      .map(
        (s) => _list(s)
          ..sort(
            (a, b) => a.createdAt?.compareTo(b.createdAt ?? DateTime(0)) ?? 0,
          ),
      );

  @override
  Future<bool> acceptOrder(
    String orderId, {
    required String riderId,
    required String name,
    required String phone,
  }) => _db.runTransaction((tx) async {
    final ref = _orders.doc(orderId);
    final snap = await tx.get(ref);
    final d = snap.data();
    final status = OrderStatus.parse(d?['status'] as String?);
    if (d == null ||
        d['riderId'] != null ||
        (status != OrderStatus.placed && status != OrderStatus.confirmed)) {
      return false;
    }
    tx.update(ref, {
      'riderId': riderId,
      'riderName': name,
      'riderPhone': phone,
      'status': OrderStatus.assigned.name,
      'history': FieldValue.arrayUnion([
        StatusEvent(
          status: OrderStatus.assigned,
          at: DateTime.now(),
          by: riderId,
        ).toMap(),
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  });

  @override
  Future<void> startDelivery(String orderId, String riderId) =>
      _setStatus(orderId, OrderStatus.outForDelivery, riderId);

  @override
  Future<void> markArrived(String orderId, String riderId) =>
      _orders.doc(orderId).update({
        'arrivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> releaseJob(String orderId, String riderId) => _setStatus(
    orderId,
    OrderStatus.confirmed,
    riderId,
    note: 'Rider handed the job back',
    extra: {'riderId': null, 'riderName': null, 'riderPhone': null},
  );

  @override
  Future<void> completeDelivery(
    String orderId,
    String riderId, {
    required int cashCollected,
    required int emptiesCollected,
  }) => _setStatus(
    orderId,
    OrderStatus.delivered,
    riderId,
    extra: {
      'cashCollected': cashCollected,
      'emptiesCollected': emptiesCollected,
      if (cashCollected > 0) 'paymentStatus': PaymentStatus.paid.name,
    },
  );

  @override
  Stream<List<LpgOrder>> watchRiderHistory(String riderId, {int limit = 100}) =>
      _orders.where('riderId', isEqualTo: riderId).snapshots().map((s) {
        final all =
            _list(s)
                .where(
                  (o) =>
                      o.status == OrderStatus.delivered ||
                      o.status == OrderStatus.cancelled,
                )
                .toList()
              ..sort(
                (a, b) => (b.updatedAt ?? DateTime(0)).compareTo(
                  a.updatedAt ?? DateTime(0),
                ),
              );
        return all.take(limit).toList();
      });

  @override
  Future<void> publishRiderLocation(String orderId, RiderLocation l) => _db
      .doc('${FirestorePaths.live(orderId)}/${FirestorePaths.liveDoc}')
      .set({...l.toMap(), 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Stream<RiderLocation?> watchRiderLocation(String orderId) => _db
      .doc('${FirestorePaths.live(orderId)}/${FirestorePaths.liveDoc}')
      .snapshots()
      .map((d) => d.exists ? RiderLocation.fromMap(d.data()!) : null);

  @override
  Stream<List<OrderMessage>> watchMessages(String orderId) => _db
      .collection(FirestorePaths.messages(orderId))
      .orderBy('createdAt')
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs) OrderMessage.fromMap(d.id, d.data()),
        ],
      );

  @override
  Future<void> sendMessage(
    String orderId, {
    required String uid,
    required MessageRole role,
    required String name,
    required String text,
  }) => _db.collection(FirestorePaths.messages(orderId)).add({
    'uid': uid,
    'role': role.name,
    'name': name,
    'text': text.trim(),
    'createdAt': FieldValue.serverTimestamp(),
  });

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
  Future<void> submitPaymentReference(String orderId, String reference) async =>
      _s.update(
        _path,
        orderId,
        (d) => {
          ...d,
          'paymentReference': reference.trim(),
          'updatedAt': DateTime.now(),
        },
      );

  @override
  Future<void> rate(String orderId, int stars, String feedback) async =>
      _s.update(
        _path,
        orderId,
        (d) => {
          ...d,
          'rating': stars.clamp(1, 5),
          'feedback': feedback,
          'updatedAt': DateTime.now(),
        },
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
  Stream<List<LpgOrder>> watchRecent({int limit = 300}) =>
      _s.watch(_path, (docs) => _sorted(docs.entries).take(limit).toList());

  @override
  Future<void> markPaid(String orderId, String by) async => _s.update(
    _path,
    orderId,
    (d) => {...d, 'paymentStatus': 'paid', 'updatedAt': DateTime.now()},
  );

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

  @override
  Stream<List<LpgOrder>> watchAvailable() => _s.watch(
    _path,
    (docs) => _sorted(
      docs.entries.where(
        (e) =>
            e.value['riderId'] == null &&
            (e.value['status'] == OrderStatus.placed.name ||
                e.value['status'] == OrderStatus.confirmed.name),
      ),
    ).reversed.toList(),
  );

  @override
  Future<bool> acceptOrder(
    String orderId, {
    required String riderId,
    required String name,
    required String phone,
  }) async {
    final d = _s.get(_path, orderId);
    final status = OrderStatus.parse(d?['status'] as String?);
    if (d == null ||
        d['riderId'] != null ||
        (status != OrderStatus.placed && status != OrderStatus.confirmed)) {
      return false;
    }
    _setStatus(
      orderId,
      OrderStatus.assigned,
      riderId,
      extra: {'riderId': riderId, 'riderName': name, 'riderPhone': phone},
    );
    return true;
  }

  @override
  Future<void> startDelivery(String orderId, String riderId) async =>
      _setStatus(orderId, OrderStatus.outForDelivery, riderId);

  @override
  Future<void> markArrived(String orderId, String riderId) async =>
      _s.update(
        _path,
        orderId,
        (d) => {...d, 'arrivedAt': DateTime.now(), 'updatedAt': DateTime.now()},
      );

  @override
  Future<void> releaseJob(String orderId, String riderId) async => _setStatus(
    orderId,
    OrderStatus.confirmed,
    riderId,
    note: 'Rider handed the job back',
    extra: {'riderId': null, 'riderName': null, 'riderPhone': null},
  );

  @override
  Future<void> completeDelivery(
    String orderId,
    String riderId, {
    required int cashCollected,
    required int emptiesCollected,
  }) async => _setStatus(
    orderId,
    OrderStatus.delivered,
    riderId,
    extra: {
      'cashCollected': cashCollected,
      'emptiesCollected': emptiesCollected,
      if (cashCollected > 0) 'paymentStatus': PaymentStatus.paid.name,
    },
  );

  @override
  Stream<List<LpgOrder>> watchRiderHistory(String riderId, {int limit = 100}) =>
      _s.watch(
        _path,
        (docs) => _sorted(
          docs.entries.where(
            (e) =>
                e.value['riderId'] == riderId &&
                (e.value['status'] == OrderStatus.delivered.name ||
                    e.value['status'] == OrderStatus.cancelled.name),
          ),
        ).take(limit).toList(),
      );

  @override
  Future<void> publishRiderLocation(String orderId, RiderLocation l) async =>
      _s.set(FirestorePaths.live(orderId), FirestorePaths.liveDoc, {
        ...l.toMap(),
        'updatedAt': DateTime.now(),
      });

  @override
  Stream<RiderLocation?> watchRiderLocation(String orderId) =>
      _s.watch(FirestorePaths.live(orderId), (docs) {
        final d = docs[FirestorePaths.liveDoc];
        return d == null ? null : RiderLocation.fromMap(d);
      });

  @override
  Stream<List<OrderMessage>> watchMessages(String orderId) =>
      _s.watch(FirestorePaths.messages(orderId), (docs) {
        final list = [
          for (final e in docs.entries) OrderMessage.fromMap(e.key, e.value),
        ]..sort(
            (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
              b.createdAt ?? DateTime(0),
            ),
          );
        return list;
      });

  @override
  Future<void> sendMessage(
    String orderId, {
    required String uid,
    required MessageRole role,
    required String name,
    required String text,
  }) async => _s.set(FirestorePaths.messages(orderId), _s.newId(), {
    'uid': uid,
    'role': role.name,
    'name': name,
    'text': text.trim(),
    'createdAt': DateTime.now(),
  });

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
