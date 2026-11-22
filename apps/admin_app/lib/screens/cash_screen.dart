import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/order_x.dart';
import '../widgets/common.dart';

/// Cash each rider collected, what they have handed in, and today's closing.
class CashScreen extends StatelessWidget {
  const CashScreen({super.key, this.embedded = false});
  final bool embedded;

  Future<void> _handover(
    BuildContext context,
    RiderProfile r,
    int suggested,
  ) async {
    final s = context.read<AdminSession>();
    final amount = TextEditingController(
      text: suggested > 0 ? '$suggested' : '',
    );
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Cash from ${r.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Amount received (Rs)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final n = int.tryParse(amount.text.trim()) ?? 0;
    if (ok != true || n <= 0 || !context.mounted) return;
    final err = await s.addHandover(r, n, note: note.text.trim());
    if (context.mounted) {
      showMessage(context, err ?? 'Recorded', error: err != null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    // Orders are loaded newest first and only so many; count handovers only
    // from the oldest loaded order onwards so the two sides match.
    DateTime? since;
    for (final o in s.orders) {
      final t = o.createdAt;
      if (t != null && (since == null || t.isBefore(since))) since = t;
    }
    final handovers = [
      for (final h in s.handovers)
        if (since == null || h.at == null || !h.at!.isBefore(since)) h,
    ];
    final deliveredToday = s.orders
        .where(
          (o) =>
              o.status == OrderStatus.delivered &&
              (o.timeOf(OrderStatus.delivered) ?? o.updatedAt ?? DateTime(0))
                  .isAfter(startOfDay),
        )
        .toList();
    final sales = deliveredToday.fold(0, (n, o) => n + o.total);
    final cashToday = deliveredToday.fold(
      0,
      (n, o) => n + (o.cashCollected ?? 0),
    );
    final onlineToday = deliveredToday
        .where((o) => o.paymentMethod.isPrepaid)
        .fold(0, (n, o) => n + o.total);
    final handedToday = handovers
        .where((h) => h.at != null && h.at!.isAfter(startOfDay))
        .fold(0, (n, h) => n + h.amount);
    final rows = <(RiderProfile, RiderCash)>[
      for (final r in s.riders) (r, riderCash(r.uid, s.orders, handovers)),
    ]..sort((a, b) => b.$2.pending.compareTo(a.$2.pending));
    final totalPending = rows.fold(0, (n, e) => n + e.$2.pending);
    final fmt = DateFormat('d MMM, h:mm a');
    return Scaffold(
      appBar: embedded ? null : AppBar(title: const Text('Cash handover')),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: panel(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's closing · ${DateFormat('EEE d MMM').format(now)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Line('Deliveries', '${deliveredToday.length}'),
                  _Line('Sales (delivered)', rs(sales)),
                  _Line('Cash collected by riders', rs(cashToday)),
                  _Line('Paid online (confirmed)', rs(onlineToday)),
                  _Line('Cash handed in today', rs(handedToday)),
                  const Divider(),
                  _Line(
                    'Cash still with riders',
                    rs(totalPending),
                    bold: true,
                    color: totalPending > 0 ? Brand.flame : Brand.success,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Riders',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text(
                'No riders yet.',
                style: TextStyle(color: context.pal.muted),
              ),
            for (final (r, c) in rows)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: panel(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          rs(c.pending),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: c.pending > 0 ? Brand.flame : Brand.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Collected ${rs(c.collected)} · handed in ${rs(c.handedIn)} · ${c.deliveries} deliveries',
                      style: TextStyle(color: context.pal.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: () => _handover(context, r, c.pending),
                      icon: const Icon(Icons.payments_rounded, size: 18),
                      label: const Text('Receive cash'),
                    ),
                  ],
                ),
              ),
            if (handovers.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Recent handovers',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              for (final h in handovers.take(15))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${h.riderName} · ${rs(h.amount)}'),
                  subtitle: Text(
                    '${h.at == null ? '' : fmt.format(h.at!.toLocal())}${h.note.isEmpty ? '' : ' · ${h.note}'}',
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Text(
              since == null
                  ? ''
                  : 'Based on orders since ${DateFormat('d MMM').format(since)}.',
              style: TextStyle(color: context.pal.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.k, this.v, {this.bold = false, this.color});
  final String k;
  final String v;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(k)),
        Text(
          v,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: bold ? 16 : 14,
            color: color,
          ),
        ),
      ],
    ),
  );
}
