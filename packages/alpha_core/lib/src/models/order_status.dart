/// Lifecycle of an order. The customer app creates orders as [placed];
/// the admin app confirms and assigns a rider; the rider app moves the order
/// to [outForDelivery] and [delivered].
enum OrderStatus {
  placed('Order placed', 'We have received your order'),
  confirmed('Confirmed', 'Alpha LPG has confirmed your order'),
  assigned('Rider assigned', 'A rider is preparing your cylinders'),
  outForDelivery('Out for delivery', 'Your rider is on the way'),
  delivered('Delivered', 'Cylinders delivered. Stay safe!'),
  cancelled('Cancelled', 'This order was cancelled');

  const OrderStatus(this.label, this.description);
  final String label;
  final String description;

  static OrderStatus parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => placed);

  /// The happy-path steps shown in the tracking timeline.
  static const journey = [
    placed,
    confirmed,
    assigned,
    outForDelivery,
    delivered,
  ];

  bool get isActive => this != delivered && this != cancelled;

  /// Customers may cancel only before the order is confirmed.
  bool get customerCanCancel => this == placed;
}

enum PaymentMethod {
  cashOnDelivery('Cash on delivery'),
  jazzCash('JazzCash'),
  easyPaisa('Easypaisa'),
  bankTransfer('Bank transfer');

  const PaymentMethod(this.label);
  final String label;

  /// Methods the customer app currently offers. The others are planned and
  /// already understood by the admin app and Cloud Functions.
  static const available = [cashOnDelivery, bankTransfer];

  static PaymentMethod parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => cashOnDelivery);
}

enum PaymentStatus {
  pending,
  paid,
  refunded;

  static PaymentStatus parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => pending);
}
