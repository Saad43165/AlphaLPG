import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../state/cart.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/live.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.select<AppState, String?>((s) => s.uid);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My orders'),
        actions: const [CartButton()],
      ),
      body: uid == null
          ? EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Sign in to see your orders',
              action: FilledButton(
                onPressed: () => context.push('/login?from=/orders'),
                child: const Text('Sign in'),
              ),
            )
          : Live<List<LpgOrder>>(
              cacheKey: uid,
              stream: () =>
                  context.read<Backend>().orders.watchCustomerOrders(uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return EmptyState(
                    icon: Icons.cloud_off,
                    title: 'Could not load orders',
                    message: '${snap.error}',
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final orders = snap.data!;
                if (orders.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No orders yet',
                    message: 'Your LPG orders will appear here.',
                    action: FilledButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Order now'),
                    ),
                  );
                }
                return Constrained(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => OrderTile(orders[i]),
                  ),
                );
              },
            ),
    );
  }
}

class OrderTile extends StatelessWidget {
  const OrderTile(this.order, {super.key});
  final LpgOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/orders/${o.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      o.displayNumber,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  StatusPill(o.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                o.items.map((i) => '${i.quantity}× ${i.name}').join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      o.createdAt != null
                          ? formatDateTime(o.createdAt!)
                          : 'Just now',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    formatRupees(o.total),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              if (!o.status.isActive) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      context.read<Cart>().reorder(o);
                      context.push('/cart');
                    },
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text('Order again'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
