import 'package:alpha_core/alpha_core.dart';

extension AdminOrderX on LpgOrder {
  /// Cash the rider must collect at the door (cash-on-delivery, not yet paid).
  int get amountDue =>
      paymentMethod == PaymentMethod.cashOnDelivery &&
          paymentStatus != PaymentStatus.paid
      ? total
      : 0;

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

String rs(int v) {
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return 'Rs ${v < 0 ? '-' : ''}$b';
}

/// Where an online payment stands, from the shop's point of view.
enum PayStage {
  /// The customer chose an online method; the shop has not sent the account.
  sendDetails('Send details'),

  /// Details sent; the customer has not paid / sent a receipt yet.
  waiting('Waiting for customer'),

  /// A receipt came in: check it and mark paid.
  receipt('Receipt: check it'),

  /// The shop flagged a problem; waiting for a new receipt.
  issue('Problem sent');

  const PayStage(this.label);
  final String label;
}

extension AdminOrderMoneyX on LpgOrder {
  /// Null for cash, paid or cancelled orders.
  PayStage? get payStage {
    if (!awaitingPaymentCheck) return null;
    if (paymentIssue.isNotEmpty) return PayStage.issue;
    if (receiptAt != null) return PayStage.receipt;
    if (paymentRequest != null) return PayStage.waiting;
    return PayStage.sendDetails;
  }

  /// A wallet / bank order whose money has not been confirmed yet.
  bool get awaitingPaymentCheck =>
      paymentMethod.isPrepaid &&
      paymentStatus == PaymentStatus.pending &&
      status != OrderStatus.cancelled;
}
