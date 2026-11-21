import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';

/// Chat about one order, from the shop: the customer and the rider both see it.
class OrderChatScreen extends StatelessWidget {
  const OrderChatScreen({super.key, required this.order});
  final LpgOrder order;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AdminSession>();
    final repo = s.backend.orders;
    return ChatPage(
      title: order.customerName,
      subtitle: order.riderName != null
          ? 'Order ${order.displayNumber} · rider ${order.riderName}'
          : 'Order ${order.displayNumber}',
      messages: repo
          .watchMessages(order.id)
          .map(
            (list) => [
              for (final m in list)
                ChatMsg(
                  text: m.text,
                  name: switch (m.role) {
                    MessageRole.customer => m.name,
                    MessageRole.rider => '${m.name} (rider)',
                    MessageRole.admin => 'Alpha LPG',
                  },
                  mine: m.role == MessageRole.admin,
                  at: m.createdAt,
                ),
            ],
          ),
      quickReplies: const [
        'Your order is confirmed',
        'Your rider is on the way',
        'Please keep your empty cylinders ready',
        'We will call you shortly',
        'Thank you for ordering from Alpha LPG',
      ],
      onSend: (text) => repo.sendMessage(
        order.id,
        uid: s.uid ?? '',
        role: MessageRole.admin,
        name: 'Alpha LPG',
        text: text,
      ),
    );
  }
}
