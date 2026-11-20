import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../state/cart.dart';
import '../../theme/brand.dart';
import '../../utils/format.dart';
import '../../utils/launch.dart';
import '../../widgets/common.dart';
import '../../widgets/live.dart';
import '../../widgets/payment.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    return Live<LpgOrder?>(
      cacheKey: orderId,
      stream: () => backend.orders.watchOrder(orderId),
      builder: (context, snap) {
        final o = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(o == null ? 'Order' : 'Order ${o.displayNumber}'),
            actions: [
              if (o != null && o.status != OrderStatus.cancelled)
                TextButton.icon(
                  onPressed: () => context.push('/invoice', extra: o),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Invoice'),
                ),
            ],
          ),
          body: switch (snap) {
            AsyncSnapshot(hasError: true) => EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load this order',
              message: '${snap.error}',
            ),
            AsyncSnapshot(connectionState: ConnectionState.waiting) =>
              const Center(child: CircularProgressIndicator()),
            _ when o == null => const EmptyState(
              icon: Icons.search_off,
              title: 'Order not found',
            ),
            _ => Constrained(child: _OrderBody(o)),
          },
        );
      },
    );
  }
}

class _OrderBody extends StatelessWidget {
  const _OrderBody(this.o);
  final LpgOrder o;

  Future<void> _cancel(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelDialog(),
    );
    if (reason == null || !context.mounted) return;
    try {
      await context.read<Backend>().orders.cancelByCustomer(o, reason);
      if (context.mounted) showMessage(context, 'Order cancelled');
    } catch (e) {
      if (context.mounted) {
        showMessage(
          context,
          'Could not cancel — it may already be confirmed. Please call us.',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusHeader(o),
        const SizedBox(height: 12),
        if (o.canBeRated) ...[_RateCard(o), const SizedBox(height: 12)],
        if (o.rating != null) ...[_RatedCard(o), const SizedBox(height: 12)],
        if (o.status != OrderStatus.cancelled) _Timeline(o),
        if (o.riderName != null && o.status.isActive) ...[
          const SectionTitle('Your rider'),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Brand.navy,
                child: Icon(Icons.two_wheeler, color: Colors.white),
              ),
              title: Text(o.riderName!),
              subtitle: const Text('Alpha LPG delivery rider'),
              trailing: o.riderPhone == null
                  ? null
                  : IconButton.filled(
                      tooltip: 'Call rider',
                      style: IconButton.styleFrom(
                        backgroundColor: Brand.success,
                      ),
                      onPressed: () => Launch.call(o.riderPhone!),
                      icon: const Icon(Icons.call, color: Colors.white),
                    ),
            ),
          ),
        ],
        const SectionTitle('Items'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final i in o.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${i.quantity} × ${i.name}\n${i.type.label} · ${formatRupees(i.unitPrice)} each',
                          ),
                        ),
                        Text(
                          formatRupees(i.lineTotal),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 20),
                _kv('Subtotal', formatRupees(o.subtotal)),
                _kv(
                  'Delivery',
                  o.deliveryFee == 0 ? 'FREE' : formatRupees(o.deliveryFee),
                ),
                const SizedBox(height: 4),
                _kv('Total', formatRupees(o.total), bold: true),
              ],
            ),
          ),
        ),
        const SectionTitle('Payment'),
        _PaymentCard(o),
        const SectionTitle('Delivery'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(o.address.label),
                subtitle: Text(o.address.oneLine),
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(
                  o.scheduledFor == null
                      ? 'As soon as possible'
                      : formatDay(o.scheduledFor!),
                ),
                subtitle: o.notes.isEmpty ? null : Text(o.notes),
              ),
              if (o.emptiesToCollect > 0)
                ListTile(
                  leading: const Icon(Icons.autorenew),
                  title: Text(
                    'Keep ${o.emptiesToCollect} empty cylinder${o.emptiesToCollect == 1 ? '' : 's'} ready',
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (o.status.customerCanCancel)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB3261E),
            ),
            onPressed: () => _cancel(context),
            icon: const Icon(Icons.close),
            label: const Text('Cancel order'),
          ),
        if (!o.status.isActive)
          FilledButton.icon(
            onPressed: () {
              context.read<Cart>().reorder(o);
              context.push('/cart');
            },
            icon: const Icon(Icons.replay),
            label: const Text('Order again'),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Launch.whatsapp(
            settings.whatsapp,
            'Hi Alpha LPG, I have a question about order ${o.displayNumber}.',
          ),
          icon: const Icon(Icons.chat, color: Brand.whatsapp),
          label: const Text('Help with this order'),
        ),
        const SizedBox(height: 8),
        if (o.createdAt != null)
          Text(
            'Placed ${formatDateTime(o.createdAt!)}',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
      ],
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
      fontSize: bold ? 17 : 14,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: style),
        const SizedBox(width: 12),
        Expanded(
          child: Text(v, style: style, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader(this.o);
  final LpgOrder o;

  @override
  Widget build(BuildContext context) {
    final c = StatusPill.colorOf(o.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            switch (o.status) {
              OrderStatus.delivered => Icons.check_circle,
              OrderStatus.cancelled => Icons.cancel,
              OrderStatus.outForDelivery => Icons.two_wheeler,
              _ => Icons.local_fire_department,
            },
            color: c,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.status.label,
                  style: TextStyle(
                    color: c,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                Text(
                  o.status == OrderStatus.cancelled && o.cancelReason.isNotEmpty
                      ? 'Reason: ${o.cancelReason}'
                      : o.status.description,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline(this.o);
  final LpgOrder o;

  @override
  Widget build(BuildContext context) {
    final current = OrderStatus.journey.indexOf(o.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            for (var i = 0; i < OrderStatus.journey.length; i++)
              _TimelineRow(
                status: OrderStatus.journey[i],
                done: i <= current,
                isCurrent: i == current,
                isLast: i == OrderStatus.journey.length - 1,
                at: o.timeOf(OrderStatus.journey[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.status,
    required this.done,
    required this.isCurrent,
    required this.isLast,
    this.at,
  });

  final OrderStatus status;
  final bool done;
  final bool isCurrent;
  final bool isLast;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final color = done ? Brand.blueDark : const Color(0xFFCBD6E2);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: done ? color : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.label,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                      color: done ? Brand.navy : Colors.black38,
                    ),
                  ),
                  if (at != null)
                    Text(
                      formatTime(at!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  static const _reasons = [
    'Ordered by mistake',
    'Need a different size',
    'Found gas elsewhere',
    'Delivery time too late',
    'Other',
  ];
  String _reason = _reasons.first;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cancel this order?'),
    content: RadioGroup<String>(
      groupValue: _reason,
      onChanged: (v) => setState(() => _reason = v!),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in _reasons)
            RadioListTile<String>(
              value: r,
              title: Text(r),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => context.pop(),
        child: const Text('Keep order'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFB3261E),
          minimumSize: const Size(0, 44),
        ),
        onPressed: () => context.pop(_reason),
        child: const Text('Cancel order'),
      ),
    ],
  );
}

class _RateCard extends StatefulWidget {
  const _RateCard(this.o);
  final LpgOrder o;

  @override
  State<_RateCard> createState() => _RateCardState();
}

class _RateCardState extends State<_RateCard> {
  int _stars = 0;
  final _comment = TextEditingController();
  bool _sending = false;

  static const _labels = [
    '',
    'Poor',
    'Not great',
    'Okay',
    'Good',
    'Excellent!',
  ];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await context.read<Backend>().orders.rate(
        widget.o.id,
        _stars,
        _comment.text.trim(),
      );
      if (mounted) showMessage(context, 'Thank you for your feedback!');
    } catch (e) {
      if (mounted) showMessage(context, 'Could not send rating', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(Brand.radius),
      boxShadow: Brand.shadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How was your delivery?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                tooltip: '$i star${i == 1 ? '' : 's'}',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _stars = i);
                },
                icon: Icon(
                  i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: i <= _stars ? Brand.flame : Brand.muted,
                  size: 34,
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _labels[_stars],
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (_stars > 0) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Anything we should know? (optional)',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _sending ? null : _send,
            child: const Text('Submit rating'),
          ),
        ],
      ],
    ),
  );
}

