import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/launch.dart';
import '../utils/order_x.dart';
import '../utils/rider_state.dart';
import '../widgets/common.dart';
import '../widgets/schedule.dart';
import 'order_detail_screen.dart';

enum _Filter { fresh, scheduled, active, verify, done, cancelled }

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  _Filter _f = _Filter.fresh;
  String _q = '';

  /// Picking several waiting orders to give to one rider.
  bool _selecting = false;
  final _picked = <String>{};

  bool _isWaiting(LpgOrder o) =>
      o.status == OrderStatus.confirmed && o.riderId == null && !o.isUpcoming();

  Future<void> _giveToRider(AdminSession s) async {
    final orders = [
      for (final o in s.orders)
        if (_picked.contains(o.id) && _isWaiting(o)) o,
    ];
    if (orders.isEmpty) return;
    final r = await showModalBottomSheet<RiderProfile>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => RiderPicker(
        riders: s.riders,
        order: orders.first,
        allOrders: s.orders,
        extraCylinders: orders.fold<int>(0, (n, o) => n + o.cylinderCount),
        count: orders.length,
      ),
    );
    if (r == null || !mounted) return;
    var done = 0;
    String? error;
    for (final o in orders) {
      final err = await s.assign(o, r);
      if (err != null) {
        error = err;
        break;
      }
      done++;
    }
    if (!mounted) return;
    setState(() {
      _selecting = false;
      _picked.clear();
    });
    showMessage(
      context,
      error ?? 'Gave $done order${done == 1 ? '' : 's'} to ${r.name}',
      error: error != null,
    );
  }

  bool _searching = false;

  /// What the list shows: orders, with plain-text headings between groups.
  List<Object> _items(AdminSession s) {
    final out = <Object>[];
    switch (_f) {
      case _Filter.active:
        final active = s.activeOrders;
        for (final (title, test) in <(String, bool Function(LpgOrder))>[
          (
            'Waiting for a rider',
            (o) => o.status == OrderStatus.confirmed && o.riderId == null,
          ),
          (
            'Rider assigned, not left yet',
            (o) =>
                o.status == OrderStatus.assigned ||
                (o.status == OrderStatus.confirmed && o.riderId != null),
          ),
          ('On the road', (o) => o.status == OrderStatus.outForDelivery),
        ]) {
          final g = active.where(test).toList();
          if (g.isEmpty) continue;
          out.add('$title · ${g.length}');
          out.addAll(g);
        }
      case _Filter.scheduled:
        String? day;
        for (final o in s.upcomingOrders) {
          final d = _dayName(o.scheduledFor!);
          if (d != day) {
            day = d;
            out.add(d);
          }
          out.add(o);
        }
      default:
        out.addAll(_list(s));
    }
    return out;
  }

  static String _dayName(DateTime d) {
    final now = DateTime.now();
    final a = DateTime(d.year, d.month, d.day);
    final t = DateTime(now.year, now.month, now.day);
    final diff = a.difference(t).inDays;
    return diff == 0
        ? 'Today'
        : diff == 1
        ? 'Tomorrow'
        : DateFormat('EEEE d MMM').format(d);
  }

  List<LpgOrder> _list(AdminSession s) => switch (_f) {
    _Filter.fresh => s.ordersIn([OrderStatus.placed]),
    _Filter.scheduled => s.upcomingOrders,
    _Filter.active => s.activeOrders,
    _Filter.verify => [
      for (final stage in [
        PayStage.sendDetails,
        PayStage.receipt,
        PayStage.issue,
        PayStage.waiting,
      ])
        for (final o in s.orders)
          if (o.payStage == stage) o,
    ],
    _Filter.done => s.ordersIn([OrderStatus.delivered]),
    _Filter.cancelled => s.ordersIn([OrderStatus.cancelled]),
  };

  /// Search across customer, phone, order number, area and rider.
  bool _matches(LpgOrder o) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = [
      o.customerName,
      o.customerPhone,
      o.displayNumber,
      o.businessName,
      o.address.area,
      o.address.line1,
      o.riderName ?? '',
    ].join(' ').toLowerCase();
    return hay.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    // While searching, look through every order, not just the chosen tab.
    final list = _q.trim().isEmpty
        ? _items(s)
        : <Object>[
            for (final o in s.orders)
              if (_matches(o)) o,
          ];
    final counts = {
      _Filter.fresh: s.newCount,
      _Filter.scheduled: s.upcomingOrders.length,
      _Filter.active: s.activeCount,
      _Filter.verify: s.toVerifyCount,
    };
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: _searching
            ? TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(
                  hintText: 'Name, phone, order no. or area',
                  border: InputBorder.none,
                  filled: false,
                ),
              )
            : const Row(
                children: [
                  BrandLogo(height: 30),
                  SizedBox(width: 10),
                  Text('Orders'),
                ],
              ),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search orders',
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _q = '';
            }),
          ),
        ],
      ),
      bottomNavigationBar: _selecting && _picked.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => _giveToRider(s),
                  icon: const Icon(Icons.two_wheeler_rounded),
                  label: Text(
                    'Give ${_picked.length} order${_picked.length == 1 ? '' : 's'} to a rider',
                  ),
                ),
              ),
            )
          : null,
      body: Constrained(
        child: Column(
          children: [
            if (!_searching) const _ShopBar(),
            if (!_searching && s.waitingForRider.isNotEmpty)
              _PayBanner(
                icon: Icons.two_wheeler_rounded,
                text: s.waitingForRider.length == 1
                    ? '1 order has waited ${AdminSession.waitingMinutes}+ min for a rider'
                    : '${s.waitingForRider.length} orders have waited ${AdminSession.waitingMinutes}+ min for a rider',
                onTap: () => setState(() => _f = _Filter.fresh),
              ),
            if (!_searching && s.silentRiders.isNotEmpty)
              _PayBanner(
                icon: Icons.signal_wifi_off_rounded,
                text: s.silentRiders.length == 1
                    ? '${s.silentRiders.first.name} has an order but the phone has not reported for 5+ min'
                    : '${s.silentRiders.length} riders with orders have not reported for 5+ min',
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  builder: (_) => ChangeNotifierProvider.value(
                    value: s,
                    child: _RiderJobsSheet(s.silentRiders.first),
                  ),
                ),
              ),
            if (!_searching && s.unpaidAfterDetails.isNotEmpty)
              _PayBanner(
                icon: Icons.hourglass_bottom_rounded,
                text: s.unpaidAfterDetails.length == 1
                    ? '1 customer has not paid 1+ hour after getting the account details'
                    : '${s.unpaidAfterDetails.length} customers have not paid 1+ hour after getting the account details',
                onTap: () => setState(() => _f = _Filter.verify),
              ),
            if (!_searching && s.scheduledSoonCount > 0)
              _PayBanner(
                icon: Icons.event_rounded,
                text: s.scheduledSoonCount == 1
                    ? '1 scheduled order in the next 24 hours'
                    : '${s.scheduledSoonCount} scheduled orders in the next 24 hours',
                onTap: () => setState(() => _f = _Filter.scheduled),
              ),
            if (!_searching && s.needDetailsCount > 0)
              _PayBanner(
                icon: Icons.send_rounded,
                text: s.needDetailsCount == 1
                    ? '1 order needs payment details sent'
                    : '${s.needDetailsCount} orders need payment details sent',
                onTap: () => setState(() => _f = _Filter.verify),
              ),
            if (!_searching && s.receiptsToCheckCount > 0)
              _PayBanner(
                icon: Icons.receipt_long_rounded,
                text: s.receiptsToCheckCount == 1
                    ? '1 payment receipt to check'
                    : '${s.receiptsToCheckCount} payment receipts to check',
                onTap: () => setState(() => _f = _Filter.verify),
              ),
            if (!_searching)
              SizedBox(
                height:
                    92 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 4,
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
            if (!_searching && s.riders.any((r) => r.active)) _RiderStrip(s),
            if (!_searching)
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final (f, label) in const [
                      (_Filter.fresh, 'New'),
                      (_Filter.scheduled, 'Scheduled'),
                      (_Filter.active, 'In progress'),
                      (_Filter.verify, 'Online payments'),
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
                        _Filter.scheduled => 'No scheduled orders',
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
                      itemBuilder: (_, i) {
                        final item = list[i];
                        if (item is String) {
                          final waiting = item.startsWith(
                            'Waiting for a rider',
                          );
                          final many =
                              waiting &&
                              s.activeOrders.where(_isWaiting).length >= 2;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: context.pal.muted,
                                    ),
                                  ),
                                ),
                                if (many)
                                  TextButton(
                                    onPressed: () => setState(() {
                                      _selecting = !_selecting;
                                      _picked.clear();
                                    }),
                                    child: Text(
                                      _selecting ? 'Cancel' : 'Select several',
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }
                        final order = item as LpgOrder;
                        if (_selecting && _isWaiting(order)) {
                          final on = _picked.contains(order.id);
                          return InkWell(
                            borderRadius: BorderRadius.circular(Brand.radius),
                            onTap: () => setState(
                              () => on
                                  ? _picked.remove(order.id)
                                  : _picked.add(order.id),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: on,
                                  onChanged: (_) => setState(
                                    () => on
                                        ? _picked.remove(order.id)
                                        : _picked.add(order.id),
                                  ),
                                ),
                                Expanded(
                                  child: AbsorbPointer(
                                    child: OrderTile(order: order),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return OrderTile(order: order);
                      },
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
    final pal = context.pal;
    final when = o.createdAt == null
        ? ''
        : DateFormat('d MMM · h:mm a').format(o.createdAt!);
    final paid = o.paymentStatus == PaymentStatus.paid;
    final who =
        o.customerType == CustomerSegment.business && o.businessName.isNotEmpty
        ? '${o.customerName} · ${o.businessName}'
        : o.customerName;
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
                // Order number and status.
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.displayNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            when,
                            style: TextStyle(color: pal.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (context.watch<AdminSession>().chat.unread(o.id) >
                        0) ...[
                      Pill(
                        Icons.forum_rounded,
                        '${context.watch<AdminSession>().chat.unread(o.id)} new',
                        color: Brand.cylinderRed,
                      ),
                      const SizedBox(width: 8),
                    ],
                    StatusChip(o.status),
                  ],
                ),
                const SizedBox(height: 10),
                // Who, what and where.
                Text(
                  who,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.propane_tank_rounded,
                        size: 15,
                        color: pal.muted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        o.itemsLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: pal.ink, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 15, color: pal.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        o.areaLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: pal.muted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                if (o.isScheduled) ...[
                  const SizedBox(height: 10),
                  ScheduleChip(o),
                ],
                Divider(height: 22, color: pal.line),
                // Money and rider on one line; payment tags on their own
                // line below so nothing gets squeezed.
                Row(
                  children: [
                    Text(
                      rs(o.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.two_wheeler,
                                size: 17,
                                color: o.riderName == null
                                    ? pal.muted
                                    : Brand.blueDark,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                o.riderName ??
                                    (o.status.isActive ? 'No rider yet' : '—'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: o.riderName == null
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  fontSize: 13,
                                  color: o.riderName == null ? pal.muted : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Pill(
                      paid
                          ? Icons.check_circle_rounded
                          : o.paymentMethod == PaymentMethod.cashOnDelivery
                          ? Icons.payments_outlined
                          : switch (o.payStage) {
                              PayStage.sendDetails => Icons.send_rounded,
                              PayStage.receipt => Icons.receipt_long_rounded,
                              PayStage.issue => Icons.error_outline_rounded,
                              _ => Icons.hourglass_top_rounded,
                            },
                      paid
                          ? 'Paid · ${o.paymentMethod.label}'
                          : o.paymentMethod == PaymentMethod.cashOnDelivery
                          ? 'Cash on delivery'
                          : o.payStage?.label ?? 'Online',
                      color: paid
                          ? Brand.success
                          : switch (o.payStage) {
                              PayStage.sendDetails => Brand.cylinderRed,
                              PayStage.receipt => context.pal.warn,
                              _ => const Color(0xFF8A6D00),
                            },
                    ),
                    if (context.watch<AdminSession>().isNewCustomer(o))
                      const Pill(
                        Icons.phone_in_talk_rounded,
                        'New customer: call to confirm',
                        color: Brand.blueDark,
                      ),
                    if (!paid &&
                        context.watch<AdminSession>().hasPaymentWarning(o))
                      const Pill(
                        Icons.warning_amber_rounded,
                        'Check payment',
                        color: Brand.danger,
                      ),
                  ],
                ),
                if (o.status == OrderStatus.placed) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                          ),
                          onPressed: () async {
                            final s = context.read<AdminSession>();
                            final err = await s.confirm(o);
                            if (context.mounted) {
                              showMessage(
                                context,
                                err ?? 'Order confirmed',
                                error: err != null,
                              );
                            }
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Confirm'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                          ),
                          onPressed: () => Launch.call(o.customerPhone),
                          icon: const Icon(Icons.call_rounded, size: 18),
                          label: const Text('Call'),
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

/// Open / close the shop for customers from the first screen, and see how
/// many riders are on shift. Changes reach every customer immediately.
class _ShopBar extends StatelessWidget {
  const _ShopBar();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final open = s.settings.acceptingOrders;
    final live = s.liveRiders.length;
    final pal = context.pal;
    final color = open ? Brand.success : Brand.danger;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(Brand.radius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            open ? Icons.storefront_rounded : Icons.pause_circle_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  open ? 'Shop is open' : 'Shop is closed',
                  style: TextStyle(fontWeight: FontWeight.w800, color: color),
                ),
                Text(
                  open
                      ? (live == 0
                            ? 'No rider on shift'
                            : '$live rider${live == 1 ? '' : 's'} on shift')
                      : 'Customers cannot place orders',
                  style: TextStyle(color: pal.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Switch(
            value: open,
            onChanged: (v) async {
              if (!v) {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Close the shop?'),
                    content: const Text(
                      'Customers will see "Not taking orders" and cannot place new orders. Orders already placed continue.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Keep open'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Close shop'),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
              }
              final err = await s.setShopOpen(v);
              if (context.mounted) {
                showMessage(
                  context,
                  err ?? (v ? 'Shop is open' : 'Shop is closed'),
                  error: err != null,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _PayBanner extends StatelessWidget {
  const _PayBanner({
    required this.icon,
    required this.text,
    required this.onTap,
  });
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Material(
      color: context.pal.warnBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Every rider at a glance: free, on a job, or offline. Tap one to see what
/// they are carrying.
class _RiderStrip extends StatelessWidget {
  const _RiderStrip(this.s);
  final AdminSession s;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final riders =
        [
          for (final r in s.riders)
            if (r.active) r,
        ]..sort((a, b) {
          return riderStateIn(
            s,
            a,
            pal.muted,
          ).rank.compareTo(riderStateIn(s, b, pal.muted).rank);
        });
    return SizedBox(
      height: 62 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 3,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          for (final r in riders)
            Builder(
              builder: (context) {
                final st = riderStateIn(s, r, pal.muted);
                final label = st.label;
                final color = st.color;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: pal.card,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        isScrollControlled: true,
                        builder: (_) => ChangeNotifierProvider.value(
                          value: s,
                          child: _RiderJobsSheet(r),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.name,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
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
              },
            ),
        ],
      ),
    );
  }
}

class _RiderJobsSheet extends StatelessWidget {
  const _RiderJobsSheet(this.rider);
  final RiderProfile rider;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final jobs = s.jobsOf(rider.uid);
    final pal = context.pal;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              rider.name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
            ),
            Text(
              riderStateOf(rider, jobs, pal.muted).label,
              style: TextStyle(
                color: riderStateOf(rider, jobs, pal.muted).color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (jobs.isEmpty)
              Text(
                'No orders with this rider right now.',
                style: TextStyle(color: pal.muted),
              ),
            for (final o in jobs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OrderTile(order: o),
              ),
            if (rider.phone.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => Launch.call(rider.phone),
                icon: const Icon(Icons.call_rounded),
                label: Text('Call ${rider.name}'),
              ),
          ],
        ),
      ),
    );
  }
}
