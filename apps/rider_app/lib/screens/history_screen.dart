import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/common.dart';
import '../widgets/job_card.dart';
import 'job_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static String _day(DateTime d) {
    final n = DateTime.now();
    final t = DateTime(n.year, n.month, n.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = t.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RiderSession>();
    final today = s.deliveredToday;
    // Group by day.
    final groups = <String, List<LpgOrder>>{};
    for (final o in s.history) {
      final t =
          o.timeOf(OrderStatus.delivered) ??
          o.updatedAt ??
          o.createdAt ??
          DateTime(0);
      (groups[_day(t)] ??= []).add(o);
    }
    return Constrained(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              _Stat(
                icon: Icons.check_circle_rounded,
                color: Brand.success,
                value: '${today.length}',
                label: 'Delivered today',
              ),
              const SizedBox(width: 10),
              _Stat(
                icon: Icons.payments_rounded,
                color: const Color(0xFF9A6B00),
                value: formatRupees(s.cashToday),
                label: 'Cash to hand in',
              ),
              const SizedBox(width: 10),
              _Stat(
                icon: Icons.autorenew_rounded,
                color: Brand.blueDark,
                value: '${s.emptiesToday}',
                label: 'Empties back',
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
            Heading(e.key),
            for (final o in e.value)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: JobCard(
                  order: o,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => JobDetailScreen(orderId: o.id),
                    ),
                  ),
                ),
              ),
          ],
        ],
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
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(color: context.pal.muted, fontSize: 11.5),
          ),
        ],
      ),
    ),
  );
}
