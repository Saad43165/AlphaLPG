import 'package:alpha_core/alpha_core.dart';

import '../l10n/lang.dart';

import 'package:material_ui/material_ui.dart' hide Text;

import '../l10n/text.dart';

import 'package:provider/provider.dart';

import '../services/backend.dart';
import '../state/app_state.dart';
import '../theme/brand.dart';
import 'common.dart';

const _orderReasons = [
  ('Rider is late', Icons.schedule_rounded),
  ('Wrong cylinder or quantity', Icons.swap_horiz_rounded),
  ('Cylinder not delivered', Icons.report_gmailerrorred_rounded),
  ('Cylinder leaking or damaged', Icons.warning_amber_rounded),
  ('Payment or price problem', Icons.payments_rounded),
  ('Refund request', Icons.currency_exchange_rounded),
  ('Something else', Icons.more_horiz_rounded),
];

const _riderReasons = [
  ('Rude or bad behaviour', Icons.person_off_rounded),
  ('Asked for extra money', Icons.money_off_rounded),
  ('Did not come / very late', Icons.schedule_rounded),
  ('Unsafe handling of cylinders', Icons.warning_amber_rounded),
  ('Something else', Icons.more_horiz_rounded),
];

/// A complaint that goes straight to Alpha LPG (not into the chat).
Future<void> openReport(
  BuildContext context,
  LpgOrder o, {
  bool aboutRider = false,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportSheet(order: o, aboutRider: aboutRider),
  );
  if (sent == true && context.mounted) {
    showMessage(
      context,
      'Report sent to Alpha LPG. They will look into it and contact you.',
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.order, required this.aboutRider});
  final LpgOrder order;
  final bool aboutRider;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  final _details = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final o = widget.order;
    final state = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Backend>().orders.addReport(
        OrderReport(
          orderId: o.id,
          orderNumber: o.displayNumber,
          customerId: o.customerId,
          customerName: state.profile?.name ?? o.customerName,
          customerPhone: o.customerPhone,
          riderId: o.riderId,
          riderName: o.riderName,
          about: widget.aboutRider ? 'rider' : 'order',
          reason: _reason!,
          details: _details.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not send. Check your internet and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = widget.aboutRider ? _riderReasons : _orderReasons;
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
            Text(
              widget.aboutRider
                  ? 'Report a problem with ${widget.order.riderName ?? 'the rider'}'
                  : 'What went wrong?',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
            ),
            const SizedBox(height: 4),
            Text(
              'This goes privately to Alpha LPG for order ${widget.order.displayNumber}. '
              '${widget.aboutRider ? 'The rider does not see it.' : ''}',
              style: TextStyle(color: pal.muted, height: 1.35),
            ),
            const SizedBox(height: 10),
            for (final (label, icon) in reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: _reason == label
                      ? Brand.blueDark.withValues(alpha: 0.12)
                      : pal.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _reason == label ? Brand.blueDark : pal.line,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(icon, color: Brand.blueDark),
                    title: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: _reason == label
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Brand.blueDark,
                          )
                        : null,
                    onTap: () => setState(() => _reason = label),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _details,
              maxLines: 3,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: tr('Tell us more (optional)'),
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Brand.danger),
                ),
              ),
            FilledButton.icon(
              onPressed: _reason == null || _busy ? null : _send,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _reason == null ? 'Choose what happened' : 'Send to Alpha LPG',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The customer's reports on this order, with the shop's answer.
class MyReports extends StatelessWidget {
  const MyReports(this.order, {super.key});
  final LpgOrder order;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<OrderReport>>(
    stream: context.read<Backend>().orders.watchOrderReports(
      order.id,
      order.customerId,
    ),
    builder: (context, snap) {
      final list = snap.data ?? const <OrderReport>[];
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(
        children: [
          for (final r in list)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (r.isOpen ? Brand.flame : Brand.success).withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r.aboutRider ? 'Report about the rider' : 'Your report'}: ${r.reason}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.reply.isNotEmpty
                        ? 'Alpha LPG: ${r.reply}'
                        : (r.isOpen
                              ? 'Sent to Alpha LPG. They are looking into it.'
                              : 'Resolved by Alpha LPG.'),
                    style: const TextStyle(height: 1.35),
                  ),
                  if (r.refund != 'none') ...[
                    const SizedBox(height: 4),
                    Text(
                      r.refund == 'refunded'
                          ? 'Refund: done'
                          : 'Refund: not approved',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: r.refund == 'refunded'
                            ? Brand.success
                            : Brand.danger,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      );
    },
  );
}
