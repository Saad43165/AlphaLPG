import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/order_x.dart';
import '../widgets/common.dart';

enum _Period { today, week, month, all }

/// Sales, cash and cylinders for a period: what the owner checks every night.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Period _p = _Period.today;

  DateTime? get _from {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return switch (_p) {
      _Period.today => today,
      _Period.week => today.subtract(const Duration(days: 6)),
      _Period.month => today.subtract(const Duration(days: 29)),
      _Period.all => null,
    };
  }

  DateTime _when(LpgOrder o) =>
      o.timeOf(OrderStatus.delivered) ??
      o.updatedAt ??
      o.createdAt ??
      DateTime(2000);

  bool _inRange(DateTime? t) {
    final f = _from;
    return f == null || (t != null && !t.isBefore(f));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final delivered = [
      for (final o in s.orders)
        if (o.status == OrderStatus.delivered && _inRange(_when(o))) o,
    ];
    final placed = [
      for (final o in s.orders)
        if (_inRange(o.createdAt)) o,
    ];
    final cancelled = placed.where((o) => o.status == OrderStatus.cancelled);
    final revenue = delivered.fold(0, (n, o) => n + o.total);
    final cylinders = delivered.fold(0, (n, o) => n + o.cylinderCount);
    final cashByRiders = delivered.fold(
      0,
      (n, o) => n + (o.cashCollected ?? 0),
    );
    final prepaidReceived = delivered
        .where(
          (o) =>
              o.paymentMethod.isPrepaid &&
              o.paymentStatus == PaymentStatus.paid,
        )
        .fold(0, (n, o) => n + o.total);
    final unpaid = delivered
        .where((o) => o.paymentStatus != PaymentStatus.paid)
        .fold(0, (n, o) => n + o.total);

    final byProduct = <String, int>{};
    for (final o in delivered) {
      for (final i in o.items) {
        byProduct[i.name] = (byProduct[i.name] ?? 0) + i.quantity;
      }
    }
    final byRider = <String, ({int jobs, int cash})>{};
    for (final o in delivered) {
      final k = o.riderName ?? 'Unassigned';
      final cur = byRider[k] ?? (jobs: 0, cash: 0);
      byRider[k] = (
        jobs: cur.jobs + 1,
        cash: cur.cash + (o.cashCollected ?? 0),
      );
    }
    final riders = byRider.entries.toList()
      ..sort((a, b) => b.value.jobs.compareTo(a.value.jobs));
    final products = byProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    Widget tile(String label, String value, IconData icon, Color color) =>
        Container(
          padding: const EdgeInsets.all(14),
          decoration: panel(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(color: context.pal.muted, fontSize: 12.5),
              ),
            ],
          ),
        );

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('Sales & cash report')),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            SegmentedButton<_Period>(
              // No tick on the chosen one: it squeezed "Today" onto two lines.
              showSelectedIcon: false,
              style: const ButtonStyle(
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: _Period.today,
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('Today')),
                ),
                ButtonSegment(
                  value: _Period.week,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('7 days'),
                  ),
                ),
                ButtonSegment(
                  value: _Period.month,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('30 days'),
                  ),
                ),
                ButtonSegment(
                  value: _Period.all,
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('All')),
                ),
              ],
              selected: {_p},
              onSelectionChanged: (v) => setState(() => _p = v.first),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              // Taller tiles when the phone's text size is large.
              childAspectRatio: MediaQuery.textScalerOf(context).scale(14) > 18
                  ? 0.8
                  : 1.55,
              children: [
                tile(
                  'Sales delivered',
                  rs(revenue),
                  Icons.payments_rounded,
                  Brand.success,
                ),
                tile(
                  'Orders delivered',
                  '${delivered.length}',
                  Icons.check_circle_rounded,
                  Brand.blueDark,
                ),
                tile(
                  'Cylinders delivered',
                  '$cylinders',
                  Icons.propane_tank_rounded,
                  const Color(0xFFE53424),
                ),
                tile(
                  'Average order',
                  delivered.isEmpty
                      ? '–'
                      : rs((revenue / delivered.length).round()),
                  Icons.analytics_rounded,
                  Brand.blueDeep,
                ),
              ],
            ),
            const Heading('Money'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: panel(context),
              child: Column(
                children: [
                  _Line('Cash taken by riders', rs(cashByRiders)),
                  _Line('Wallet / bank received', rs(prepaidReceived)),
                  _Line(
                    'Delivered but not paid yet',
                    rs(unpaid),
                    warn: unpaid > 0,
                  ),
                ],
              ),
            ),
            const Heading('Orders'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: panel(context),
              child: Column(
                children: [
                  _Line('Placed', '${placed.length}'),
                  _Line('Delivered', '${delivered.length}'),
                  _Line('Cancelled', '${cancelled.length}'),
                ],
              ),
            ),
            if (products.isNotEmpty) ...[
              const Heading('Cylinders sold'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: panel(context),
                child: Column(
                  children: [
                    for (final e in products) _Line(e.key, '${e.value}'),
                  ],
                ),
              ),
            ],
            if (riders.isNotEmpty) ...[
              const Heading('By rider'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: panel(context),
                child: Column(
                  children: [
                    for (final e in riders)
                      _Line(
                        e.key,
                        '${e.value.jobs} job${e.value.jobs == 1 ? '' : 's'} · cash ${rs(e.value.cash)}',
                      ),
                  ],
                ),
              ),
            ],
            if (delivered.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: Icons.insights_rounded,
                  title: 'No deliveries in this period yet',
                  message: 'Figures appear here as orders are delivered.',
                ),
              ),
            if (s.orders.length >= 300)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Based on your latest 300 orders.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.pal.muted, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.k, this.v, {this.warn = false});
  final String k, v;
  final bool warn;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: TextStyle(color: context.pal.muted)),
        ),
        Text(
          v,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: warn ? context.pal.orange : null,
          ),
        ),
      ],
    ),
  );
}
