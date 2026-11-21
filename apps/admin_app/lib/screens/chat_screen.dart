import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';

/// Chat about one order, from the shop: the customer and the rider both see it.
class OrderChatScreen extends StatefulWidget {
  const OrderChatScreen({super.key, required this.order});
  final LpgOrder order;

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  late final ChatInbox _chat;

  @override
  void initState() {
    super.initState();
    _chat = context.read<AdminSession>().chat..pin(widget.order.id);
  }

  @override
  void dispose() {
    _chat.unpin(widget.order.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AdminSession>();
    final order = widget.order;
    return ListenableBuilder(
      listenable: _chat,
      builder: (context, _) => ChatPage(
        title: order.customerName,
        subtitle: order.riderName != null
            ? 'Order ${order.displayNumber} · rider ${order.riderName}'
            : 'Order ${order.displayNumber}',
        messages: [
          for (final m in _chat.messages(order.id))
            ChatMsg(
              text: m.text,
              name: switch (m.role) {
                MessageRole.customer => m.name,
                MessageRole.rider => '${m.name} (rider)',
                MessageRole.admin => 'Alpha LPG',
              },
              mine: m.role == MessageRole.admin,
              at: m.createdAt,
              seen:
                  m.role == MessageRole.admin &&
                  m.createdAt != null &&
                  _chat.seenByOthers(order.id, m.createdAt!),
            ),
        ],
        quickReplies: const [
          'Your order is confirmed',
          'Your rider is on the way',
          'Please keep your empty cylinders ready',
          'We will call you shortly',
          'Thank you for ordering from Alpha LPG',
        ],
        onOpened: () => _chat.markRead(order.id),
        onSend: (text) => s.backend.orders.sendMessage(
          order.id,
          uid: s.uid ?? '',
          role: MessageRole.admin,
          name: 'Alpha LPG',
          text: text,
        ),
      ),
    );
  }
}
