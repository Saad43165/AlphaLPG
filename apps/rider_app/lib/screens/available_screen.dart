import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/common.dart';
import '../widgets/job_card.dart';
import 'job_detail_screen.dart';

/// Orders nobody has taken yet. First rider to accept gets the job.
class AvailableScreen extends StatelessWidget {
  const AvailableScreen({super.key, required this.onAccepted});
  final VoidCallback onAccepted;

  Future<void> _accept(BuildContext context, RiderSession s, int index) async {
    final order = s.available[index];
    final result = await s.accept(order);
    if (!context.mounted) return;
    switch (result) {
      case AcceptResult.ok:
        showMessage(context, 'Job accepted. Find it in "My jobs".');
        onAccepted();
      case AcceptResult.taken:
        showMessage(
          context,
          'Too late: another rider took this order.',
          error: true,
        );
      case AcceptResult.offline:
        showMessage(
          context,
          'Go online first (top of the screen) to accept jobs.',
          error: true,
        );
      case AcceptResult.error:
        showMessage(
          context,
          'Could not accept. Check your internet and try again.',
          error: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RiderSession>();
    return Constrained(
      child: Column(
        children: [
          if (!s.online)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF8A6D00),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'You are offline, so you cannot accept orders.',
                      style: TextStyle(
                        color: Color(0xFF5C4600),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => s.setOnline(true),
                    child: const Text('Go online'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: s.available.isEmpty
                ? const EmptyState(
                    icon: Icons.hourglass_empty_rounded,
                    title: 'No new orders',
                    message: 'New orders show up here the moment a customer places one.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: s.available.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final o = s.available[i];
                      return JobCard(
                        order: o,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => JobDetailScreen(orderId: o.id),
                          ),
                        ),
                        action: FilledButton.icon(
                          onPressed: () => _accept(context, s, i),
                          icon: const Icon(Icons.bolt_rounded),
                          label: const Text('Accept job'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
