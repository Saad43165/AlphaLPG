import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Text;

import '../../utils/reorder.dart';

import '../../l10n/lang.dart';

import '../../l10n/text.dart';

import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../theme/brand.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';
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
                  return const OrderListSkeleton();
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
                return Constrained(child: _OrdersList(orders: orders));
              },
            ),
    );
  }
}

enum _Show { all, active, delivered, cancelled }

class _OrdersList extends StatefulWidget {
  const _OrdersList({required this.orders});
  final List<LpgOrder> orders;

  @override
  State<_OrdersList> createState() => _OrdersListState();
}

class _OrdersListState extends State<_OrdersList> {
  _Show _show = _Show.all;

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final orders = widget.orders;
    final pal = context.pal;
    final active = [
      for (final o in orders)
        if (o.status.isActive) o,
    ];
    final delivered = [
      for (final o in orders)
        if (o.status == OrderStatus.delivered) o,
    ];
    final cancelled = [
      for (final o in orders)
        if (o.status == OrderStatus.cancelled) o,
    ];
    final spent = delivered.fold(0, (n, o) => n + o.total);

    final showActive = _show == _Show.all || _show == _Show.active;
    final past = switch (_show) {
      _Show.all => [
        for (final o in orders)
          if (!o.status.isActive) o,
      ],
      _Show.delivered => delivered,
      _Show.cancelled => cancelled,
      _Show.active => const <LpgOrder>[],
    };

    // Past orders grouped by month, newest first.
    final children = <Widget>[];
    if (showActive && active.isNotEmpty) {
      children.add(const _SectionLabel('In progress'));
      for (final o in active) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ActiveOrderCard(o),
          ),
        );
      }
    }
    String? lastMonth;
    for (final o in past) {
      final t = o.createdAt ?? DateTime.now();
      final label = '${_months[t.month - 1]} ${t.year}';
      if (label != lastMonth) {
        lastMonth = label;
        children.add(_SectionLabel(label));
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OrderTile(o),
        ),
      );
    }
    if (children.isEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.only(top: 60),
          child: EmptyState(
            icon: Icons.inbox_rounded,
            title: 'Nothing here',
            message: 'No orders match this filter.',
          ),
        ),
      );
    }

    Widget chip(_Show v, String label, int n) => ChoiceChip(
      label: Text(n > 0 && v != _Show.all ? '$label · $n' : label),
      selected: _show == v,
      onSelected: (_) => setState(() => _show = v),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              chip(_Show.all, 'All', orders.length),
              const SizedBox(width: 8),
              chip(_Show.active, 'In progress', active.length),
              const SizedBox(width: 8),
              chip(_Show.delivered, 'Delivered', delivered.length),
              const SizedBox(width: 8),
              chip(_Show.cancelled, 'Cancelled', cancelled.length),
            ],
          ),
        ),
        if (delivered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
            child: Text(
              '${delivered.length} delivered · ${formatRupees(spent)} spent in total',
              style: TextStyle(color: pal.muted, fontSize: 13),
            ),
          ),
        ...children,
      ],
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
                if (o.paymentMethod.isPrepaid &&
                    o.paymentStatus != PaymentStatus.paid) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                    decoration: BoxDecoration(
                      color: Brand.flame.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 18,
                          color: Brand.flame,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            o.paymentIssue.isNotEmpty
                                ? 'Payment problem: tap to fix'
                                : o.receiptAt != null
                                ? 'Payment sent: being checked'
                                : o.paymentRequest != null
                                ? 'Payment details are ready'
                                : 'Waiting for payment details',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Flexible(
                          child: TextButton(
                            onPressed: () =>
                                context.push('/orders/${o.id}/payment'),
                            child: Text(
                              o.paymentRequest != null && o.receiptAt == null
                                  ? 'Pay now'
                                  : 'Open',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
    final color = StatusPill.colorOf(o.status);
    final needsRating = delivered && o.rating == null;
    return Opacity(
      opacity: delivered ? 1 : 0.78,
      child: Container(
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
                  // Number, date and status.
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: color.withValues(alpha: 0.14),
                        child: Icon(
                          delivered ? Icons.check_rounded : Icons.close_rounded,
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.displayNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              o.createdAt != null
                                  ? formatDateTime(o.createdAt!)
                                  : 'Just now',
                              style: TextStyle(
                                color: pal.muted,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(o.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // What was in it.
                  for (final i in o.items.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          Text(
                            '${i.quantity}×',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${i.name} (${tr(i.typeLabel.toLowerCase())})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (o.items.length > 3)
                    Text(
                      '+ ${o.items.length - 3} more',
                      style: TextStyle(color: pal.muted, fontSize: 12.5),
                    ),
                  if (!delivered && o.cancelReason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Reason: ${o.cancelReason}',
                      style: TextStyle(color: pal.muted, fontSize: 12.5),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Money and rating.
                  Row(
                    children: [
                      Text(
                        formatRupees(o.total),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const Spacer(),
                      if (delivered && o.rating != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var n = 1; n <= 5; n++)
                              Icon(
                                n <= o.rating!
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 17,
                                color: const Color(0xFFF5A623),
                              ),
                          ],
                        ),
                    ],
                  ),
                  if (delivered) ...[
                    const SizedBox(height: 2),
                    Text(
                      o.paymentStatus == PaymentStatus.paid
                          ? 'Paid · ${o.paymentMethod.label}'
                          : o.paymentMethod.label,
                      style: TextStyle(color: pal.muted, fontSize: 12.5),
                    ),
                  ],
                  if (needsRating) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5A623).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star_border_rounded,
                            color: Color(0xFFF5A623),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'How was your delivery? Tap to rate.',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Two equal actions.
                  Row(
                    children: [
                      if (delivered) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 44),
                            ),
                            onPressed: () => context.push('/invoice', extra: o),
                            icon: const Icon(
                              Icons.receipt_long_rounded,
                              size: 18,
                            ),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Invoice', maxLines: 1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                          ),
                          onPressed: () {
                            reorderNow(context, o);
                          },
                          icon: const Icon(Icons.replay_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Order again', maxLines: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
