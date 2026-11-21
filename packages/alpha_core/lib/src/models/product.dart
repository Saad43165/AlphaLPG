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
    this.imageData = '',
    this.segment = CustomerSegment.both,
    this.active = true,
    this.inStock = true,
    this.stock,
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

  /// A photo uploaded by the shop owner, stored right in the product as
  /// base64 (JPEG or PNG, kept small). Works on the free Firebase plan, which
  /// has no file storage. Empty means "use the automatic picture".
  final String imageData;

  bool get hasUploadedImage => imageData.isNotEmpty;

  /// The bundled cylinder picture closest in size, used when no photo has
  /// been uploaded (so a new size always shows a sensible image).
  String get automaticImageAsset {
    if (imageAsset.isNotEmpty) return imageAsset;
    const known = <(double, String)>[
      (6.0, 'assets/products/6kg.png'),
      (10.0, 'assets/products/10kg.png'),
      (11.8, 'assets/products/11_8kg.png'),
      (45.4, 'assets/products/45_4kg.png'),
    ];
    var best = known.first;
    for (final e in known) {
      if ((e.$1 - sizeKg).abs() < (best.$1 - sizeKg).abs()) best = e;
    }
    return best.$2;
  }

  final CustomerSegment segment;
  final bool active;
  final bool inStock;

  /// Cylinders in the shop. Null means "not counting stock". When a count is
  /// set, the shop's confirmed orders take from it, and at 0 the product shows
  /// as out of stock.
  final int? stock;
  final int sortOrder;

  /// "Only 3 left" for the customer when stock is low (null otherwise).
  int? get lowStock =>
      (stock != null && stock! > 0 && stock! <= 5) ? stock : null;

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
    imageData: m['imageData'] as String? ?? '',
    segment: CustomerSegment.parse(m['segment'] as String?),
    active: m['active'] as bool? ?? true,
    inStock: m['inStock'] as bool? ?? true,
    stock: (m['stock'] as num?)?.round(),
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
    'imageData': imageData,
    'segment': segment.name,
    'active': active,
    'inStock': inStock,
    if (stock != null) 'stock': stock,
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
