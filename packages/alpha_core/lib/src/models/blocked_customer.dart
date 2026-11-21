import '../dates.dart';

/// A customer the shop has stopped from ordering (`blocked/{uid}`).
class BlockedCustomer {
  const BlockedCustomer({
    required this.uid,
    this.name = '',
    this.phone = '',
    this.reason = '',
    this.at,
  });

  final String uid;
  final String name;
  final String phone;
  final String reason;
  final DateTime? at;

  factory BlockedCustomer.fromMap(String uid, Map<String, dynamic> m) =>
      BlockedCustomer(
        uid: uid,
        name: m['name'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        reason: m['reason'] as String? ?? '',
        at: readDate(m['at']),
      );
}
