import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../state/cart.dart';
import '../../theme/brand.dart';
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
                  return const EmptyState(
                    icon: Icons.cloud_off,
                    title: 'Could not load your orders',
                    message: 'Check your internet connection and try again.',
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
                final active = [
                  for (final o in orders)
                    if (o.status.isActive) o,
                ];
                final past = [
                  for (final o in orders)
                    if (!o.status.isActive) o,
                ];
                return Constrained(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    children: [
                      _Summary(orders: orders, active: active.length),
                      if (active.isNotEmpty) ...[
                        const _SectionLabel('In progress'),
                        for (final o in active)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ActiveOrderCard(o),
                          ),
                      ],
                      if (past.isNotEmpty) ...[
                        const _SectionLabel('Past orders'),
                        for (final o in past)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: OrderTile(o),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

/// Orders at a glance: how many, how many cylinders delivered, total spent.
class _Summary extends StatelessWidget {
  const _Summary({required this.orders, required this.active});
  final List<LpgOrder> orders;
  final int active;

  @override
  Widget build(BuildContext context) {
    final delivered = orders.where((o) => o.status == OrderStatus.delivered);
    final cylinders = delivered.fold(0, (n, o) => n + o.cylinderCount);
    final spent = delivered.fold(0, (n, o) => n + o.total);
    Widget cell(String value, String label) => Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
          ),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        gradient: Brand.headerGradient,
        borderRadius: BorderRadius.circular(Brand.radius),
      ),
      child: Row(
        children: [
          cell('${orders.length}', 'Orders'),
          cell('$cylinders', 'Cylinders'),
          cell(formatRupees(spent), 'Spent'),
        ],
      ),
    );
  }
}

/// An order that is still moving: progress bar, what happens next, and a
/// big Track button.
class ActiveOrderCard extends StatelessWidget {
  const ActiveOrderCard(this.order, {super.key});
  final LpgOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final pal = context.pal;
    final color = StatusPill.colorOf(o.status);
    final step = OrderStatus.journey.indexOf(o.status);
    return Container(
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(Brand.radius),
        boxShadow: pal.shadow,
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Brand.radius),
          onTap: () => context.push('/orders/${o.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        o.displayNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    StatusPill(o.status),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < OrderStatus.journey.length; i++) ...[
                      Expanded(
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: i <= step ? color : pal.line,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      if (i < OrderStatus.journey.length - 1)
                        const SizedBox(width: 4),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  o.status == OrderStatus.outForDelivery && o.riderName != null
                      ? '${o.riderName} is on the way'
                      : o.status.description,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  o.items.map((i) => '${i.quantity}× ${i.name}').join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: pal.muted, height: 1.35),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatRupees(o.total),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      onPressed: () => context.push('/orders/${o.id}'),
                      icon: Icon(
                        o.status == OrderStatus.outForDelivery
                            ? Icons.my_location_rounded
                            : Icons.visibility_rounded,
                        size: 18,
                      ),
                      label: Text(
                        o.status == OrderStatus.outForDelivery
                            ? 'Track rider'
                            : 'View order',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A finished (delivered or cancelled) order.
class OrderTile extends StatelessWidget {
  const OrderTile(this.order, {super.key});
  final LpgOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final pal = context.pal;
    final delivered = o.status == OrderStatus.delivered;
    return Container(
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(Brand.radius),
        boxShadow: pal.shadow,
        border: pal.isDark ? Border.all(color: pal.line) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Brand.radius),
          onTap: () => context.push('/orders/${o.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: StatusPill.colorOf(o.status)
                          .withValues(alpha: 0.14),
                      child: Icon(
                        delivered
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: StatusPill.colorOf(o.status),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.displayNumber,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            o.createdAt != null
                                ? formatDateTime(o.createdAt!)
                                : 'Just now',
                            style: TextStyle(color: pal.muted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatRupees(o.total),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StatusPill(o.status),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  o.items.map((i) => '${i.quantity}× ${i.name}').join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: pal.muted, height: 1.35),
                ),
                const SizedBox(height: 6),
                if (delivered)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: o.rating != null
                        ? Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 18,
                                color: Brand.flame,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'You rated ${o.rating}/5',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Tap to rate your delivery',
                            style: TextStyle(color: pal.muted, fontSize: 12.5),
                          ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 4,
                    children: [
                      if (delivered)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 40),
                          ),
                          onPressed: () => context.push('/invoice', extra: o),
                          icon: const Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                          ),
                          label: const Text('Invoice'),
                        ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 40),
                        ),
                        onPressed: () {
                          context.read<Cart>().reorder(o);
                          context.push('/cart');
                        },
                        icon: const Icon(Icons.replay_rounded, size: 18),
                        label: const Text('Order again'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
