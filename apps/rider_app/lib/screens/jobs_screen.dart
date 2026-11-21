import 'package:alpha_core/alpha_core.dart';
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
    return Constrained(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: s.jobs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final o = s.jobs[i];
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
