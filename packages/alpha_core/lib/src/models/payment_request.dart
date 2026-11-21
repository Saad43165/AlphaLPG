import '../dates.dart';
import 'order_status.dart';

/// Payment instructions the shop sends straight to the customer's order
/// screen: which method, which account, how much.
class PaymentRequest {
  const PaymentRequest({
    required this.method,
    required this.account,
    this.accountTitle = '',
    this.note = '',
    required this.amount,
    this.sentAt,
  });

  final PaymentMethod method;

  /// JazzCash / Easypaisa number, or bank name + IBAN / Raast ID.
  final String account;

  /// Name on the account.
  final String accountTitle;

  /// A line from the shop ("Please send the receipt after paying").
  final String note;
  final int amount;
  final DateTime? sentAt;

  factory PaymentRequest.fromMap(Map<String, dynamic> m) => PaymentRequest(
    method: PaymentMethod.parse(m['method'] as String?),
    account: m['account'] as String? ?? '',
    accountTitle: m['accountTitle'] as String? ?? '',
    note: m['note'] as String? ?? '',
    amount: (m['amount'] as num?)?.round() ?? 0,
    sentAt: readDate(m['sentAt']),
  );

  /// [sentAt] is added by the repository (server time).
  Map<String, dynamic> toMap() => {
    'method': method.name,
    'account': account,
    'accountTitle': accountTitle,
    'note': note,
    'amount': amount,
  };
}

/// A photo of a payment receipt, uploaded by the customer
/// (`orders/{id}/receipts/{id}`). Stored as a small base64 image, which works
/// on Firebase's free plan.
class PaymentReceipt {
  const PaymentReceipt({
    this.id = '',
    required this.data,
    this.note = '',
    this.createdAt,
  });
  final String id;
  final String data;
  final String note;
  final DateTime? createdAt;

  factory PaymentReceipt.fromMap(String id, Map<String, dynamic> m) =>
      PaymentReceipt(
        id: id,
        data: m['data'] as String? ?? '',
        note: m['note'] as String? ?? '',
        createdAt: readDate(m['createdAt']),
      );
}
