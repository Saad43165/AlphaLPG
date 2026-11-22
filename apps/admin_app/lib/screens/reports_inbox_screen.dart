import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/launch.dart';
import '../widgets/common.dart';
import 'order_detail_screen.dart';

/// Complaints customers send about an order or a rider.
class ReportsInboxScreen extends StatefulWidget {
  const ReportsInboxScreen({super.key, this.orderId});

  /// Only this order's reports (null = all).
  final String? orderId;

  @override
  State<ReportsInboxScreen> createState() => _ReportsInboxScreenState();
}

class _ReportsInboxScreenState extends State<ReportsInboxScreen> {
  bool _openOnly = true;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final list = [
      for (final r in s.reports)
        if ((widget.orderId == null || r.orderId == widget.orderId) &&
            (!_openOnly || r.isOpen))
          r,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Customer reports')),
      body: Constrained(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('Open · ${s.openReportCount}'),
                    selected: _openOnly,
                    onSelected: (_) => setState(() => _openOnly = true),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('All'),
                    selected: !_openOnly,
                    onSelected: (_) => setState(() => _openOnly = false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.verified_user_rounded,
                      title: 'Nothing to look at',
                      message: 'When a customer reports a problem with an order or a rider, it shows up here.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => ReportCard(list[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportCard extends StatelessWidget {
  const ReportCard(this.r, {super.key, this.showOrderLink = true});
  final OrderReport r;
  final bool showOrderLink;

  Future<void> _answer(BuildContext context) async {
    final s = context.read<AdminSession>();
    final c = TextEditingController(text: r.reply);
    final resolved = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Answer the customer'),
        content: TextField(
          controller: c,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'What did you do? (the customer sees this)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Reply, keep open'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Reply and close'),
          ),
        ],
      ),
    );
    if (resolved == null || !context.mounted) return;
    final err = await s.resolveReport(
      r,
      reply: c.text.trim(),
      resolved: resolved,
    );
    if (context.mounted) {
      showMessage(context, err ?? 'Sent to the customer', error: err != null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM, h:mm a');
    final color = r.isOpen ? Brand.danger : Brand.success;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: panel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pill(
                r.aboutRider ? Icons.two_wheeler_rounded : Icons.flag_rounded,
                r.aboutRider ? 'About rider' : 'About order',
                color: color,
              ),
              Pill(
                r.isOpen ? Icons.error_outline_rounded : Icons.check_rounded,
                r.isOpen ? 'Open' : 'Resolved',
                color: color,
              ),
              Text(
                r.createdAt == null ? '' : fmt.format(r.createdAt!.toLocal()),
                style: TextStyle(color: context.pal.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            r.reason,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          if (r.details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('"${r.details}"', style: const TextStyle(height: 1.4)),
          ],
          const SizedBox(height: 8),
          Text(
            '${r.customerName} · ${prettyPhone(r.customerPhone)} · ${r.orderNumber}'
            '${r.riderName == null ? '' : ' · rider ${r.riderName}'}',
            style: TextStyle(color: context.pal.muted, fontSize: 13),
          ),
          if (r.reply.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Your answer: ${r.reply}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => _answer(context),
                icon: const Icon(Icons.reply_rounded, size: 18),
                label: Text(r.isOpen ? 'Answer' : 'Edit answer'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => Launch.call(r.customerPhone),
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('Call'),
              ),
              if (showOrderLink)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: context.read<AdminSession>(),
                        child: OrderDetailScreen(orderId: r.orderId),
                      ),
                    ),
                  ),
                  child: const Text('Open order'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
