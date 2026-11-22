import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart' show WhatsAppIcon;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Text;
import 'package:provider/provider.dart';

import '../../l10n/text.dart';
import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../theme/brand.dart';
import '../../utils/format.dart';
import '../../utils/launch.dart';
import '../../widgets/common.dart';
import '../../widgets/report_sheet.dart';

/// Everything about getting help in one place: report a problem with any past
/// order, ask for a refund, and see how each earlier request is going.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _pickOrder(BuildContext context, {bool refund = false}) async {
    final state = context.read<AppState>();
    final uid = state.uid;
    if (uid == null) return;
    final orders = await context
        .read<Backend>()
        .orders
        .watchCustomerOrders(uid)
        .first;
    if (!context.mounted) return;
    if (orders.isEmpty) {
      showMessage(context, 'You have no orders yet.');
      return;
    }
    final picked = await showModalBottomSheet<LpgOrder>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                refund
                    ? 'Which order needs a refund?'
                    : 'Which order is it about?',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              for (final o in orders.take(15))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(o.displayNumber),
                  subtitle: Text(
                    '${o.createdAt == null ? '' : formatDateTime(o.createdAt!.toLocal())} · ${formatRupees(o.total)} · ${o.status.label}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(ctx, o),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && context.mounted) await openReport(context, picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pal = context.pal;
    final s = state.settings;
    final uid = state.uid;
    Widget action(IconData icon, String title, String sub, VoidCallback tap) =>
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(Brand.radius),
            boxShadow: pal.shadow,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: ListTile(
              leading: Icon(icon, color: Brand.blueDark),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(sub),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: tap,
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        leading: const ScreenBack(),
        title: const Text('Help center'),
      ),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (uid != null) ...[
              action(
                Icons.report_gmailerrorred_rounded,
                'Report a problem with an order',
                'Any order, even one from last month',
                () => _pickOrder(context),
              ),
              action(
                Icons.currency_exchange_rounded,
                'Ask for a refund',
                'Pick the order and tell us what happened',
                () => _pickOrder(context, refund: true),
              ),
            ],
            action(
              Icons.help_outline_rounded,
              'Help and FAQs',
              'Quick answers',
              () => context.push('/help'),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: pal.card,
                borderRadius: BorderRadius.circular(Brand.radius),
                boxShadow: pal.shadow,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => Launch.call(s.phone),
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('Call us'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => Launch.whatsapp(s.whatsapp),
                      icon: const WhatsAppIcon(size: 20),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                ],
              ),
            ),
            if (uid != null) ...[
              const SectionTitle('Your earlier requests'),
              StreamBuilder<List<OrderReport>>(
                stream: context.read<Backend>().orders.watchCustomerReports(
                  uid,
                ),
                builder: (context, snap) {
                  final list = snap.data ?? const <OrderReport>[];
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'Nothing yet. If something goes wrong, tell us above.',
                        style: TextStyle(color: pal.muted),
                      ),
                    );
                  }
                  return Column(
                    children: [for (final r in list.take(20)) _Ticket(r)],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Ticket extends StatelessWidget {
  const _Ticket(this.r);
  final OrderReport r;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final (String label, Color color) = r.refund == 'refunded'
        ? ('Refunded', Brand.success)
        : r.refund == 'declined'
        ? ('Refund not approved', Brand.danger)
        : r.isOpen
        ? ('Open', Brand.flame)
        : ('Resolved', Brand.success);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(Brand.radius),
        boxShadow: pal.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r.orderNumber} · ${r.reason}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          if (r.createdAt != null)
            Text(
              formatDateTime(r.createdAt!.toLocal()),
              style: TextStyle(color: pal.muted, fontSize: 12.5),
            ),
          const SizedBox(height: 6),
          Text(
            r.reply.isNotEmpty
                ? 'Alpha LPG: ${r.reply}'
                : 'Sent to Alpha LPG. They are looking into it.',
            style: const TextStyle(height: 1.35),
          ),
        ],
      ),
    );
  }
}
