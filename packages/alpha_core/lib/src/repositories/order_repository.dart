import 'package:cloud_firestore/cloud_firestore.dart';

import '../dates.dart';
import '../firestore_paths.dart';
import '../models/order.dart';
import '../models/order_report.dart';
import '../models/order_message.dart';
import '../models/order_status.dart';
import '../models/payment_request.dart';
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

  /// Customer: "I paid". Transaction ID and amount are required; a receipt
  /// picture (base64) is optional but encouraged. Marks the order as having a
  /// receipt for the shop to check.
  Future<void> submitPayment(
    String orderId, {
    required String uid,
    required String reference,
    required int amount,
    String? data,
    String note = '',
  });

  /// Admin: removes the payment receipt pictures and delivery photos of
  /// finished orders last touched before [before] (the orders and their
  /// amounts stay). Works through [limit] orders per call; returns how many
  /// pictures were removed. Call again until it returns 0.
  Future<int> archiveOldPhotos(DateTime before, {int limit = 40});

  /// Customer: complaint about the order or the rider, straight to the shop.
  Future<void> addReport(OrderReport r);

  /// Customer: their own reports on one order.
  Stream<List<OrderReport>> watchOrderReports(
    String orderId,
    String customerId,
  );

  /// Rider: their own reports on one order (with the shop's answers).
  Stream<List<OrderReport>> watchRiderReports(String orderId, String riderId);

  /// Admin: all reports, newest first.
  Stream<List<OrderReport>> watchReports({int limit = 200});

  /// Admin: answer and close (or reopen) a report.
  Future<void> resolveReport(
    String id, {
    required String reply,
    bool resolved = true,
    String refund = 'none',
  });

  /// Customer: every report they have sent, newest first (a help history).
  Stream<List<OrderReport>> watchCustomerReports(String customerId);

  /// Public star rating of a rider (null if none yet).
  Stream<RiderStats?> watchRiderStats(String riderId);

  /// Admin: publish a rider's star rating.
  Future<void> saveRiderStats(String riderId, double average, int count);

  /// Rider: a photo of the delivered cylinders / the customer's door
  /// (base64 JPEG, kept small). Customer and shop can see it.
  Future<void> addDeliveryProof(
    String orderId, {
    required String uid,
    required String data,
  });
  Stream<List<PaymentReceipt>> watchDeliveryProofs(String orderId);

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

  /// Admin: sends payment instructions (method, account, amount) straight to
  /// the customer's order screen. Clears any earlier payment problem.
  Future<void> sendPaymentRequest(String orderId, PaymentRequest request);

  /// Admin: tells the customer what is wrong ("receipt is not clear"), or
  /// clears it with an empty string.
  Future<void> setPaymentIssue(String orderId, String issue);

  /// Customer: attaches a photo of the payment receipt (base64 image).
  Future<void> addReceipt(
    String orderId, {
    required String uid,
    required String data,
    String note = '',
  });

  /// The receipts on an order, newest last (customer and admin).
  Stream<List<PaymentReceipt>> watchReceipts(String orderId);
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

  /// Admin: takes an order away from its rider; it goes back to "confirmed"
  /// with nobody assigned, so another rider can accept it (or the shop can
  /// assign one).
  Future<void> unassignRider(String orderId, String adminId);

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
    bool markPaid = true,
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

  /// When each side last opened the chat: used for "Seen" and unread counts.
  Stream<Map<MessageRole, DateTime>> watchChatReads(String orderId);

  /// "I have read everything so far" for [role].
  Future<void> markChatRead(String orderId, MessageRole role);

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
    return _list(s)
      ..sort((a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
  }

  @override
  Future<String> place(LpgOrder order) async {
    final ref = _orders.doc();
    final batch = _db.batch()
      ..set(ref, {
        ..._newOrderData(ref.id, order, DateTime.now()),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    if (order.couponCode.isNotEmpty) {
      // The code is spent in the same step as the order.
      batch.set(
        _db.doc(FirestorePaths.couponUse(order.couponCode, order.customerId)),
        {'orderId': ref.id, 'at': FieldValue.serverTimestamp()},
      );
    }
    await batch.commit();
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
  Future<void> submitPayment(
    String orderId, {
    required String uid,
    required String reference,
    required int amount,
    String? data,
    String note = '',
  }) async {
    final batch = _db.batch();
    if (data != null && data.isNotEmpty) {
      batch.set(_db.collection(FirestorePaths.receipts(orderId)).doc(), {
        'uid': uid,
        'data': data,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(_orders.doc(orderId), {
      'paymentReference': reference.trim(),
      'paidAmount': amount,
      'receiptAt': FieldValue.serverTimestamp(),
      'paymentIssue': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  @override
  Future<int> archiveOldPhotos(DateTime before, {int limit = 40}) async {
    final snap = await _orders
        .where('updatedAt', isLessThan: Timestamp.fromDate(before))
        .orderBy('updatedAt')
        .limit(limit)
        .get();
    var removed = 0;
    for (final d in snap.docs) {
      final status = OrderStatus.parse(d.data()['status'] as String?);
      if (status != OrderStatus.delivered && status != OrderStatus.cancelled) {
        continue;
      }
      for (final sub in [
        FirestorePaths.receipts(d.id),
        FirestorePaths.proofs(d.id),
      ]) {
        final photos = await _db.collection(sub).get();
        for (final p in photos.docs) {
          await p.reference.delete();
          removed++;
        }
      }
    }
    return removed;
  }

  @override
  Future<void> addReport(OrderReport r) => _db.collection('reports').add({
    ...r.toNewMap(),
    'createdAt': FieldValue.serverTimestamp(),
  });

  @override
  Stream<List<OrderReport>> watchOrderReports(
    String orderId,
    String customerId,
  ) => _db
      .collection('reports')
      .where('customerId', isEqualTo: customerId)
      .where('orderId', isEqualTo: orderId)
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) OrderReport.fromMap(d.id, d.data())]
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            ),
          ),
      );

  @override
  Stream<List<OrderReport>> watchCustomerReports(String customerId) => _db
      .collection('reports')
      .where('customerId', isEqualTo: customerId)
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) OrderReport.fromMap(d.id, d.data())]
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            ),
          ),
      );

  @override
  Stream<List<OrderReport>> watchRiderReports(String orderId, String riderId) =>
      _db
          .collection('reports')
          .where('riderId', isEqualTo: riderId)
          .where('by', isEqualTo: 'rider')
          .snapshots()
          .map(
            (s) =>
                [
                  for (final d in s.docs)
                    if (d.data()['orderId'] == orderId)
                      OrderReport.fromMap(d.id, d.data()),
                ]..sort(
                  (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
                    a.createdAt ?? DateTime(0),
                  ),
                ),
          );

  @override
  Stream<List<OrderReport>> watchReports({int limit = 200}) => _db
      .collection('reports')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) OrderReport.fromMap(d.id, d.data())],
      );

  @override
  Future<void> resolveReport(
    String id, {
    required String reply,
    bool resolved = true,
    String refund = 'none',
  }) => _db.collection('reports').doc(id).update({
    'refund': refund,
    'reply': reply,
    'status': resolved ? 'resolved' : 'open',
    'resolvedAt': resolved ? FieldValue.serverTimestamp() : null,
  });

  @override
  Stream<RiderStats?> watchRiderStats(String riderId) => _db
      .collection('riderStats')
      .doc(riderId)
      .snapshots()
      .map((d) => d.exists ? RiderStats.fromMap(d.id, d.data()!) : null);

  @override
  Future<void> saveRiderStats(String riderId, double average, int count) => _db
      .collection('riderStats')
      .doc(riderId)
      .set({'average': average, 'count': count});

  @override
  Future<void> addDeliveryProof(
    String orderId, {
    required String uid,
    required String data,
  }) => _db.collection(FirestorePaths.proofs(orderId)).add({
    'uid': uid,
    'data': data,
    'createdAt': FieldValue.serverTimestamp(),
  });

  @override
  Stream<List<PaymentReceipt>> watchDeliveryProofs(String orderId) => _db
      .collection(FirestorePaths.proofs(orderId))
      .orderBy('createdAt')
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) PaymentReceipt.fromMap(d.id, d.data())],
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
  Future<void> sendPaymentRequest(String orderId, PaymentRequest r) =>
      _orders.doc(orderId).update({
        'paymentRequest': {
          ...r.toMap(),
          'sentAt': FieldValue.serverTimestamp(),
        },
        'paymentIssue': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> setPaymentIssue(String orderId, String issue) =>
      _orders.doc(orderId).update({
        'paymentIssue': issue.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> addReceipt(
    String orderId, {
    required String uid,
    required String data,
    String note = '',
  }) async {
    final batch = _db.batch();
    batch.set(_db.collection(FirestorePaths.receipts(orderId)).doc(), {
      'uid': uid,
      'data': data,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_orders.doc(orderId), {
      'receiptAt': FieldValue.serverTimestamp(),
      'paymentIssue': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  @override
  Stream<List<PaymentReceipt>> watchReceipts(String orderId) => _db
      .collection(FirestorePaths.receipts(orderId))
      .orderBy('createdAt')
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) PaymentReceipt.fromMap(d.id, d.data())],
      );

  @override
  Future<void> markPaid(String orderId, String by) =>
      _orders.doc(orderId).update({
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
  Future<void> unassignRider(String orderId, String adminId) => _setStatus(
    orderId,
    OrderStatus.confirmed,
    adminId,
    note: 'Taken back from the rider',
    extra: {'riderId': null, 'riderName': null, 'riderPhone': null},
  );

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
    bool markPaid = true,
  }) => _setStatus(
    orderId,
    OrderStatus.delivered,
    riderId,
    extra: {
      'cashCollected': cashCollected,
      'emptiesCollected': emptiesCollected,
      if (cashCollected > 0 && markPaid)
        'paymentStatus': PaymentStatus.paid.name,
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
        (s) => [for (final d in s.docs) OrderMessage.fromMap(d.id, d.data())],
      );

  @override
  Stream<Map<MessageRole, DateTime>> watchChatReads(String orderId) =>
      _db.collection(FirestorePaths.chatReads(orderId)).snapshots().map((s) {
        final out = <MessageRole, DateTime>{};
        for (final d in s.docs) {
          final at = readDate(d.data()['at']);
          if (at != null) out[MessageRole.parse(d.id)] = at;
        }
        return out;
      });

  @override
  Future<void> markChatRead(String orderId, MessageRole role) => _db
      .doc('${FirestorePaths.chatReads(orderId)}/${role.name}')
      .set({'at': FieldValue.serverTimestamp()});

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
  }) async {
    await _orders.doc(id).update({
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
    if (status == OrderStatus.cancelled) await _releaseCoupon(id);
  }

  /// A cancelled order gives its discount code back to the customer.
  Future<void> _releaseCoupon(String id) async {
    try {
      final d = (await _orders.doc(id).get()).data();
      final code = d?['couponCode'] as String? ?? '';
      final uid = d?['customerId'] as String? ?? '';
      if (code.isEmpty || uid.isEmpty) return;
      await _db.doc(FirestorePaths.couponUse(code, uid)).delete();
    } catch (_) {
      // Best effort: the shop can also hand the code back.
    }
  }
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
    if (order.couponCode.isNotEmpty) {
      final path = FirestorePaths.couponUse(order.couponCode, order.customerId);
      final k = path.lastIndexOf('/');
      _s.set(path.substring(0, k), path.substring(k + 1), {
        'orderId': id,
        'at': now,
      });
    }
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
  Future<void> submitPayment(
    String orderId, {
    required String uid,
    required String reference,
    required int amount,
    String? data,
    String note = '',
  }) async {
    if (data != null && data.isNotEmpty) {
      _s.set(FirestorePaths.receipts(orderId), _s.newId(), {
        'uid': uid,
        'data': data,
        'note': note,
        'createdAt': DateTime.now(),
      });
    }
    _s.update(
      _path,
      orderId,
      (d) => {
        ...d,
        'paymentReference': reference.trim(),
        'paidAmount': amount,
        'receiptAt': DateTime.now(),
        'paymentIssue': '',
        'updatedAt': DateTime.now(),
      },
    );
  }

  @override
  Future<int> archiveOldPhotos(DateTime before, {int limit = 40}) async {
    var removed = 0;
    for (final e in _s.collection(_path).entries.toList().take(limit)) {
      final status = OrderStatus.parse(e.value['status'] as String?);
      final at = readDate(e.value['updatedAt']);
      if ((status != OrderStatus.delivered &&
              status != OrderStatus.cancelled) ||
          at == null ||
          !at.isBefore(before)) {
        continue;
      }
      for (final sub in [
        FirestorePaths.receipts(e.key),
        FirestorePaths.proofs(e.key),
      ]) {
        for (final id in _s.collection(sub).keys.toList()) {
          _s.delete(sub, id);
          removed++;
        }
      }
    }
    return removed;
  }

  @override
  Future<void> addReport(OrderReport r) async => _s.set('reports', _s.newId(), {
    ...r.toNewMap(),
    'createdAt': DateTime.now(),
  });

  @override
  Stream<List<OrderReport>> watchOrderReports(
    String orderId,
    String customerId,
  ) => watchReports().map(
    (l) => [
      for (final r in l)
        if (r.orderId == orderId && r.customerId == customerId) r,
    ],
  );

  @override
  Stream<List<OrderReport>> watchCustomerReports(String customerId) =>
      watchReports().map(
        (l) => [
          for (final r in l)
            if (r.customerId == customerId) r,
        ],
      );

  @override
  Stream<List<OrderReport>> watchRiderReports(String orderId, String riderId) =>
      watchReports().map(
        (l) => [
          for (final r in l)
            if (r.orderId == orderId && r.riderId == riderId && r.fromRider) r,
        ],
      );

  @override
  Stream<List<OrderReport>> watchReports({int limit = 200}) =>
      _s.watch('reports', (docs) {
        final l =
            [for (final e in docs.entries) OrderReport.fromMap(e.key, e.value)]
              ..sort(
                (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
                  a.createdAt ?? DateTime(0),
                ),
              );
        return l.take(limit).toList();
      });

  @override
  Future<void> resolveReport(
    String id, {
    required String reply,
    bool resolved = true,
    String refund = 'none',
  }) async => _s.update(
    'reports',
    id,
    (d) => {
      ...d,
      'refund': refund,
      'reply': reply,
      'status': resolved ? 'resolved' : 'open',
      'resolvedAt': resolved ? DateTime.now() : null,
    },
  );

  @override
  Stream<RiderStats?> watchRiderStats(String riderId) =>
      _s.watch('riderStats', (docs) {
        final d = docs[riderId];
        return d == null ? null : RiderStats.fromMap(riderId, d);
      });

  @override
  Future<void> saveRiderStats(
    String riderId,
    double average,
    int count,
  ) async =>
      _s.set('riderStats', riderId, {'average': average, 'count': count});

  @override
  Future<void> addDeliveryProof(
    String orderId, {
    required String uid,
    required String data,
  }) async => _s.set(FirestorePaths.proofs(orderId), _s.newId(), {
    'uid': uid,
    'data': data,
    'createdAt': DateTime.now(),
  });

  @override
  Stream<List<PaymentReceipt>> watchDeliveryProofs(String orderId) => _s.watch(
    FirestorePaths.proofs(orderId),
    (docs) {
      final l =
          [for (final e in docs.entries) PaymentReceipt.fromMap(e.key, e.value)]
            ..sort(
              (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
                b.createdAt ?? DateTime(0),
              ),
            );
      return l;
    },
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
  Future<void> sendPaymentRequest(String orderId, PaymentRequest r) async =>
      _s.update(
        _path,
        orderId,
        (d) => {
          ...d,
          'paymentRequest': {...r.toMap(), 'sentAt': DateTime.now()},
          'paymentIssue': '',
          'updatedAt': DateTime.now(),
        },
      );

  @override
  Future<void> setPaymentIssue(String orderId, String issue) async => _s.update(
    _path,
    orderId,
    (d) => {...d, 'paymentIssue': issue.trim(), 'updatedAt': DateTime.now()},
  );

  @override
  Future<void> addReceipt(
    String orderId, {
    required String uid,
    required String data,
    String note = '',
  }) async {
    _s.set(FirestorePaths.receipts(orderId), _s.newId(), {
      'uid': uid,
      'data': data,
      'note': note,
      'createdAt': DateTime.now(),
    });
    _s.update(
      _path,
      orderId,
      (d) => {
        ...d,
        'receiptAt': DateTime.now(),
        'paymentIssue': '',
        'updatedAt': DateTime.now(),
      },
    );
  }

  @override
  Stream<List<PaymentReceipt>> watchReceipts(String orderId) => _s.watch(
    FirestorePaths.receipts(orderId),
    (docs) {
      final list =
          [for (final e in docs.entries) PaymentReceipt.fromMap(e.key, e.value)]
            ..sort(
              (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
                b.createdAt ?? DateTime(0),
              ),
            );
      return list;
    },
  );

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
  Future<void> unassignRider(String orderId, String adminId) async =>
      _setStatus(
        orderId,
        OrderStatus.confirmed,
        adminId,
        note: 'Taken back from the rider',
        extra: {'riderId': null, 'riderName': null, 'riderPhone': null},
      );

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
  Future<void> markArrived(String orderId, String riderId) async => _s.update(
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
    bool markPaid = true,
  }) async => _setStatus(
    orderId,
    OrderStatus.delivered,
    riderId,
    extra: {
      'cashCollected': cashCollected,
      'emptiesCollected': emptiesCollected,
      if (cashCollected > 0 && markPaid)
        'paymentStatus': PaymentStatus.paid.name,
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
        final list =
            [for (final e in docs.entries) OrderMessage.fromMap(e.key, e.value)]
              ..sort(
                (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
                  b.createdAt ?? DateTime(0),
                ),
              );
        return list;
      });

  @override
  Stream<Map<MessageRole, DateTime>> watchChatReads(String orderId) =>
      _s.watch(FirestorePaths.chatReads(orderId), (docs) {
        final out = <MessageRole, DateTime>{};
        for (final e in docs.entries) {
          final at = readDate(e.value['at']);
          if (at != null) out[MessageRole.parse(e.key)] = at;
        }
        return out;
      });

  @override
  Future<void> markChatRead(String orderId, MessageRole role) async => _s.set(
    FirestorePaths.chatReads(orderId),
    role.name,
    {'at': DateTime.now()},
  );

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
  }) {
    _s.update(
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
    if (status == OrderStatus.cancelled) {
      final d = _s.get(_path, id);
      final code = d?['couponCode'] as String? ?? '';
      final uid = d?['customerId'] as String? ?? '';
      if (code.isNotEmpty) {
        final path = FirestorePaths.couponUse(code, uid);
        final k = path.lastIndexOf('/');
        _s.delete(path.substring(0, k), path.substring(k + 1));
      }
    }
  }
}
