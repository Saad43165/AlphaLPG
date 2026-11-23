import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/order_x.dart';
import '../widgets/common.dart';
import 'earnings_screen.dart';
import 'job_detail_screen.dart';

/// Finished jobs, grouped by day, with what was collected each day.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static String _day(DateTime d) {
    final n = DateTime.now();
    final t = DateTime(n.year, n.month, n.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = t.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEEE d MMM').format(d);
  }

  static DateTime _when(LpgOrder o) =>
      o.timeOf(OrderStatus.delivered) ??
      o.updatedAt ??
      o.createdAt ??
      DateTime(0);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RiderSession>();
    final pal = context.pal;
    final today = s.deliveredToday;
    // Group by day (history is newest first).
    final groups = <String, List<LpgOrder>>{};
    for (final o in s.history) {
      (groups[_day(_when(o))] ??= []).add(o);
    }
    final pending = s.cashPending;
    return Constrained(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Cash the rider still has to hand over: the thing that matters.
          Material(
            color: context.pal.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Brand.radius),
              side: BorderSide(
                color: pending > 0 ? context.pal.warn : Brand.success,
                width: 2,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(Brand.radius),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: s,
                    child: const EarningsScreen(),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      pending > 0
                          ? Icons.account_balance_wallet_rounded
                          : Icons.verified_rounded,
                      color: pending > 0 ? Brand.warning : Brand.success,
                      size: 30,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pending > 0
                                ? 'Cash to hand to Alpha LPG'
                                : 'All cash handed in',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: pending > 0
                                  ? const Color(0xFF5C4600)
                                  : null,
                            ),
                          ),
                          if (pending > 0)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formatRupees(pending),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 26,
                                  color: Color(0xFF5C4600),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Stat(
                icon: Icons.check_circle_rounded,
                color: Brand.success,
                value: '${today.length}',
                label: 'Done today',
              ),
              const SizedBox(width: 10),
              _Stat(
                icon: Icons.payments_rounded,
                color: const Color(0xFF9A6B00),
                value: formatRupees(s.cashToday),
                label: 'Cash today',
              ),
              const SizedBox(width: 10),
              _Stat(
                icon: Icons.autorenew_rounded,
                color: Brand.blueDark,
                value: '${s.emptiesToday}',
                label: 'Empties today',
              ),
            ],
          ),
          if (s.history.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.history_rounded,
                title: 'No deliveries yet',
                message: 'Completed jobs will be listed here with the cash you collected.',
              ),
            ),
          for (final e in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
              child: Row(
                children: [
                  Text(
                    e.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${e.value.where((o) => o.status == OrderStatus.delivered).length} delivered'
                      ' · ${formatRupees(e.value.fold(0, (n, o) => n + (o.cashCollected ?? 0)))} cash',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: pal.muted, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            for (final o in e.value)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HistoryTile(order: o),
              ),
          ],
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.order});
  final LpgOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final pal = context.pal;
    final delivered = o.status == OrderStatus.delivered;
    final cash = o.cashCollected ?? 0;
    final expected = o.emptiesToCollect;
    final took = o.emptiesCollected ?? 0;
    return Container(
      decoration: panel(context),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(Brand.radius),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => JobDetailScreen(orderId: o.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${o.displayNumber} · ${DateFormat('h:mm a').format(HistoryScreen._when(o))}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: pal.muted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(o.status),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 16, color: pal.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${o.areaLine} · ${o.itemsLine}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: pal.muted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                if (delivered) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Pill(
                        Icons.payments_rounded,
                        cash > 0
                            ? 'Cash ${formatRupees(cash)}'
                            : o.paymentMethod.isPrepaid
                            ? 'Paid online'
                            : 'No cash',
                        color: cash > 0
                            ? const Color(0xFF9A6B00)
                            : Brand.success,
                      ),
                      if (expected > 0)
                        Pill(
                          Icons.autorenew_rounded,
                          'Empties $took of $expected',
                          color: took == expected
                              ? Brand.success
                              : context.pal.warn,
                        ),
                    ],
                  ),
                ] else if (o.cancelReason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Cancelled: ${o.cancelReason}',
                    style: TextStyle(color: pal.muted, fontSize: 13),
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

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
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
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.pal.muted, fontSize: 11.5),
          ),
        ],
      ),
    ),
  );
}
