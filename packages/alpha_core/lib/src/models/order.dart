import '../dates.dart';
import 'address.dart';
import 'order_status.dart';
import 'product.dart';

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.sizeKg,
    required this.type,
    required this.unitPrice,
    required this.quantity,
  });

  final String productId;
  final String name;
  final double sizeKg;
  final PurchaseType type;
  final int unitPrice;
  final int quantity;

  int get lineTotal => unitPrice * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
    productId: m['productId'] as String? ?? '',
    name: m['name'] as String? ?? '',
    sizeKg: (m['sizeKg'] as num?)?.toDouble() ?? 0,
    type: PurchaseType.parse(m['type'] as String?),
    unitPrice: (m['unitPrice'] as num?)?.round() ?? 0,
    quantity: (m['quantity'] as num?)?.toInt() ?? 1,
  );

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'name': name,
    'sizeKg': sizeKg,
    'type': type.name,
    'unitPrice': unitPrice,
    'quantity': quantity,
  };
}

class StatusEvent {
  const StatusEvent({
    required this.status,
    required this.at,
    this.by = '',
    this.note = '',
  });

  final OrderStatus status;
  final DateTime at;
  final String by; // uid of customer / admin / rider
  final String note;

  factory StatusEvent.fromMap(Map<String, dynamic> m) => StatusEvent(
    status: OrderStatus.parse(m['status'] as String?),
    at: readDate(m['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    by: m['by'] as String? ?? '',
    note: m['note'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'status': status.name,
    'at': at,
    'by': by,
    'note': note,
  };
}

/// An order document in `orders/{id}`. Shared by all three apps.
class LpgOrder {
  const LpgOrder({
    this.id = '',
    this.orderNumber = '',
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerType = CustomerSegment.home,
    this.businessName = '',
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.address,
    this.paymentMethod = PaymentMethod.cashOnDelivery,
    this.paymentStatus = PaymentStatus.pending,
    this.status = OrderStatus.placed,
    this.history = const [],
    this.scheduledFor,
    this.notes = '',
    this.riderId,
    this.riderName,
    this.riderPhone,
    this.cancelReason = '',
    this.rating,
    this.feedback = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final CustomerSegment customerType;
  final String businessName;
  final List<OrderItem> items;
  final int subtotal;
  final int deliveryFee;
  final int total;
  final Address address;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final OrderStatus status;
  final List<StatusEvent> history;

  /// Null means "deliver as soon as possible".
  final DateTime? scheduledFor;
  final String notes;
  final String? riderId;
  final String? riderName;
  final String? riderPhone;
  final String cancelReason;

  /// 1–5 stars left by the customer after delivery.
  final int? rating;
  final String feedback;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get canBeRated => status == OrderStatus.delivered && rating == null;

  int get cylinderCount => items.fold(0, (n, i) => n + i.quantity);

  /// Empties the rider should collect (one per refill cylinder).
  int get emptiesToCollect => items
      .where((i) => i.type == PurchaseType.refill)
      .fold(0, (n, i) => n + i.quantity);

  String get displayNumber => orderNumber.isNotEmpty
      ? orderNumber
      : '#${id.substring(0, 6).toUpperCase()}';

  DateTime? timeOf(OrderStatus s) {
    for (final e in history.reversed) {
      if (e.status == s) return e.at;
    }
    return null;
  }

  factory LpgOrder.fromMap(String id, Map<String, dynamic> m) => LpgOrder(
    id: id,
    orderNumber: m['orderNumber'] as String? ?? '',
    customerId: m['customerId'] as String? ?? '',
    customerName: m['customerName'] as String? ?? '',
    customerPhone: m['customerPhone'] as String? ?? '',
    customerType: CustomerSegment.parse(m['customerType'] as String?),
    businessName: m['businessName'] as String? ?? '',
    items: [
      for (final i in (m['items'] as List? ?? const []))
        OrderItem.fromMap(Map<String, dynamic>.from(i as Map)),
    ],
    subtotal: (m['subtotal'] as num?)?.round() ?? 0,
    deliveryFee: (m['deliveryFee'] as num?)?.round() ?? 0,
    total: (m['total'] as num?)?.round() ?? 0,
    address: Address.fromMap(
      '',
      Map<String, dynamic>.from(m['address'] as Map? ?? const {}),
    ),
    paymentMethod: PaymentMethod.parse(m['paymentMethod'] as String?),
    paymentStatus: PaymentStatus.parse(m['paymentStatus'] as String?),
    status: OrderStatus.parse(m['status'] as String?),
    history: [
      for (final e in (m['history'] as List? ?? const []))
        StatusEvent.fromMap(Map<String, dynamic>.from(e as Map)),
    ],
    scheduledFor: readDate(m['scheduledFor']),
    notes: m['notes'] as String? ?? '',
    riderId: m['riderId'] as String?,
    riderName: m['riderName'] as String?,
    riderPhone: m['riderPhone'] as String?,
    cancelReason: m['cancelReason'] as String? ?? '',
    rating: (m['rating'] as num?)?.toInt(),
    feedback: m['feedback'] as String? ?? '',
    createdAt: readDate(m['createdAt']),
    updatedAt: readDate(m['updatedAt']),
  );

  Map<String, dynamic> toMap() => {
    'orderNumber': orderNumber,
    'customerId': customerId,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'customerType': customerType.name,
    'businessName': businessName,
    'items': [for (final i in items) i.toMap()],
    'subtotal': subtotal,
    'deliveryFee': deliveryFee,
    'total': total,
    'address': address.toMap(),
    'paymentMethod': paymentMethod.name,
    'paymentStatus': paymentStatus.name,
    'status': status.name,
    'history': [for (final e in history) e.toMap()],
    'scheduledFor': scheduledFor,
    'notes': notes,
    'riderId': riderId,
    'riderName': riderName,
    'riderPhone': riderPhone,
    'cancelReason': cancelReason,
    'rating': rating,
    'feedback': feedback,
    'cylinderCount': cylinderCount,
    'emptiesToCollect': emptiesToCollect,
  };
}
