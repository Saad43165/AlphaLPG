import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/order_x.dart';
import '../utils/payment_checks.dart';

String _accountFor(PaymentMethod m, AppSettings s) => switch (m) {
  PaymentMethod.jazzCash => s.jazzCashAccount,
  PaymentMethod.easyPaisa => s.easyPaisaAccount,
  PaymentMethod.bankTransfer =>
    s.bankDetails.isNotEmpty ? s.bankDetails : s.raastId,
  PaymentMethod.cashOnDelivery => '',
};

/// Admin tools inside an order's Payment section: send the customer the
/// account to pay, see the receipts they upload, and flag a problem.
class PaymentPanel extends StatelessWidget {
  const PaymentPanel(this.order, {super.key});
  final LpgOrder order;

  Future<void> _send(BuildContext context) async {
    final s = context.read<AdminSession>();
    final req = await showModalBottomSheet<PaymentRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SendSheet(order: order, settings: s.settings),
    );
    if (req == null || !context.mounted) return;
    final err = await s.sendPaymentRequest(order, req);
    if (!context.mounted) return;
    showAppMessage(
      context,
      err ?? 'Sent to ${order.customerName}',
      error: err != null,
    );
  }

  Future<void> _problem(BuildContext context) async {
    final s = context.read<AdminSession>();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ProblemSheet(),
    );
    if (text == null || !context.mounted) return;
    final err = await s.setPaymentIssue(order, text);
    if (!context.mounted) return;
    showAppMessage(
      context,
      err ?? (text.isEmpty ? 'Problem cleared' : 'Customer told'),
      error: err != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    final req = o.paymentRequest;
    final prepaid = o.paymentMethod.isPrepaid;
    if (!prepaid || o.status == OrderStatus.cancelled) {
      return const SizedBox.shrink();
    }
    final paid = o.paymentStatus == PaymentStatus.paid;
    final backend = context.read<AdminSession>().backend;
    final fmt = DateFormat('d MMM, h:mm a');
    final stage = o.payStage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stage != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.pal.card,
              border: Border.all(
                color: stage == PayStage.sendDetails
                    ? Brand.cylinderRed
                    : context.pal.warn,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(switch (stage) {
              PayStage.sendDetails =>
                'To do: send ${o.paymentMethod.label} payment details to the customer. They have not received them yet.',
              PayStage.waiting => 'Details sent. Waiting for the customer to pay and send a receipt.',
              PayStage.receipt => 'Receipt received. Check it in your account, then tap Mark paid.',
              PayStage.issue => 'You told the customer about a problem. Waiting for a new receipt.',
            }, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)),
          ),
        ],
        ...(() {
          final warnings = paymentWarnings(
            o,
            context.watch<AdminSession>().orders,
          );
          if (warnings.isEmpty) return <Widget>[];
          return <Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.pal.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Brand.danger, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: context.pal.red),
                      SizedBox(width: 8),
                      Text(
                        'Check before marking paid',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  for (final w in warnings)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '• ${w.text}',
                        style: const TextStyle(height: 1.35),
                      ),
                    ),
                ],
              ),
            ),
          ];
        })(),
        if (req != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.pal.card,
              border: Border.all(color: Brand.blueDark, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sent to customer${req.sentAt == null ? '' : ' · ${fmt.format(req.sentAt!.toLocal())}'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${req.method.label} · ${req.account}'
                  '${req.accountTitle.isEmpty ? '' : ' (${req.accountTitle})'}'
                  ' · Rs ${req.amount}',
                  style: const TextStyle(height: 1.35),
                ),
              ],
            ),
          ),
        ],
        if (!paid) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
            onPressed: () => _send(context),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(
              req == null
                  ? 'Send payment details to customer'
                  : 'Change / resend payment details',
            ),
          ),
        ],
        if (o.paymentIssue.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.pal.card,
              border: Border.all(color: Brand.danger, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Customer told: ${o.paymentIssue}',
              style: const TextStyle(height: 1.35),
            ),
          ),
        ],
        StreamBuilder<List<PaymentReceipt>>(
          stream: backend.orders.watchReceipts(o.id),
          builder: (context, snap) {
            final list = snap.data ?? const <PaymentReceipt>[];
            if (list.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.length == 1
                        ? 'Receipt from customer'
                        : '${list.length} receipts from customer',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in list) ReceiptImage(r.data, size: 96),
                    ],
                  ),
                  if (!paid) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => _problem(context),
                      icon: const Icon(Icons.report_gmailerrorred_rounded),
                      label: Text(
                        o.paymentIssue.isEmpty
                            ? 'Receipt problem'
                            : 'Change problem note',
                      ),
                    ),
                    if (o.paymentIssue.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            context.read<AdminSession>().setPaymentIssue(o, ''),
                        child: const Text('Clear problem note'),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SendSheet extends StatefulWidget {
  const _SendSheet({required this.order, required this.settings});
  final LpgOrder order;
  final AppSettings settings;

  @override
  State<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<_SendSheet> {
  late PaymentMethod _method;
  final _account = TextEditingController();
  final _title = TextEditingController(text: 'Alpha LPG');
  final _note = TextEditingController();
  late final _amount = TextEditingController(text: '${widget.order.total}');

  static const _methods = [
    PaymentMethod.jazzCash,
    PaymentMethod.easyPaisa,
    PaymentMethod.bankTransfer,
  ];

  @override
  void initState() {
    super.initState();
    final chosen =
        widget.order.paymentRequest?.method ?? widget.order.paymentMethod;
    _method = _methods.contains(chosen) ? chosen : PaymentMethod.jazzCash;
    final r = widget.order.paymentRequest;
    if (r != null) {
      _account.text = r.account;
      _title.text = r.accountTitle;
      _note.text = r.note;
      _amount.text = '${r.amount}';
    } else {
      _account.text = _accountFor(_method, widget.settings);
    }
  }

  @override
  void dispose() {
    _account.dispose();
    _title.dispose();
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _valid =>
      _account.text.trim().isNotEmpty && (int.tryParse(_amount.text) ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final chosen = widget.order.paymentMethod;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Send payment details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.order.customerName} chose ${chosen.label}. '
              'They see this on their order screen.',
              style: TextStyle(color: context.pal.muted),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _methods)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: _method == m,
                    onSelected: (_) => setState(() {
                      _method = m;
                      _account.text = _accountFor(m, widget.settings);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _account,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _method == PaymentMethod.bankTransfer
                    ? 'Account / IBAN'
                    : 'Account number',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Account title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Amount to pay',
                prefixText: 'Rs ',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Message to customer (optional)',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: !_valid
                  ? null
                  : () => Navigator.pop(
                      context,
                      PaymentRequest(
                        method: _method,
                        account: _account.text.trim(),
                        accountTitle: _title.text.trim(),
                        note: _note.text.trim(),
                        amount: int.parse(_amount.text),
                      ),
                    ),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send to customer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProblemSheet extends StatefulWidget {
  const _ProblemSheet();

  @override
  State<_ProblemSheet> createState() => _ProblemSheetState();
}

class _ProblemSheetState extends State<_ProblemSheet> {
  final _c = TextEditingController();
  static const _quick = [
    'The receipt is not clear',
    'We did not receive the money',
    'The amount does not match',
    'This receipt is for another payment',
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'What is wrong with the payment?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in _quick)
                ActionChip(
                  label: Text(q),
                  onPressed: () => setState(() => _c.text = q),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            maxLength: 140,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Message (the customer sees it)',
            ),
          ),
          FilledButton(
            onPressed: _c.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, _c.text.trim()),
            child: const Text('Tell customer'),
          ),
        ],
      ),
    ),
  );
}