class _RatedCard extends StatelessWidget {
  const _RatedCard(this.o);
  final LpgOrder o;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Brand.flame.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(Brand.radius),
    ),
    child: Row(
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= o.rating! ? Icons.star_rounded : Icons.star_outline_rounded,
            color: Brand.warning,
            size: 22,
          ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Thanks for rating this delivery',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard(this.o);
  final LpgOrder o;

  Future<void> _addReference(BuildContext context) async {
    final controller = TextEditingController(text: o.paymentReference);
    final ref = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Transaction ID'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'From your ${o.paymentMethod.label} receipt',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ref == null || ref.trim().isEmpty || !context.mounted) return;
    try {
      await context.read<Backend>().orders.submitPaymentReference(o.id, ref);
      if (context.mounted) {
        showMessage(context, 'Transaction ID saved. We will confirm shortly.');
      }
    } catch (_) {
      if (context.mounted) {
        showMessage(
          context,
          'Could not save. Please send it on WhatsApp.',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final paid = o.paymentStatus == PaymentStatus.paid;
    final needsTransfer =
        o.paymentMethod.isPrepaid && !paid && o.status != OrderStatus.cancelled;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Brand.radius),
        boxShadow: Brand.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: o.paymentMethod.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(o.paymentMethod.icon, color: o.paymentMethod.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.paymentMethod.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      formatRupees(o.total),
                      style: const TextStyle(color: Brand.muted),
                    ),
                  ],
                ),
              ),
              Tag(
                paid
                    ? 'PAID'
                    : (o.paymentMethod.isPrepaid
                          ? 'AWAITING PAYMENT'
                          : 'PAY ON DELIVERY'),
                color: paid ? Brand.success : Brand.flame,
                dark: !paid,
              ),
            ],
          ),
          if (o.paymentReference.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Transaction ID: ${o.paymentReference}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          if (needsTransfer) ...[
            const SizedBox(height: 12),
            if (o.paymentReference.isEmpty)
              PaymentInstructions(
                method: o.paymentMethod,
                settings: settings,
                total: o.total,
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _addReference(context),
              icon: const Icon(Icons.tag_rounded),
              label: Text(
                o.paymentReference.isEmpty
                    ? 'Add transaction ID'
                    : 'Change transaction ID',
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (o.status != OrderStatus.cancelled)
            TextButton.icon(
              onPressed: () => context.push('/invoice', extra: o),
              icon: const Icon(Icons.download_rounded),
              label: const Text('View / share invoice (PDF)'),
            ),
        ],
      ),
    );
  }
}
