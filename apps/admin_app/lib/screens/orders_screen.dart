import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/order_x.dart';
import '../widgets/common.dart';
import 'order_detail_screen.dart';

enum _Filter { fresh, active, verify, done, cancelled }

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  _Filter _f = _Filter.fresh;

  List<LpgOrder> _list(AdminSession s) => switch (_f) {
    _Filter.fresh => s.ordersIn([OrderStatus.placed]),
    _Filter.active => s.ordersIn([
      OrderStatus.confirmed,
      OrderStatus.assigned,
      OrderStatus.outForDelivery,
    ]),
    _Filter.verify => [
      for (final o in s.orders)
        if (o.awaitingPaymentCheck) o,
    ],
    _Filter.done => s.ordersIn([OrderStatus.delivered]),
    _Filter.cancelled => s.ordersIn([OrderStatus.cancelled]),
  };

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final list = _list(s);
    final counts = {
      _Filter.fresh: s.newCount,
      _Filter.active: s.activeCount,
      _Filter.verify: s.toVerifyCount,
    };
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            BrandLogo(height: 30),
            SizedBox(width: 10),
            Text('Orders'),
          ],
        ),
      ),
      body: Constrained(
        child: Column(
          children: [
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  _Stat(
                    'New orders',
                    '${s.newCount}',
                    Icons.notifications_active_rounded,
                    const Color(0xFFB58900),
                  ),
                  _Stat(
                    'On the road',
                    '${s.ordersIn([OrderStatus.outForDelivery]).length}',
                    Icons.two_wheeler,
                    const Color(0xFF6A3FC1),
                  ),
                  _Stat(
                    'Sales today',
                    rs(s.salesToday),
                    Icons.payments_rounded,
                    Brand.success,
                  ),
                  _Stat(
                    'Delivered today',
                    '${s.deliveredTodayCount}',
                    Icons.check_circle_rounded,
                    Brand.blueDark,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final (f, label) in const [
                    (_Filter.fresh, 'New'),
                    (_Filter.active, 'In progress'),
                    (_Filter.verify, 'Verify payment'),
                    (_Filter.done, 'Delivered'),
                    (_Filter.cancelled, 'Cancelled'),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        selected: _f == f,
                        onSelected: (_) => setState(() => _f = f),
                        label: Text(
                          (counts[f] ?? 0) > 0
                              ? '$label · ${counts[f]}'
                              : label,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (s.error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  s.error!,
                  style: const TextStyle(color: Brand.danger),
                ),
              ),
            Expanded(
              child: !s.ordersLoaded
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                  ? EmptyState(
                      icon: Icons.inbox_rounded,
                      title: switch (_f) {
                        _Filter.fresh => 'No new orders',
                        _Filter.active => 'Nothing in progress',
                        _Filter.verify => 'No payments to check',
                        _Filter.done => 'No delivered orders yet',
                        _Filter.cancelled => 'No cancelled orders',
                      },
                      message: 'New orders appear here the moment a customer places them.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => OrderTile(order: list[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon, this.color);
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    margin: const EdgeInsets.only(right: 10),
    padding: const EdgeInsets.all(12),
    decoration: panel(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.pal.muted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
          ),
        ),
      ],
    ),
  );
}

class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order});
  final LpgOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final when = o.createdAt == null
        ? ''
        : DateFormat('d MMM, h:mm a').format(o.createdAt!);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: panel(context),
        child: InkWell(
          borderRadius: BorderRadius.circular(Brand.radius),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OrderDetailScreen(orderId: o.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      o.displayNumber,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    StatusChip(o.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  o.customerType == CustomerSegment.business &&
                          o.businessName.isNotEmpty
                      ? '${o.customerName} · ${o.businessName}'
                      : o.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${o.itemsLine}  ·  ${o.areaLine}',
                  style: TextStyle(color: context.pal.muted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      rs(o.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Pill(
                      o.paymentStatus == PaymentStatus.paid
                          ? Icons.check_circle_rounded
                          : o.paymentMethod.isPrepaid
                          ? Icons.hourglass_top_rounded
                          : Icons.payments_outlined,
                      o.paymentStatus == PaymentStatus.paid
                          ? 'Paid'
                          : o.paymentMethod == PaymentMethod.cashOnDelivery
                          ? 'Cash'
                          : 'Verify',
                      color: o.paymentStatus == PaymentStatus.paid
                          ? Brand.success
                          : const Color(0xFF8A6D00),
                    ),
                    const Spacer(),
                    Text(
                      when,
                      style: TextStyle(color: context.pal.muted, fontSize: 12),
                    ),
                  ],
                ),
                if (o.riderName != null && o.status.isActive) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.two_wheeler,
                        size: 16,
                        color: Brand.blueDark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        o.riderName!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
