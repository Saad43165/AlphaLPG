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
  bankTransfer('Bank transfer / Raast');

  const PaymentMethod(this.label);
  final String label;

  /// Methods offered at checkout. Wallet and bank payments are manual
  /// transfers to Alpha LPG's accounts (see [AppSettings]); the customer can
  /// add the transaction ID and the admin marks the order paid.
  static const available = [cashOnDelivery, jazzCash, easyPaisa, bankTransfer];

  bool get isPrepaid => this != cashOnDelivery;

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
