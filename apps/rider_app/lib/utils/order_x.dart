import 'package:alpha_core/alpha_core.dart';

extension RiderOrderX on LpgOrder {
  /// Cash the rider must collect at the door (cash-on-delivery, not yet paid).
  int get amountDue =>
      paymentMethod == PaymentMethod.cashOnDelivery &&
          paymentStatus != PaymentStatus.paid
      ? total
      : 0;

  /// A wallet / bank order the shop has not confirmed as paid yet. The rider
  /// cannot finish it: Alpha LPG confirms online payments.
  bool get awaitingOnlinePayment =>
      paymentMethod.isPrepaid && paymentStatus != PaymentStatus.paid;

  /// "2× 11.8kg, 1× 6kg"
  String get itemsLine => items
      .map(
        (i) => i.isAccessory
            ? '${i.quantity}× ${i.name}'
            : '${i.quantity}× ${i.sizeKg == i.sizeKg.roundToDouble() ? i.sizeKg.toInt() : i.sizeKg}kg',
      )
      .join(', ');

  /// Neighbourhood for quick scanning in lists.
  String get areaLine =>
      address.area.isNotEmpty ? address.area : address.oneLine;
}
