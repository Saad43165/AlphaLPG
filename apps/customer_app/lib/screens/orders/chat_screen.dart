import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';

/// Chat about one order with the rider and Alpha LPG: bubbles, quick
/// replies, ticks when the other side has seen it.
class OrderChatScreen extends StatefulWidget {
  const OrderChatScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  late final ChatInbox _chat;

  @override
  void initState() {
    super.initState();
    _chat = context.read<AppState>().chat..pin(widget.orderId);
  }

  @override
  void dispose() {
    _chat.unpin(widget.orderId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final state = context.read<AppState>();
    final uid = state.uid ?? '';
    return StreamBuilder<LpgOrder?>(
      stream: backend.orders.watchOrder(widget.orderId),
      builder: (context, snap) {
        final o = snap.data;
        return ListenableBuilder(
          listenable: _chat,
          builder: (context, _) => ChatPage(
            title: o?.riderName != null
                ? '${o!.riderName} · rider'
                : 'Alpha LPG',
            subtitle: 'Order ${o?.displayNumber ?? ''}'.trim(),
            messages: [
              for (final m in _chat.messages(widget.orderId))
                ChatMsg(
                  text: m.text,
                  name: m.role == MessageRole.rider
                      ? '${m.name} (rider)'
                      : (m.name.isEmpty ? m.role.fallbackName : m.name),
                  mine: m.role == MessageRole.customer,
                  at: m.createdAt,
                  seen:
                      m.role == MessageRole.customer &&
                      m.createdAt != null &&
                      _chat.seenByOthers(widget.orderId, m.createdAt!),
                ),
            ],
            quickReplies: const [
              'I am at home',
              'Please call me',
              'Gate is open',
              'Please wait 5 minutes',
              'Where are you?',
            ],
            loadError: _chat.error(widget.orderId) == null
                ? null
                : ChatInbox.explain(_chat.error(widget.orderId)!),
            onRetry: () => _chat.retry(widget.orderId),
            onOpened: () => _chat.markRead(widget.orderId),
            onSend: (text) => backend.orders.sendMessage(
              widget.orderId,
              uid: uid,
              role: MessageRole.customer,
              name: state.profile?.name ?? 'Customer',
              text: text,
            ),
          ),
        );
      },
    );
  }
}
