import 'package:alpha_core/alpha_core.dart';
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
                const SizedBox(height: 4),
                _kv(
                  'Payment',
                  '${o.paymentMethod.label} · ${o.paymentStatus.name}',
                ),
              ],
            ),
          ),
        ),
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
        Expanded(child: Text(v, style: style, textAlign: TextAlign.end)),
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
