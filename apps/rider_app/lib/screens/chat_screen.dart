import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';

/// Chat with the customer (and the shop) about one job.
class JobChatScreen extends StatelessWidget {
  const JobChatScreen({super.key, required this.order});
  final LpgOrder order;

  @override
  Widget build(BuildContext context) {
    final s = context.read<RiderSession>();
    final repo = s.backend.orders;
    return ChatPage(
      title: order.customerName,
      subtitle: 'Order ${order.displayNumber}',
      messages: repo
          .watchMessages(order.id)
          .map(
            (list) => [
              for (final m in list)
                ChatMsg(
                  text: m.text,
                  name: m.role == MessageRole.customer
                      ? m.name
                      : (m.role == MessageRole.admin ? 'Alpha LPG' : m.name),
                  mine: m.role == MessageRole.rider,
                  at: m.createdAt,
                ),
            ],
          ),
      quickReplies: const [
        'On my way',
        'I am outside',
        'Please come to the gate',
        'Please call me',
        'Running 10 minutes late',
      ],
      onSend: (text) => repo.sendMessage(
        order.id,
        uid: s.uid ?? '',
        role: MessageRole.rider,
        name: s.profile?.name ?? 'Rider',
        text: text,
      ),
    );
  }
}
