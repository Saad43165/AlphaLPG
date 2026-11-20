/// A cylinder the customer can order (6kg, 10kg composite, 11.8kg, 45.4kg …).
///
/// Prices are whole rupees. [refillPrice] is the gas price when the customer
/// hands over an empty cylinder. [newCylinderPrice] is the price including a
/// brand-new cylinder; null means new cylinders are not sold online.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sizeKg,
    required this.refillPrice,
    this.newCylinderPrice,
    this.description = '',
    this.badge = '',
    this.imageUrl = '',
    this.imageAsset = '',
    this.segment = CustomerSegment.both,
    this.active = true,
    this.inStock = true,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final double sizeKg;
  final int refillPrice;
  final int? newCylinderPrice;
  final String description;
  final String badge;
  final String imageUrl;
  final String imageAsset;
  final CustomerSegment segment;
  final bool active;
  final bool inStock;
  final int sortOrder;

  String get sizeLabel =>
      '${sizeKg == sizeKg.roundToDouble() ? sizeKg.toInt() : sizeKg} KG';

  bool get sellsNewCylinder => newCylinderPrice != null;

  int priceFor(PurchaseType type) => switch (type) {
    PurchaseType.refill => refillPrice,
    PurchaseType.newCylinder => newCylinderPrice ?? refillPrice,
  };

  factory Product.fromMap(String id, Map<String, dynamic> m) => Product(
    id: id,
    name: m['name'] as String? ?? '',
    sizeKg: (m['sizeKg'] as num?)?.toDouble() ?? 0,
    refillPrice: (m['refillPrice'] as num?)?.round() ?? 0,
    newCylinderPrice: (m['newCylinderPrice'] as num?)?.round(),
    description: m['description'] as String? ?? '',
    badge: m['badge'] as String? ?? '',
    imageUrl: m['imageUrl'] as String? ?? '',
    imageAsset: m['imageAsset'] as String? ?? '',
    segment: CustomerSegment.parse(m['segment'] as String?),
    active: m['active'] as bool? ?? true,
    inStock: m['inStock'] as bool? ?? true,
    sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'sizeKg': sizeKg,
    'refillPrice': refillPrice,
    'newCylinderPrice': newCylinderPrice,
    'description': description,
    'badge': badge,
    'imageUrl': imageUrl,
    'imageAsset': imageAsset,
    'segment': segment.name,
    'active': active,
    'inStock': inStock,
    'sortOrder': sortOrder,
  };
}

enum PurchaseType {
  refill('Refill', 'Exchange your empty cylinder'),
  newCylinder('New cylinder', 'Includes a new Alpha cylinder');

  const PurchaseType(this.label, this.hint);
  final String label;
  final String hint;

  static PurchaseType parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => refill);
}

/// Who a product (or a customer) is aimed at.
enum CustomerSegment {
  home('Home'),
  business('Business'),
  both('Home & business');

  const CustomerSegment(this.label);
  final String label;

  static CustomerSegment parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => both);
}
