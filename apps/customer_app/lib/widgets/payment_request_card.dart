import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart' as ui;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
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
              tooltip: 'Copy $label',
              onPressed: () => _copy(context, value, label),
              icon: const Icon(Icons.copy_rounded, size: 18),
            ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: m.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: m.color.withValues(alpha: 0.5)),
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

/// Receipts the customer already sent, plus the button to add another.
class ReceiptSection extends StatefulWidget {
  const ReceiptSection(this.order, {super.key});
  final LpgOrder order;

  @override
  State<ReceiptSection> createState() => _ReceiptSectionState();
}

class _ReceiptSectionState extends State<ReceiptSection> {
  bool _busy = false;

  Future<void> _add(ImageSource source) async {
    final backend = context.read<Backend>();
    final messenger = context;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2200,
        imageQuality: 90,
      );
      if (file == null) return;
      setState(() => _busy = true);
      final data = await ui.compressReceiptPhoto(await file.readAsBytes());
      await backend.orders.addReceipt(
        widget.order.id,
        uid: widget.order.customerId,
        data: data,
      );
      if (messenger.mounted) {
        showMessage(messenger, 'Receipt sent. We will confirm your payment.');
      }
    } catch (e) {
      if (messenger.mounted) {
        showMessage(
          messenger,
          e is String ? e : 'Could not send the receipt. Check your internet and try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _choose() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose a screenshot'),
              onTap: () {
                Navigator.pop(c);
                _add(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(c);
                _add(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
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
              color: Brand.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, color: Brand.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Alpha LPG could not confirm your payment: ${o.paymentIssue}. Please send a new receipt.',
                    style: const TextStyle(height: 1.4, fontSize: 13.5),
                  ),
                ),
              ],
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
                    'Receipts you sent',
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
          onPressed: _busy ? null : _choose,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_rounded),
          label: Text(
            _busy
                ? 'Sending…'
                : (o.receiptAt == null
                      ? 'Add payment receipt'
                      : 'Add another receipt'),
          ),
        ),
      ],
    );
  }
}
