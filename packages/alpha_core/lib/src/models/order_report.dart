import '../dates.dart';

/// A customer's complaint about an order or its rider, sent straight to the
/// shop (`reports/{id}`), not into the chat.
class OrderReport {
  const OrderReport({
    this.id = '',
    required this.orderId,
    this.orderNumber = '',
    required this.customerId,
    this.customerName = '',
    this.customerPhone = '',
    this.riderId,
    this.riderName,
    this.about = 'order',
    this.by = 'customer',
    required this.reason,
    this.details = '',
    this.status = 'open',
    this.reply = '',
    this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String orderId;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? riderId;
  final String? riderName;

  /// 'order' or 'rider'.
  final String about;

  /// Who sent it: 'customer' or 'rider' (a problem on the way, such as
  /// "customer not answering").
  final String by;
  bool get fromRider => by == 'rider';
  final String reason;
  final String details;

  /// 'open' until the shop marks it 'resolved'.
  final String status;

  /// The shop's answer, shown to the customer.
  final String reply;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  bool get isOpen => status != 'resolved';
  bool get aboutRider => about == 'rider';

  factory OrderReport.fromMap(String id, Map<String, dynamic> m) => OrderReport(
    id: id,
    orderId: m['orderId'] as String? ?? '',
    orderNumber: m['orderNumber'] as String? ?? '',
    customerId: m['customerId'] as String? ?? '',
    customerName: m['customerName'] as String? ?? '',
    customerPhone: m['customerPhone'] as String? ?? '',
    riderId: m['riderId'] as String?,
    riderName: m['riderName'] as String?,
    about: m['about'] == 'rider' ? 'rider' : 'order',
    by: m['by'] == 'rider' ? 'rider' : 'customer',
    reason: m['reason'] as String? ?? '',
    details: m['details'] as String? ?? '',
    status: m['status'] == 'resolved' ? 'resolved' : 'open',
    reply: m['reply'] as String? ?? '',
    createdAt: readDate(m['createdAt']),
    resolvedAt: readDate(m['resolvedAt']),
  );

  Map<String, dynamic> toNewMap() => {
    'orderId': orderId,
    'orderNumber': orderNumber,
    'customerId': customerId,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'riderId': riderId,
    'riderName': riderName,
    'about': about,
    'by': by,
    'reason': reason,
    'details': details,
    'status': 'open',
    'reply': '',
  };
}

/// A rider's public star rating (`riderStats/{uid}`), kept up to date by the
/// shop so customers can see who is coming.
class RiderStats {
  const RiderStats({this.uid = '', this.average = 0, this.count = 0});
  final String uid;
  final double average;
  final int count;

  factory RiderStats.fromMap(String uid, Map<String, dynamic> m) => RiderStats(
    uid: uid,
    average: (m['average'] as num?)?.toDouble() ?? 0,
    count: (m['count'] as num?)?.toInt() ?? 0,
  );
}
