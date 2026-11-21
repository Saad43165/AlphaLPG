import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';

/// Chat about one order with the rider and Alpha LPG.
class OrderChatScreen extends StatelessWidget {
  const OrderChatScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final state = context.read<AppState>();
    final uid = state.uid ?? '';
    return StreamBuilder<LpgOrder?>(
      stream: backend.orders.watchOrder(orderId),
      builder: (context, snap) {
        final o = snap.data;
        return ChatPage(
          title: 'Order ${o?.displayNumber ?? ''}'.trim(),
          subtitle: o?.riderName != null
              ? 'Rider ${o!.riderName} and Alpha LPG'
              : 'Alpha LPG',
          messages: backend.orders
              .watchMessages(orderId)
              .map(
                (list) => [
                  for (final m in list)
                    ChatMsg(
                      text: m.text,
                      name: m.role == MessageRole.rider
                          ? '${m.name} (rider)'
                          : (m.name.isEmpty ? m.role.fallbackName : m.name),
                      mine: m.role == MessageRole.customer,
                      at: m.createdAt,
                    ),
                ],
              ),
          quickReplies: const [
            'I am at home',
            'Please call me',
            'Gate is open',
            'Please wait 5 minutes',
            'Where are you?',
          ],
          onOpened: () => state.markChatRead(orderId),
          onSend: (text) => backend.orders.sendMessage(
            orderId,
            uid: uid,
            role: MessageRole.customer,
            name: state.profile?.name ?? 'Customer',
            text: text,
          ),
        );
      },
    );
  }
}
