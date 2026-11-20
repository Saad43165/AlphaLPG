import 'models/app_settings.dart';
import 'models/order.dart';

/// The single source of truth for order totals on the client.
/// `firebase/functions/src/pricing.ts` mirrors these rules on the server and
/// re-prices every new order, so a tampered client cannot change the total.
class PriceBreakdown {
  const PriceBreakdown({
    required this.subtotal,
    required this.deliveryFee,
    required this.cylinders,
  });

  final int subtotal;
  final int deliveryFee;
  final int cylinders;

  int get total => subtotal + deliveryFee;
  bool get freeDelivery => deliveryFee == 0;

  static PriceBreakdown of(List<OrderItem> items, AppSettings s) {
    final subtotal = items.fold(0, (sum, i) => sum + i.lineTotal);
    final cylinders = items.fold(0, (n, i) => n + i.quantity);
    final free =
        subtotal == 0 ||
        (s.freeDeliveryFrom > 0 && subtotal >= s.freeDeliveryFrom);
    return PriceBreakdown(
      subtotal: subtotal,
      deliveryFee: free ? 0 : s.deliveryFee,
      cylinders: cylinders,
    );
  }

  /// Why the order cannot be placed yet, or null if it can.
  String? problem(AppSettings s) {
    if (!s.acceptingOrders) {
      return s.closedMessage.isNotEmpty
          ? s.closedMessage
          : 'We are not taking online orders right now. Please call us.';
    }
    if (cylinders == 0) return 'Your cart is empty.';
    if (cylinders > s.maxCylindersPerOrder) {
      return 'For more than ${s.maxCylindersPerOrder} cylinders please request a bulk quote.';
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
