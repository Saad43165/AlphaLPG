import '../dates.dart';

/// Who wrote a message in an order's chat.
enum MessageRole {
  customer,
  rider,
  admin;

  static MessageRole parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => admin);

  /// Small label shown on each bubble so nobody is mistaken for someone else.
  String get badge => switch (this) {
    customer => 'CUSTOMER',
    rider => 'RIDER',
    admin => 'SHOP',
  };

  /// "Alpha LPG" for the shop, otherwise the sender's own name.
  String get fallbackName => switch (this) {
    customer => 'Customer',
    rider => 'Rider',
    admin => 'Alpha LPG',
  };
}

/// One chat message on an order (`orders/{id}/messages/{messageId}`). The
/// customer, the assigned rider and the shop can all write; each of them is
/// told about new messages from the others.
class OrderMessage {
  const OrderMessage({
    this.id = '',
    required this.role,
    required this.name,
    required this.text,
    this.createdAt,
  });

  final String id;
  final MessageRole role;
  final String name;
  final String text;
  final DateTime? createdAt;

  factory OrderMessage.fromMap(String id, Map<String, dynamic> m) =>
      OrderMessage(
        id: id,
        role: MessageRole.parse(m['role'] as String?),
        name: m['name'] as String? ?? '',
        text: m['text'] as String? ?? '',
        createdAt: readDate(m['createdAt']),
      );
}
