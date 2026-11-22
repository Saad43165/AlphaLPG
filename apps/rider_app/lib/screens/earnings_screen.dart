import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/common.dart';

/// A rider's own numbers: deliveries, cash collected, cash to hand in.
class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RiderSession>();
    final uid = s.profile?.uid ?? '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime when(LpgOrder o) =>
        o.timeOf(OrderStatus.delivered) ?? o.updatedAt ?? DateTime(0);
    final delivered = [
      for (final o in s.history)
        if (o.status == OrderStatus.delivered) o,
    ];
    List<LpgOrder> since(DateTime t) => [
      for (final o in delivered)
        if (!when(o).isBefore(t)) o,
    ];
    final week = since(today.subtract(const Duration(days: 6)));
    final month = since(today.subtract(const Duration(days: 29)));
    final todays = since(today);
    int cash(Iterable<LpgOrder> l) =>
        l.fold(0, (n, o) => n + (o.cashCollected ?? 0));
    final c = riderCash(uid, s.history, s.handovers);
    final rated = [
      for (final o in delivered)
        if (o.rating != null) o.rating!,
    ];
    final avg = rated.isEmpty
        ? null
        : rated.reduce((a, b) => a + b) / rated.length;
    final fmt = DateFormat('d MMM, h:mm a');
    Widget row(String label, List<LpgOrder> l) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${l.length} deliveries',
                  style: TextStyle(color: context.pal.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatRupees(cash(l)),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('My earnings and cash')),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: c.pending > 0
                    ? const LinearGradient(
                        colors: [Color(0xFFF6C23E), Color(0xFFE9A92A)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF23B26A), Color(0xFF137A47)],
                      ),
                borderRadius: BorderRadius.circular(Brand.radius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.pending > 0
                        ? 'Cash to hand to Alpha LPG'
                        : 'All cash handed in',
                    style: TextStyle(
                      color: c.pending > 0 ? Brand.navy : Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatRupees(c.pending),
                    style: TextStyle(
                      color: c.pending > 0 ? Brand.navy : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                    ),
                  ),
                  Text(
                    'Collected ${formatRupees(c.collected)} · handed in ${formatRupees(c.handedIn)}',
                    style: TextStyle(
                      color: (c.pending > 0 ? Brand.navy : Colors.white)
                          .withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const Heading('Deliveries and cash collected'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: panel(context),
              child: Column(
                children: [
                  row('Today', todays),
                  const Divider(height: 1),
                  row('Last 7 days', week),
                  const Divider(height: 1),
                  row('Last 30 days', month),
                ],
              ),
            ),
            const Heading('Customer rating'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: panel(context),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Brand.flame, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      avg == null
                          ? 'No ratings yet'
                          : '${avg.toStringAsFixed(1)} / 5',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Text(
                    '${rated.length} rated',
                    style: TextStyle(color: context.pal.muted),
                  ),
                ],
              ),
            ),
            if (s.handovers.isNotEmpty) ...[
              const Heading('Cash you handed in'),
              for (final h in s.handovers.take(10))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(formatRupees(h.amount)),
                  subtitle: Text(
                    h.at == null ? '' : fmt.format(h.at!.toLocal()),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Text(
              'Based on your last ${s.history.length} orders.',
              style: TextStyle(color: context.pal.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
