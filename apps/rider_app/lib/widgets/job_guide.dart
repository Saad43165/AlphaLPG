import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/order_x.dart';
import 'common.dart';

/// One box saying what the rider should do right now with this job.
class JobNextStep extends StatelessWidget {
  const JobNextStep({super.key, required this.order, required this.mine});
  final LpgOrder order;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final waiting = o.awaitingOnlinePayment;
    final (IconData icon, Color color, String title, String text) = !mine
        ? (
            Icons.info_outline_rounded,
            Brand.blueDark,
            'Not your job',
            'Accept it from the New tab to deliver it.',
          )
        : switch (o.status) {
            OrderStatus.assigned => (
              Icons.inventory_2_rounded,
              Brand.blueDark,
              'Load the cylinders, then start',
              'Check the items below. Tap "Start delivery" when you leave. The customer then follows you on the map.',
            ),
            OrderStatus.outForDelivery =>
              o.arrivedAt == null
                  ? (
                      Icons.navigation_rounded,
                      Brand.success,
                      'Go to the customer',
                      'Use Navigate. Tap "I have arrived" when you reach the door.',
                    )
                  : waiting
                  ? (
                      Icons.hourglass_top_rounded,
                      context.pal.warn,
                      'Wait: payment not confirmed',
                      'The customer pays ${o.paymentMethod.label} and Alpha LPG must confirm it first. Do not take cash. Ask the shop if it takes long.',
                    )
                  : (
                      Icons.check_circle_rounded,
                      Brand.success,
                      'Hand over and finish',
                      o.amountDue > 0
                          ? 'Take ${formatRupees(o.amountDue)} cash, collect ${o.emptiesToCollect} empty cylinder${o.emptiesToCollect == 1 ? '' : 's'}, then tap "Mark delivered".'
                          : 'Collect ${o.emptiesToCollect} empty cylinder${o.emptiesToCollect == 1 ? '' : 's'}, then tap "Mark delivered". No cash to take.',
                    ),
            OrderStatus.delivered => (
              Icons.verified_rounded,
              Brand.success,
              'Delivered',
              'Well done. This job is finished.',
            ),
            OrderStatus.cancelled => (
              Icons.cancel_rounded,
              Brand.danger,
              'Cancelled',
              'You do not need to deliver this order.',
            ),
            _ => (
              Icons.info_outline_rounded,
              Brand.blueDark,
              'Waiting',
              'Alpha LPG will tell you the next step.',
            ),
          };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.pal.card,
        borderRadius: BorderRadius.circular(Brand.radius),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// When the customer wants it (shown only for scheduled orders).
class JobSchedule extends StatelessWidget {
  const JobSchedule({super.key, required this.order});
  final LpgOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    if (o.scheduledFor == null) return const SizedBox.shrink();
    final slot = o.notes.split('\n').first;
    final label = slot.startsWith('Slot: ') ? slot.substring(6) : '';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: panel(context),
      child: Row(
        children: [
          Icon(Icons.event_rounded, color: context.pal.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Customer wants it on ${DateFormat('EEE d MMM').format(o.scheduledFor!)}'
              '${label.isEmpty ? '' : ', $label'}',
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

const _problems = [
  ('Customer is not answering', Icons.phone_disabled_rounded),
  ('Wrong or missing address', Icons.wrong_location_rounded),
  ('Customer says cancel / refuses', Icons.do_not_disturb_on_rounded),
  ('Payment problem', Icons.payments_rounded),
  ('Problem with the cylinder', Icons.warning_amber_rounded),
  ('Accident or vehicle problem', Icons.car_crash_rounded),
  ('Something else', Icons.more_horiz_rounded),
];

/// "Report a problem": goes straight to Alpha LPG (not into the customer
/// chat), and shows the shop's answers.
class JobProblem extends StatelessWidget {
  const JobProblem({super.key, required this.order});
  final LpgOrder order;

  Future<void> _report(BuildContext context) async {
    final s = context.read<RiderSession>();
    final picked = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ProblemSheet(),
    );
    if (picked == null || !context.mounted) return;
    final err = await s.reportProblem(order, picked.$1, picked.$2);
    if (context.mounted) {
      showMessage(
        context,
        err ?? 'Sent to Alpha LPG. They will call you or the customer.',
        error: err != null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<RiderSession>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: Brand.danger,
          ),
          onPressed: () => _report(context),
          icon: const Icon(Icons.flag_outlined),
          label: const Text('Report a problem to Alpha LPG'),
        ),
        StreamBuilder<List<OrderReport>>(
          stream: s.backend.orders.watchRiderReports(
            order.id,
            s.profile?.uid ?? '',
          ),
          builder: (context, snap) {
            final list = snap.data ?? const <OrderReport>[];
            return Column(
              children: [
                for (final r in list)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.pal.card,
                      border: Border.all(
                        color: r.isOpen ? context.pal.warn : Brand.success,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You reported: ${r.reason}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          r.reply.isNotEmpty
                              ? 'Alpha LPG: ${r.reply}'
                              : r.isOpen
                              ? 'Sent. Alpha LPG is looking into it.'
                              : 'Resolved.',
                          style: const TextStyle(height: 1.35),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProblemSheet extends StatefulWidget {
  const _ProblemSheet();

  @override
  State<_ProblemSheet> createState() => _ProblemSheetState();
}

class _ProblemSheetState extends State<_ProblemSheet> {
  String? _reason;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'What is the problem?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
            ),
            const SizedBox(height: 4),
            Text(
              'This goes privately to Alpha LPG. The customer does not see it.',
              style: TextStyle(color: pal.muted),
            ),
            const SizedBox(height: 10),
            for (final (label, icon) in _problems)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: _reason == label ? pal.tint : pal.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _reason == label ? Brand.blueDark : pal.line,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(icon, color: context.pal.blue),
                    title: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: _reason == label
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: context.pal.blue,
                          )
                        : null,
                    onTap: () => setState(() => _reason = label),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            TextField(
              controller: _details,
              maxLines: 2,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'More details (optional)',
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
              onPressed: _reason == null
                  ? null
                  : () => Navigator.pop(context, (
                      _reason!,
                      _details.text.trim(),
                    )),
              icon: const Icon(Icons.send_rounded),
              label: Text(
                _reason == null ? 'Choose the problem' : 'Send to Alpha LPG',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
