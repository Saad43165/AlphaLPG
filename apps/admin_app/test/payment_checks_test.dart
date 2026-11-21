import 'package:alpha_admin/utils/order_x.dart';
import 'package:alpha_admin/utils/payment_checks.dart';
import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_test/flutter_test.dart';

LpgOrder _o({
  required String id,
  String customer = 'c1',
  String ref = '',
  int total = 3000,
  int? paid,
  PaymentMethod method = PaymentMethod.jazzCash,
  PaymentStatus status = PaymentStatus.pending,
  DateTime? receiptAt,
  PaymentRequest? request,
  String issue = '',
}) => LpgOrder(
  id: id,
  orderNumber: 'AL-$id',
  customerId: customer,
  customerName: 'Ali',
  customerPhone: '+923001234567',
  items: const [],
  subtotal: total,
  deliveryFee: 0,
  total: total,
  address: const Address(label: 'Home', line1: '1', area: 'DHA'),
  paymentMethod: method,
  paymentStatus: status,
  paymentReference: ref,
  paidAmount: paid,
  receiptAt: receiptAt,
  paymentRequest: request,
  paymentIssue: issue,
);

void main() {
  test('a clean receipt has no warnings', () {
    final now = DateTime.now();
    final o = _o(
      id: '1',
      ref: 'TX123456',
      paid: 3000,
      receiptAt: now,
      request: PaymentRequest(
        method: PaymentMethod.jazzCash,
        account: '0300',
        amount: 3000,
        sentAt: now.subtract(const Duration(minutes: 20)),
      ),
    );
    expect(paymentWarnings(o, [o]), isEmpty);
  });

  test(
    'same transaction ID on two orders is flagged, ignoring case and spaces',
    () {
      final a = _o(
        id: '1',
        ref: 'tx-123 456',
        paid: 3000,
        receiptAt: DateTime.now(),
      );
      final b = _o(
        id: '2',
        customer: 'c2',
        ref: 'TX123456',
        paid: 3000,
        receiptAt: DateTime.now(),
      );
      final w = paymentWarnings(b, [a, b]);
      expect(
        w.any((x) => x.severe && x.text.contains('same transaction ID')),
        isTrue,
      );
    },
  );

  test('missing id, short amount and early receipt are flagged', () {
    final o = _o(id: '1', total: 3000, paid: 2000, receiptAt: DateTime.now());
    final texts = paymentWarnings(o, [o]).map((w) => w.text).join('|');
    expect(texts, contains('No transaction ID'));
    expect(texts, contains('Rs 1000 is missing'));
    expect(texts, contains('before you sent payment details'));
  });

  test('earlier problem on the same customer is flagged; cash and paid orders are not', () {
    final bad = _o(id: '1', issue: 'fake receipt');
    final o = _o(
      id: '2',
      ref: 'TX999999',
      paid: 3000,
      receiptAt: DateTime.now(),
    );
    expect(
      paymentWarnings(o, [bad, o]).any((w) => w.text.contains('earlier order')),
      isTrue,
    );
    expect(
      paymentWarnings(_o(id: '3', method: PaymentMethod.cashOnDelivery), []),
      isEmpty,
    );
    expect(
      paymentWarnings(_o(id: '4', status: PaymentStatus.paid), []),
      isEmpty,
    );
  });

  test('payment stage tells the shop what to do next', () {
    expect(_o(id: '1').payStage, PayStage.sendDetails);
    expect(
      _o(
        id: '2',
        request: const PaymentRequest(
          method: PaymentMethod.jazzCash,
          account: 'x',
          amount: 1,
        ),
      ).payStage,
      PayStage.waiting,
    );
    expect(_o(id: '3', receiptAt: DateTime.now()).payStage, PayStage.receipt);
    expect(_o(id: '4', issue: 'blurry').payStage, PayStage.issue);
    expect(_o(id: '5', method: PaymentMethod.cashOnDelivery).payStage, isNull);
  });
}
