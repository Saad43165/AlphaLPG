import '../dates.dart';

/// A discount code the shop made ("WELCOME200").
class Coupon {
  const Coupon({
    required this.code,
    this.title = '',
    this.percent = false,
    this.value = 0,
    this.maxDiscount = 0,
    this.minOrder = 0,
    this.active = true,
    this.expiresAt,
  });

  /// Upper case, no spaces. Also the document id.
  final String code;
  final String title;

  /// True: [value] is a percentage (capped by [maxDiscount]). False: rupees.
  final bool percent;
  final int value;

  /// Cap for a percentage coupon, in rupees. 0 = no cap.
  final int maxDiscount;
  final int minOrder;
  final bool active;
  final DateTime? expiresAt;

  static String clean(String input) =>
      input.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  bool get isReferral => code.startsWith('REF-');

  /// Rupees off an order with this [subtotal]. 0 when it does not apply.
  int discountFor(int subtotal) {
    if (!active || subtotal < minOrder || value <= 0) return 0;
    var d = percent ? subtotal * value ~/ 100 : value;
    if (percent && maxDiscount > 0 && d > maxDiscount) d = maxDiscount;
    return d > subtotal ? subtotal : d;
  }

  /// Why this code cannot be used right now (null when it can).
  String? problem(int subtotal, {DateTime? now}) {
    if (!active) return 'This code is not active.';
    final t = now ?? DateTime.now();
    if (expiresAt != null && t.isAfter(expiresAt!)) {
      return 'This code has expired.';
    }
    if (subtotal < minOrder) {
      return 'This code needs an order of at least Rs. $minOrder.';
    }
    return null;
  }

  /// "Rs. 200 off" / "10% off (up to Rs. 500)"
  String get summary => percent
      ? '$value% off${maxDiscount > 0 ? ' (up to Rs. $maxDiscount)' : ''}'
      : 'Rs. $value off';

  factory Coupon.fromMap(String code, Map<String, dynamic> m) => Coupon(
    code: code,
    title: m['title'] as String? ?? '',
    percent: m['type'] == 'percent',
    value: (m['value'] as num?)?.round() ?? 0,
    maxDiscount: (m['maxDiscount'] as num?)?.round() ?? 0,
    minOrder: (m['minOrder'] as num?)?.round() ?? 0,
    active: m['active'] as bool? ?? true,
    expiresAt: readDate(m['expiresAt']),
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'type': percent ? 'percent' : 'amount',
    'value': value,
    'maxDiscount': maxDiscount,
    'minOrder': minOrder,
    'active': active,
    'expiresAt': expiresAt,
  };
}

/// A customer's reward points ("Alpha Points").
class LoyaltyAccount {
  const LoyaltyAccount({this.points = 0, this.lifetime = 0});
  final int points;
  final int lifetime;

  factory LoyaltyAccount.fromMap(Map<String, dynamic> m) => LoyaltyAccount(
    points: (m['points'] as num?)?.toInt() ?? 0,
    lifetime: (m['lifetime'] as num?)?.toInt() ?? 0,
  );
}

/// One line of a customer's points history.
class LoyaltyEntry {
  const LoyaltyEntry({
    required this.delta,
    required this.reason,
    this.orderId = '',
    this.at,
  });
  final int delta;
  final String reason;
  final String orderId;
  final DateTime? at;

  factory LoyaltyEntry.fromMap(Map<String, dynamic> m) => LoyaltyEntry(
    delta: (m['delta'] as num?)?.toInt() ?? 0,
    reason: m['reason'] as String? ?? '',
    orderId: m['orderId'] as String? ?? '',
    at: readDate(m['at']),
  );
}

/// Public numbers the home screen shows ("4.8 · 320 deliveries").
class PublicStats {
  const PublicStats({
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.deliveredCount = 0,
  });
  final double ratingAverage;
  final int ratingCount;
  final int deliveredCount;

  /// Enough reviews to be worth showing.
  bool get showable => ratingCount >= 5 && ratingAverage > 0;

  factory PublicStats.fromMap(Map<String, dynamic> m) => PublicStats(
    ratingAverage: (m['ratingAverage'] as num?)?.toDouble() ?? 0,
    ratingCount: (m['ratingCount'] as num?)?.toInt() ?? 0,
    deliveredCount: (m['deliveredCount'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'ratingAverage': double.parse(ratingAverage.toStringAsFixed(2)),
    'ratingCount': ratingCount,
    'deliveredCount': deliveredCount,
  };
}

/// A repeat order the customer set up ("same again every month").
class RefillPlan {
  const RefillPlan({
    required this.lines,
    this.everyDays = 30,
    this.paymentMethod = 'cashOnDelivery',
    this.nextDue,
    this.active = true,
  });

  /// `productId`, `type` ('refill' / 'newCylinder') and `quantity` per line.
  final List<Map<String, dynamic>> lines;
  final int everyDays;
  final String paymentMethod;
  final DateTime? nextDue;
  final bool active;

  int get cylinders =>
      lines.fold(0, (n, l) => n + ((l['quantity'] as num?)?.toInt() ?? 0));

  bool isDue([DateTime? now]) =>
      active && nextDue != null && !(now ?? DateTime.now()).isBefore(nextDue!);

  RefillPlan copyWith({DateTime? nextDue, bool? active}) => RefillPlan(
    lines: lines,
    everyDays: everyDays,
    paymentMethod: paymentMethod,
    nextDue: nextDue ?? this.nextDue,
    active: active ?? this.active,
  );

  factory RefillPlan.fromMap(Map<String, dynamic> m) => RefillPlan(
    lines: [
      for (final l in (m['lines'] as List? ?? const []))
        Map<String, dynamic>.from(l as Map),
    ],
    everyDays: (m['everyDays'] as num?)?.toInt() ?? 30,
    paymentMethod: m['paymentMethod'] as String? ?? 'cashOnDelivery',
    nextDue: readDate(m['nextDue']),
    active: m['active'] as bool? ?? true,
  );

  Map<String, dynamic> toMap() => {
    'lines': lines,
    'everyDays': everyDays,
    'paymentMethod': paymentMethod,
    'nextDue': nextDue,
    'active': active,
  };
}
