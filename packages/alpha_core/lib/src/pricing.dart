import 'models/app_settings.dart';
import 'models/order.dart';
import 'models/ordering_status.dart';

/// The single source of truth for order totals on the client.
/// `firebase/functions/src/pricing.ts` mirrors these rules on the server and
/// re-prices every new order, so a tampered client cannot change the total.
class PriceBreakdown {
  const PriceBreakdown({
    required this.subtotal,
    required this.deliveryFee,
    required this.cylinders,
    this.accessories = 0,
    this.lines = 0,
    this.couponDiscount = 0,
    this.pointsUsed = 0,
    this.pointsDiscount = 0,
  });

  final int subtotal;
  final int deliveryFee;
  final int cylinders;

  /// Stoves, regulators and other non-gas items.
  final int accessories;

  /// "3 items" / "2 cylinders" for captions.
  String get countLabel {
    final n = cylinders + accessories;
    final noun = accessories == 0 ? 'cylinder' : 'item';
    return '$n $noun${n == 1 ? '' : 's'}';
  }

  /// Different items (product × refill/new) in the order.
  final int lines;

  /// The most different items one order can hold (also enforced by the
  /// security rules).
  static const maxLines = 6;

  /// Rupees taken off by a discount code, and by spending points.
  final int couponDiscount;
  final int pointsUsed;
  final int pointsDiscount;

  int get discount => couponDiscount + pointsDiscount;
  int get total => subtotal + deliveryFee - discount;
  bool get freeDelivery => deliveryFee == 0;

  static PriceBreakdown of(
    List<OrderItem> items,
    AppSettings s, {
    String area = '',
  }) {
    final subtotal = items.fold(0, (sum, i) => sum + i.lineTotal);
    final cylinders = items
        .where((i) => !i.isAccessory)
        .fold(0, (n, i) => n + i.quantity);
    final free =
        subtotal == 0 ||
        (s.freeDeliveryFrom > 0 && subtotal >= s.freeDeliveryFrom);
    return PriceBreakdown(
      subtotal: subtotal,
      deliveryFee: free ? 0 : s.feeForArea(area),
      cylinders: cylinders,
      accessories: items
          .where((i) => i.isAccessory)
          .fold(0, (n, i) => n + i.quantity),
      lines: items.length,
    );
  }

  /// The same prices with a discount code and/or points applied.
  PriceBreakdown withDiscounts({
    int couponDiscount = 0,
    int pointsUsed = 0,
    int pointValue = 1,
  }) => PriceBreakdown(
    subtotal: subtotal,
    deliveryFee: deliveryFee,
    cylinders: cylinders,
    accessories: accessories,
    lines: lines,
    couponDiscount: couponDiscount,
    pointsUsed: pointsUsed,
    pointsDiscount: pointsUsed * pointValue,
  );

  /// Most points that can be spent on this order: the balance, capped by the
  /// shop's percentage of the price (and by what is left after a code).
  static int maxPoints(
    int subtotal,
    int couponDiscount,
    int balance,
    AppSettings s,
  ) {
    if (s.pointValue <= 0) return 0;
    final byPercent = subtotal * s.maxPointsPercent ~/ 100;
    final byPrice = subtotal - couponDiscount;
    final cap = (byPercent < byPrice ? byPercent : byPrice) ~/ s.pointValue;
    return cap < 0 ? 0 : (cap < balance ? cap : balance);
  }

  /// Why the order cannot be placed yet, or null if it can.
  String? problem(AppSettings s, {OrderingStatus? status}) {
    if (status != null && !status.canOrder) return status.message;
    if (!s.acceptingOrders) {
      return s.closedMessage.isNotEmpty
          ? s.closedMessage
          : 'We are not taking online orders right now. Please call us.';
    }
    if (lines == 0) return 'Your cart is empty.';
    if (lines > maxLines) {
      return 'One order can have up to $maxLines different items. Please place the rest as a second order.';
    }
    if (cylinders > s.maxCylindersPerOrder) {
      return 'One order can have up to ${s.maxCylindersPerOrder} cylinders. For more, send a bulk order request and we will call you with a price.';
    }
    if (subtotal < s.minOrderTotal) {
      return 'Minimum order is ${formatRupees(s.minOrderTotal)}.';
    }
    return null;
  }
}

/// "Rs. 12,682"
String formatRupees(int amount) {
  final digits = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}Rs. $buf';
}
