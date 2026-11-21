import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';

/// Chat with the customer (and the shop) about one job.
class JobChatScreen extends StatefulWidget {
  const JobChatScreen({super.key, required this.order});
  final LpgOrder order;

  @override
  State<JobChatScreen> createState() => _JobChatScreenState();
}

class _JobChatScreenState extends State<JobChatScreen> {
  late final ChatInbox _chat;

  @override
  void initState() {
    super.initState();
    _chat = context.read<RiderSession>().chat..pin(widget.order.id);
  }

  @override
  void dispose() {
    _chat.unpin(widget.order.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<RiderSession>();
    final order = widget.order;
    return ListenableBuilder(
      listenable: _chat,
      builder: (context, _) => ChatPage(
        title: order.customerName,
        subtitle: 'Order ${order.displayNumber}',
        messages: [
          for (final m in _chat.messages(order.id))
            ChatMsg(
              text: m.text,
              name: m.role == MessageRole.admin ? 'Alpha LPG' : m.name,
              mine: m.role == MessageRole.rider,
              at: m.createdAt,
              seen:
                  m.role == MessageRole.rider &&
                  m.createdAt != null &&
                  _chat.seenByOthers(order.id, m.createdAt!),
            ),
        ],
        quickReplies: const [
          'On my way',
          'I am outside',
          'Please come to the gate',
          'Please call me',
          'Running 10 minutes late',
        ],
        loadError: _chat.error(order.id) == null
            ? null
            : ChatInbox.explain(_chat.error(order.id)!),
        onRetry: () => _chat.retry(order.id),
        onOpened: () => _chat.markRead(order.id),
        onSend: (text) => s.backend.orders.sendMessage(
          order.id,
          uid: s.uid ?? '',
          role: MessageRole.rider,
          name: s.profile?.name ?? 'Rider',
          text: text,
        ),
      ),
    );
  }
}
