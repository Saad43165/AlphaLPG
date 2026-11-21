import 'package:alpha_core/alpha_core.dart';

/// "tx-123 456" and "TX123456" are the same transaction.
String normalizeRef(String s) =>
    s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

class PayWarning {
  const PayWarning(this.text, {this.severe = false});
  final String text;

  /// Severe ones ask the owner to confirm before marking the order paid.
  final bool severe;
}

/// Things worth a second look before marking an online order paid.
List<PayWarning> paymentWarnings(LpgOrder o, List<LpgOrder> all) {
  if (!o.paymentMethod.isPrepaid || o.paymentStatus == PaymentStatus.paid) {
    return const [];
  }
  final out = <PayWarning>[];
  final ref = normalizeRef(o.paymentReference);

  if (o.receiptAt != null && ref.isEmpty) {
    out.add(const PayWarning('No transaction ID was given.', severe: true));
  }
  if (ref.isNotEmpty) {
    for (final x in all) {
      if (x.id != o.id && normalizeRef(x.paymentReference) == ref) {
        out.add(
          PayWarning(
            'The same transaction ID is on order ${x.displayNumber} '
            '(${x.customerName}). One payment cannot pay two orders.',
            severe: true,
          ),
        );
      }
    }
  }
  final sent = o.paidAmount;
  if (sent != null && sent != o.total) {
    out.add(
      PayWarning(
        sent < o.total
            ? 'Customer says they sent Rs $sent, but the order is Rs ${o.total}. '
                  'Rs ${o.total - sent} is missing.'
            : 'Customer says they sent Rs $sent, more than the order total of Rs ${o.total}.',
        severe: sent < o.total,
      ),
    );
  }
  final at = o.receiptAt;
  final req = o.paymentRequest?.sentAt;
  if (at != null) {
    if (o.paymentRequest == null) {
      out.add(
        const PayWarning(
          'The receipt came before you sent payment details. '
          'Check the money reached the right account.',
        ),
      );
    } else if (req != null && at.difference(req) > const Duration(hours: 24)) {
      out.add(
        const PayWarning(
          'The receipt came more than a day after you sent the details.',
        ),
      );
    }
  }
  final earlier = all.any(
    (x) =>
        x.id != o.id &&
        x.customerId == o.customerId &&
        x.paymentIssue.isNotEmpty,
  );
  if (earlier) {
    out.add(
      const PayWarning(
        'This customer had a payment problem on an earlier order.',
      ),
    );
  }
  return out;
}
