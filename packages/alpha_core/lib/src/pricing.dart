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
    this.lines = 0,
  });

  final int subtotal;
  final int deliveryFee;
  final int cylinders;

  /// Different items (product × refill/new) in the order.
  final int lines;

  /// The most different items one order can hold (also enforced by the
  /// security rules).
  static const maxLines = 6;

  int get total => subtotal + deliveryFee;
  bool get freeDelivery => deliveryFee == 0;

  static PriceBreakdown of(
    List<OrderItem> items,
    AppSettings s, {
    String area = '',
  }) {
    final subtotal = items.fold(0, (sum, i) => sum + i.lineTotal);
    final cylinders = items.fold(0, (n, i) => n + i.quantity);
    final free =
        subtotal == 0 ||
        (s.freeDeliveryFrom > 0 && subtotal >= s.freeDeliveryFrom);
    return PriceBreakdown(
      subtotal: subtotal,
      deliveryFee: free ? 0 : s.feeForArea(area),
      cylinders: cylinders,
      lines: items.length,
    );
  }

  /// Why the order cannot be placed yet, or null if it can.
  String? problem(AppSettings s, {OrderingStatus? status}) {
    if (status != null && !status.canOrder) return status.message;
    if (!s.acceptingOrders) {
      return s.closedMessage.isNotEmpty
          ? s.closedMessage
          : 'We are not taking online orders right now. Please call us.';
    }
    if (cylinders == 0) return 'Your cart is empty.';
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
