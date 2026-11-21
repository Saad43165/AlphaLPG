import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/launch.dart';
import '../utils/order_x.dart';
import '../widgets/common.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    LpgOrder? o;
    for (final x in s.orders) {
      if (x.id == orderId) o = x;
    }
    if (o == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.search_off_rounded, title: 'Order not found'),
      );
    }
    final order = o;
    final fmt = DateFormat('d MMM, h:mm a');
    final wa = whatsappNumber(order.customerPhone);
    return Scaffold(
      appBar: AppBar(title: Text(order.displayNumber)),
      bottomNavigationBar: _Actions(order: order),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                StatusChip(order.status),
                const Spacer(),
                if (order.createdAt != null)
                  Text(
                    'Placed ${fmt.format(order.createdAt!)}',
                    style: TextStyle(color: context.pal.muted, fontSize: 13),
                  ),
              ],
            ),
            const Heading('Customer'),
            _Card(
              children: [
                Text(
                  order.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                if (order.businessName.isNotEmpty) Text(order.businessName),
                const SizedBox(height: 4),
                Text(prettyPhone(order.customerPhone)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Launch.call(order.customerPhone),
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: const Text('Call'),
                    ),
                    if (wa != null)
                      OutlinedButton.icon(
                        onPressed: () => Launch.whatsapp(wa, 'Alpha LPG order ${order.displayNumber}: '),
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: const Text('WhatsApp'),
                      ),
                  ],
                ),
              ],
            ),
            const Heading('Deliver to'),
            _Card(
              children: [
                Text(
                  '${order.address.label.isEmpty ? '' : '${order.address.label} · '}${order.address.oneLine}',
                  style: const TextStyle(height: 1.4),
                ),
                if (order.scheduledFor != null) ...[
                  const SizedBox(height: 8),
                  Pill(Icons.schedule_rounded, 'Scheduled ${fmt.format(order.scheduledFor!)}', color: Brand.blueDark),
                ],
                if (order.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Note: ${order.notes}', style: const TextStyle(fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Launch.navigate(
                    lat: order.address.lat,
                    lng: order.address.lng,
                    address: order.address.oneLine,
                  ),
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: Text(order.address.hasLocation ? 'Open pin in Maps' : 'Search address in Maps'),
                ),
              ],
            ),
            const Heading('Items'),
            _Card(
              children: [
                for (final i in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${i.quantity}× ${i.name}\n${i.type.label}',
                              style: const TextStyle(height: 1.3)),
                        ),
                        Text(rs(i.lineTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                const Divider(height: 22),
                _Line('Subtotal', rs(order.subtotal)),
                _Line('Delivery', order.deliveryFee == 0 ? 'Free' : rs(order.deliveryFee)),
                _Line('Total', rs(order.total), bold: true),
                const SizedBox(height: 6),
                Text(
                  'Collect ${order.emptiesToCollect} empty cylinder${order.emptiesToCollect == 1 ? '' : 's'} on delivery.',
                  style: TextStyle(color: context.pal.muted, fontSize: 13),
                ),
              ],
            ),
            const Heading('Payment'),
            _Card(
              children: [
                _Line('Method', order.paymentMethod.label),
                _Line(
                  'Status',
                  order.paymentStatus == PaymentStatus.paid ? 'Paid' : 'Not paid yet',
                  bold: true,
                ),
                if (order.paymentReference.isNotEmpty)
                  _Line('Transaction ID', order.paymentReference),
                if (order.cashCollected != null)
                  _Line('Cash taken by rider', rs(order.cashCollected!)),
                if (order.emptiesCollected != null)
                  _Line('Empties returned', '${order.emptiesCollected}'),
                if (order.awaitingPaymentCheck)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      order.paymentReference.isEmpty
                          ? 'The customer has not sent a transaction ID yet. Check your ${order.paymentMethod.label} account before marking paid.'
                          : 'Check this transaction ID in your ${order.paymentMethod.label} account, then mark it paid.',
                      style: const TextStyle(color: Color(0xFF8A6D00), height: 1.35),
                    ),
                  ),
              ],
            ),
            if (order.riderName != null) ...[
              const Heading('Rider'),
              _Card(
                children: [
                  Text(order.riderName!, style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (order.riderPhone != null) Text(prettyPhone(order.riderPhone!)),
                  if (order.riderPhone != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => Launch.call(order.riderPhone!),
                        icon: const Icon(Icons.call_rounded, size: 18),
                        label: const Text('Call rider'),
                      ),
                    ),
                  if (order.status == OrderStatus.outForDelivery)
                    _LiveRider(orderId: order.id),
                ],
              ),
            ],
            if (order.rating != null) ...[
              const Heading('Customer rating'),
              _Card(
                children: [
                  Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(
                          i <= order.rating! ? Icons.star_rounded : Icons.star_border_rounded,
                          color: Brand.flame,
                        ),
                    ],
                  ),
                  if (order.feedback.isNotEmpty) Text(order.feedback),
                ],
              ),
            ],
            const Heading('History'),
            _Card(
              children: [
                for (final e in order.history)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.note.isEmpty ? e.status.label : '${e.status.label} · ${e.note}',
                          ),
                        ),
                        Text(fmt.format(e.at), style: TextStyle(color: context.pal.muted, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: panel(context),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.k, this.v, {this.bold = false});
  final String k, v;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text(k, style: TextStyle(color: context.pal.muted)),
        const Spacer(),
        Flexible(
          child: Text(
            v,
            textAlign: TextAlign.end,
            style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// Where the rider is right now (opens in Google Maps).
class _LiveRider extends StatelessWidget {
  const _LiveRider({required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AdminSession>().backend.orders;
    return StreamBuilder<RiderLocation?>(
      stream: repo.watchRiderLocation(orderId),
      builder: (context, snap) {
        final l = snap.data;
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: l == null
              ? Text('Waiting for the rider\'s first location…',
                  style: TextStyle(color: context.pal.muted))
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.isFresh()
                            ? 'Live · ${l.speedKmh.round()} km/h · ${timeAgo(l.updatedAt)}'
                            : 'Last seen ${timeAgo(l.updatedAt)}',
                        style: TextStyle(
                          color: l.isFresh() ? Brand.success : Brand.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => Launch.navigate(lat: l.lat, lng: l.lng),
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: const Text('See on map'),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// The buttons that move the order forward.
class _Actions extends StatefulWidget {
  const _Actions({required this.order});
  final LpgOrder order;

  @override
  State<_Actions> createState() => _ActionsState();
}

class _ActionsState extends State<_Actions> {
  bool _busy = false;

  Future<void> _do(Future<String?> Function() job, String done) async {
    setState(() => _busy = true);
    final err = await job();
    if (!mounted) return;
    setState(() => _busy = false);
    showMessage(context, err ?? done, error: err != null);
  }

  Future<void> _assign() async {
    final s = context.read<AdminSession>();
    final r = await showModalBottomSheet<RiderProfile>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _RiderPicker(riders: s.riders, current: widget.order.riderId),
    );
    if (r != null) {
      await _do(() => s.assign(widget.order, r), 'Assigned to ${r.name}');
    }
  }

  Future<void> _cancel() async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: TextField(
          controller: c,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Reason (the customer will see it)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep order')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Brand.danger),
            onPressed: () => Navigator.pop(ctx, c.text.trim().isEmpty ? 'Cancelled by Alpha LPG' : c.text.trim()),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    c.dispose();
    if (reason != null && mounted) {
      await _do(() => context.read<AdminSession>().cancel(widget.order, reason), 'Order cancelled');
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final s = context.read<AdminSession>();
    final buttons = <Widget>[];
    if (o.status == OrderStatus.placed) {
      buttons.add(FilledButton.icon(
        onPressed: _busy ? null : () => _do(() => s.confirm(o), 'Order confirmed'),
        icon: const Icon(Icons.check_rounded),
        label: const Text('Confirm order'),
      ));
    }
    if (o.status == OrderStatus.placed ||
        o.status == OrderStatus.confirmed ||
        o.status == OrderStatus.assigned) {
      buttons.add(FilledButton.tonalIcon(
        onPressed: _busy ? null : _assign,
        icon: const Icon(Icons.two_wheeler),
        label: Text(o.riderId == null ? 'Assign rider' : 'Change rider'),
      ));
    }
    if (o.awaitingPaymentCheck || (o.paymentStatus == PaymentStatus.pending && o.status == OrderStatus.delivered)) {
      buttons.add(FilledButton.tonalIcon(
        onPressed: _busy ? null : () => _do(() => s.markPaid(o), 'Marked as paid'),
        icon: const Icon(Icons.verified_rounded),
        label: const Text('Mark paid'),
      ));
    }
    if (o.status == OrderStatus.assigned || o.status == OrderStatus.outForDelivery) {
      buttons.add(OutlinedButton(
        onPressed: _busy ? null : () => _do(() => s.markDelivered(o), 'Marked delivered'),
        child: const Text('Mark delivered'),
      ));
    }
    if (o.status.isActive) {
      buttons.add(TextButton(
        onPressed: _busy ? null : _cancel,
        style: TextButton.styleFrom(foregroundColor: Brand.danger),
        child: const Text('Cancel order'),
      ));
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: context.pal.card,
          border: Border(top: BorderSide(color: context.pal.line)),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: buttons,
        ),
      ),
    );
  }
}

class _RiderPicker extends StatelessWidget {
  const _RiderPicker({required this.riders, this.current});
  final List<RiderProfile> riders;
  final String? current;

  @override
  Widget build(BuildContext context) {
    final list = [
      for (final r in riders)
        if (r.active) r,
    ]..sort((a, b) => (b.online ? 1 : 0).compareTo(a.online ? 1 : 0));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: list.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No riders yet. Add one in the Riders tab.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text('Choose a rider', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  ),
                  for (final r in list)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (r.online ? Brand.success : Colors.grey).withValues(alpha: 0.15),
                        child: Icon(Icons.two_wheeler, color: r.online ? Brand.success : Colors.grey),
                      ),
                      title: Text(r.name),
                      subtitle: Text(r.online ? 'Online · ${r.vehicle}' : 'Offline · ${r.vehicle}'),
                      trailing: r.uid == current ? const Icon(Icons.check_rounded) : null,
                      onTap: () => Navigator.pop(context, r),
                    ),
                ],
              ),
      ),
    );
  }
}
