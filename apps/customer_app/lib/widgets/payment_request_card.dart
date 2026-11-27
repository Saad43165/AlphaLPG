import 'package:alpha_core/alpha_core.dart';

import '../l10n/lang.dart';

import 'package:alpha_ui/alpha_ui.dart' as ui;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart' hide Text;

import '../l10n/text.dart';

import 'package:provider/provider.dart';

import '../services/backend.dart';
import '../theme/brand.dart';
import '../utils/launch.dart';
import 'common.dart';
import 'payment.dart';

/// "Alpha LPG sent you payment details": the account to pay, with copy and
/// open-app buttons, so the customer never has to dig through chat.
class PaymentRequestCard extends StatelessWidget {
  const PaymentRequestCard(this.request, {super.key});
  final PaymentRequest request;

  void _copy(BuildContext context, String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    showMessage(context, '$what copied');
  }

  @override
  Widget build(BuildContext context) {
    final m = request.method;
    final pal = context.pal;
    Widget line(String label, String value, {bool copy = false}) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: pal.muted, fontSize: 12)),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          if (copy)
            IconButton.filledTonal(
              tooltip: tr('Copy $label'),
              onPressed: () => _copy(context, value, label),
              icon: const Icon(Icons.copy_rounded, size: 18),
            ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.pal.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.pal.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PaymentLogo(m, width: 52, height: 36),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Alpha LPG sent you payment details',
                  style: TextStyle(fontWeight: FontWeight.w800, height: 1.25),
                ),
              ),
            ],
          ),
          line('Pay with', m.label),
          line('Amount', formatRupees(request.amount), copy: false),
          if (request.account.isNotEmpty)
            line(
              m == PaymentMethod.bankTransfer
                  ? 'Account / IBAN'
                  : 'Account number',
              request.account,
              copy: true,
            ),
          if (request.accountTitle.isNotEmpty)
            line('Account title', request.accountTitle),
          if (request.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(request.note, style: const TextStyle(height: 1.4)),
          ],
          if (m.appId != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: () => Launch.store(m.appId!),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text('Open ${m.label}'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Receipts the customer already sent, plus the button to send payment
/// details (transaction ID and amount are required, a picture is optional).
class ReceiptSection extends StatelessWidget {
  const ReceiptSection(this.order, {super.key});
  final LpgOrder order;

  Future<void> _open(BuildContext context) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PaySheet(order: order),
    );
    if (done == true && context.mounted) {
      showMessage(
        context,
        'Sent. Alpha LPG will check and confirm your payment.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    final backend = context.read<Backend>();
    final pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (o.paymentIssue.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.pal.card,
              border: Border.all(color: Brand.danger, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, color: context.pal.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Alpha LPG could not confirm your payment: ${o.paymentIssue}. Please send the details again.',
                    style: const TextStyle(height: 1.4, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),
        if (o.paymentReference.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'You sent: transaction ${o.paymentReference}'
              '${o.paidAmount == null ? '' : ' · ${formatRupees(o.paidAmount!)}'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        StreamBuilder<List<PaymentReceipt>>(
          stream: backend.orders.watchReceipts(o.id),
          builder: (context, snap) {
            final list = snap.data ?? const <PaymentReceipt>[];
            if (list.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Receipt pictures you sent',
                    style: TextStyle(color: pal.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final r in list) ui.ReceiptImage(r.data)],
                  ),
                ],
              ),
            );
          },
        ),
        FilledButton.icon(
          onPressed: () => _open(context),
          icon: const Icon(Icons.upload_file_rounded),
          label: Text(
            o.receiptAt == null
                ? 'I have paid: send details'
                : 'Send details again',
          ),
        ),
      ],
    );
  }
}

class _PaySheet extends StatefulWidget {
  const _PaySheet({required this.order});
  final LpgOrder order;

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  late final _ref = TextEditingController(text: widget.order.paymentReference);
  late final _amount = TextEditingController(
    text:
        '${widget.order.paidAmount ?? widget.order.paymentRequest?.amount ?? widget.order.total}',
  );
  String? _data;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ref.dispose();
    _amount.dispose();
    super.dispose();
  }

  int get _due => widget.order.paymentRequest?.amount ?? widget.order.total;

  /// Screenshot, transaction ID and amount are all required.
  bool get _valid =>
      _data != null &&
      _ref.text.trim().length >= 4 &&
      (int.tryParse(_amount.text.trim()) ?? 0) > 0;

  String get _missing => _data == null
      ? 'Add the payment screenshot'
      : _ref.text.trim().length < 4
      ? 'Enter the transaction ID'
      : (int.tryParse(_amount.text.trim()) ?? 0) <= 0
      ? 'Enter the amount you sent'
      : 'Send to Alpha LPG';

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2200,
        imageQuality: 90,
      );
      if (file == null) return;
      setState(() => _busy = true);
      final data = await ui.compressReceiptPhoto(await file.readAsBytes());
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is String ? e : 'Could not use that picture.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final backend = context.read<Backend>();
    final o = widget.order;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await backend.orders.submitPayment(
        o.id,
        uid: o.customerId,
        reference: _ref.text.trim(),
        amount: int.parse(_amount.text.trim()),
        data: _data,
      );
      // A chat line too, so the shop is alerted and sees it in the thread.
      try {
        await backend.orders.sendMessage(
          o.id,
          uid: o.customerId,
          role: MessageRole.customer,
          name: 'Customer',
          text:
              '📎 I paid ${formatRupees(int.parse(_amount.text.trim()))} via ${o.paymentMethod.label}. Transaction ID: ${_ref.text.trim()}.',
        );
      } catch (_) {}
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
    final pal = context.pal;
    final o = widget.order;
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
              'Send your payment details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Order ${o.displayNumber} · ${o.paymentMethod.label}. '
              'Three quick things so we can confirm it safely: the screenshot, the transaction ID and the amount.',
              style: TextStyle(color: pal.muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            // 1. Screenshot (required).
            if (_data != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.pal.card,
                  border: Border.all(color: Brand.success, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    ui.ReceiptImage(_data!, size: 72),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Screenshot added',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _data = null),
                      child: const Text('Change'),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: context.pal.card,
                  border: Border.all(color: Brand.blueDark, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '1. Screenshot of the payment (required)',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 46),
                            ),
                            onPressed: _busy
                                ? null
                                : () => _pick(ImageSource.gallery),
                            icon: const Icon(
                              Icons.photo_library_rounded,
                              size: 18,
                            ),
                            label: const Text('Gallery'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 46),
                            ),
                            onPressed: _busy
                                ? null
                                : () => _pick(ImageSource.camera),
                            icon: const Icon(
                              Icons.photo_camera_rounded,
                              size: 18,
                            ),
                            label: const Text('Camera'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            const Text(
              '2. From your receipt',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ref,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: tr('Transaction ID (required)'),
                prefixIcon: Icon(Icons.tag_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: tr('Amount you sent (required)'),
                prefixText: tr('Rs '),
                prefixIcon: Icon(Icons.payments_rounded),
              ),
            ),
            const SizedBox(height: 12),
            if ((int.tryParse(_amount.text.trim()) ?? 0) > 0 &&
                int.parse(_amount.text.trim()) != _due)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'You need to pay ${formatRupees(_due)}. If you sent a different amount, Alpha LPG will contact you.',
                  style: TextStyle(
                    color: context.pal.warn,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: TextStyle(color: context.pal.red)),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: (_valid && !_busy) ? _submit : null,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_busy ? 'Please wait…' : _missing),
            ),
          ],
        ),
      ),
    );
  }
}
