import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/common.dart';
import '../widgets/job_card.dart';
import 'job_actions.dart';
import 'job_detail_screen.dart';

/// Jobs this rider has accepted and still has to do.
class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key, required this.onFindJobs});
  final VoidCallback onFindJobs;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RiderSession>();
    if (s.jobs.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No jobs right now',
        message: s.online
            ? 'New orders appear in the "New" tab. Accept one to start.'
            : 'You are offline. Go online (top of the screen) to see and accept new orders.',
        action: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(180, 48)),
          onPressed: onFindJobs,
          child: const Text('Look for new orders'),
        ),
      );
    }
    // The delivery on the road first, then the ones still to start.
    final jobs = [...s.jobs]
      ..sort((a, b) {
        int rank(LpgOrder o) => o.status == OrderStatus.outForDelivery ? 0 : 1;
        final c = rank(a).compareTo(rank(b));
        return c != 0
            ? c
            : (a.scheduledFor ?? a.createdAt ?? DateTime(0)).compareTo(
                b.scheduledFor ?? b.createdAt ?? DateTime(0),
              );
      });
    return Constrained(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: jobs.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == 0) return _TodayStrip(session: s);
          final o = jobs[i - 1];
          return JobCard(
            order: o,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => JobDetailScreen(orderId: o.id),
              ),
            ),
            action: o.status == OrderStatus.assigned
                ? FilledButton.icon(
                    onPressed: () => startDeliveryFlow(context, s, o),
                    icon: const Icon(Icons.two_wheeler_rounded),
                    label: const Text('Start delivery'),
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E9E5A),
                    ),
                    onPressed: () => completeDeliveryFlow(context, s, o),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Mark delivered'),
                  ),
          );
        },
      ),
    );
  }
}

/// A slim summary above the jobs: what is on, what is done, cash to hand in.
class _TodayStrip extends StatelessWidget {
  const _TodayStrip({required this.session});
  final RiderSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final pal = context.pal;
    Widget cell(IconData icon, Color color, String value, String label) =>
        Expanded(
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: pal.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: panel(context),
      child: Row(
        children: [
          cell(
            Icons.inventory_2_rounded,
            Brand.blueDark,
            '${s.jobs.length}',
            'To do',
          ),
          cell(
            Icons.check_circle_rounded,
            Brand.success,
            '${s.deliveredToday.length}',
            'Done today',
          ),
          cell(
            Icons.payments_rounded,
            s.cashPending > 0 ? const Color(0xFF9A6B00) : pal.muted,
            formatRupees(s.cashPending),
            'Cash with you',
          ),
        ],
      ),
    );
  }
}
