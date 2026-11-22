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
  const ReportsInboxScreen({super.key, this.orderId, this.embedded = false});

  /// Inside the Inbox tabs: no title bar of its own.
  final bool embedded;

  /// Only this order's reports (null = all).
  final String? orderId;

  @override
  State<ReportsInboxScreen> createState() => _ReportsInboxScreenState();
}

class _ReportsInboxScreenState extends State<ReportsInboxScreen> {
  bool _openOnly = true;
  int _from = 0; // 0 everyone, 1 customers, 2 riders

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final list = [
      for (final r in s.reports)
        if ((widget.orderId == null || r.orderId == widget.orderId) &&
            (!_openOnly || r.isOpen) &&
            (_from == 0 || (_from == 2) == r.fromRider))
          r,
    ];
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('Reports and problems')),
      body: Constrained(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: Text('Open · ${s.openReportCount}'),
                    selected: _openOnly,
                    onSelected: (_) => setState(() => _openOnly = true),
                  ),
                  ChoiceChip(
                    label: const Text('All'),
                    selected: !_openOnly,
                    onSelected: (_) => setState(() => _openOnly = false),
                  ),
                  PopupMenuButton<int>(
                    tooltip: 'Show reports from',
                    initialValue: _from,
                    onSelected: (v) => setState(() => _from = v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 0, child: Text('Everyone')),
                      PopupMenuItem(value: 1, child: Text('Customers only')),
                      PopupMenuItem(value: 2, child: Text('Riders only')),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.filter_list_rounded, size: 18),
                      label: Text(
                        const ['Everyone', 'Customers', 'Riders'][_from],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.verified_user_rounded,
                      title: 'Nothing to look at',
                      message: 'When a customer or a rider reports a problem, it shows up here. Answer it and the sender sees your reply.',
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
    var refund = r.refund;
    final resolved = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setS) => AlertDialog(
          title: const Text('Answer the customer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: c,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'What did you do? (the customer sees this)',
                  ),
                ),
                if (!r.fromRider) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Refund (shown to the customer)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (v, label) in const [
                        ('none', 'No refund'),
                        ('refunded', 'Refunded'),
                        ('declined', 'Declined'),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: refund == v,
                          onSelected: (_) => setS(() => refund = v),
                        ),
                    ],
                  ),
                ],
              ],
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
      ),
    );
    if (resolved == null || !context.mounted) return;
    final err = await s.resolveReport(
      r,
      reply: c.text.trim(),
      resolved: resolved,
      refund: refund,
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
                r.fromRider
                    ? Icons.two_wheeler_rounded
                    : r.aboutRider
                    ? Icons.person_off_rounded
                    : Icons.flag_rounded,
                r.fromRider
                    ? 'From rider ${r.riderName ?? ''}'.trim()
                    : r.aboutRider
                    ? 'Customer: about rider'
                    : 'Customer: about order',
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
