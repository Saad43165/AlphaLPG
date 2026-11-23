import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/launch.dart';
import '../utils/order_x.dart';
import '../widgets/common.dart';
import '../widgets/job_guide.dart';
import '../widgets/job_map.dart';
import 'chat_screen.dart';
import 'job_actions.dart';

class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({super.key, required this.orderId});
  final String orderId;

  LpgOrder? _find(RiderSession s) {
    for (final list in [s.jobs, s.available, s.history]) {
      for (final o in list) {
        if (o.id == orderId) return o;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RiderSession>();
    final o = _find(s);
    if (o == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'This order is no longer available',
          message: 'Another rider may have taken it, or it was cancelled.',
        ),
      );
    }
    final pal = context.pal;
    final due = o.amountDue;
    final mine = s.jobs.any((j) => j.id == o.id);
    final wa = whatsappNumber(o.customerPhone);
    return Scaffold(
      appBar: AppBar(
        title: Text(o.displayNumber),
        actions: [
          if (mine &&
              (o.status == OrderStatus.assigned ||
                  o.status == OrderStatus.outForDelivery))
            Badge(
              isLabelVisible: s.chat.unread(o.id) > 0,
              label: Text('${s.chat.unread(o.id)}'),
              backgroundColor: Brand.cylinderRed,
              offset: const Offset(-4, 4),
              child: IconButton(
                tooltip: 'Message customer',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => JobChatScreen(order: o),
                  ),
                ),
                icon: const Icon(Icons.forum_rounded),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StatusChip(o.status),
          ),
        ],
      ),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            JobNextStep(order: o, mine: mine),
            JobSchedule(order: o),
            const SizedBox(height: 12),
            if (due > 0 && o.status != OrderStatus.delivered)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF6C23E), Color(0xFFE9A92A)],
                  ),
                  borderRadius: BorderRadius.circular(Brand.radius),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.payments_rounded,
                      color: Brand.navy,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Collect cash at the door',
                        style: TextStyle(
                          color: Brand.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      formatRupees(due),
                      style: const TextStyle(
                        color: Brand.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            const Heading('Deliver to'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: panel(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (o.status == OrderStatus.assigned ||
                      o.status == OrderStatus.outForDelivery ||
                      o.address.hasLocation) ...[
                    JobMap(address: o.address),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        o.address.hasLocation
                            ? Icons.location_on_rounded
                            : Icons.location_on_outlined,
                        color: o.address.hasLocation
                            ? Brand.success
                            : Brand.blueDark,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.address.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              o.address.oneLine,
                              style: const TextStyle(height: 1.35),
                            ),
                            if (!o.address.hasLocation)
                              Text(
                                'No pin on the map: use the address.',
                                style: TextStyle(
                                  color: pal.muted,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => Launch.navigate(
                      lat: o.address.lat,
                      lng: o.address.lng,
                      address: o.address.oneLine,
                    ),
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text('Navigate'),
                  ),
                  if (o.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: pal.tint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.sticky_note_2_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              o.notes,
                              style: const TextStyle(height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Heading('Customer'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: panel(context),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Brand.navy,
                    child: Text(
                      o.customerName.isEmpty
                          ? '?'
                          : o.customerName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          o.businessName.isEmpty
                              ? prettyPhone(o.customerPhone)
                              : '${o.businessName} · ${prettyPhone(o.customerPhone)}',
                          style: TextStyle(color: pal.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (wa != null && o.status.isActive)
                    IconButton.outlined(
                      tooltip: 'WhatsApp customer',
                      onPressed: () => Launch.whatsapp(
                        wa,
                        'Assalam-o-Alaikum, I am your Alpha LPG rider for order ${o.displayNumber}.',
                      ),
                      icon: const WhatsAppIcon(size: 26),
                    ),
                  if (o.status.isActive) ...[
                    const SizedBox(width: 6),
                    IconButton.filled(
                      tooltip: 'Call customer',
                      style: IconButton.styleFrom(
                        backgroundColor: Brand.success,
                      ),
                      onPressed: () => Launch.call(o.customerPhone),
                      icon: const Icon(Icons.call_rounded, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
            const Heading('Cylinders'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: panel(context),
              child: Column(
                children: [
                  for (final i in o.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: pal.tint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${i.quantity}×',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  i.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  i.typeLabel,
                                  style: TextStyle(
                                    color: pal.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (o.emptiesToCollect > 0) ...[
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(
                          Icons.autorenew_rounded,
                          color: Brand.blueDark,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Take back ${o.emptiesToCollect} empty cylinder${o.emptiesToCollect == 1 ? '' : 's'}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Heading('Payment'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: panel(context),
              child: Column(
                children: [
                  _kv('Method', o.paymentMethod.label),
                  _kv('Order total', formatRupees(o.total)),
                  _kv(
                    'Status',
                    o.paymentStatus == PaymentStatus.paid
                        ? (o.paymentMethod.isPrepaid
                              ? 'Paid online: no cash to take'
                              : 'Paid')
                        : (o.paymentMethod.isPrepaid
                              ? 'Not confirmed yet: do not take cash'
                              : 'Take ${formatRupees(o.total)} cash'),
                  ),
                  if (o.paymentReference.isNotEmpty)
                    _kv('Transaction ID', o.paymentReference),
                  if (o.status == OrderStatus.delivered) ...[
                    const Divider(height: 18),
                    _kv('Cash collected', formatRupees(o.cashCollected ?? 0)),
                    _kv('Empties collected', '${o.emptiesCollected ?? 0}'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (mine &&
                (o.status == OrderStatus.assigned ||
                    o.status == OrderStatus.outForDelivery)) ...[
              JobProblem(order: o),
              const SizedBox(height: 10),
              Badge(
                isLabelVisible: s.chat.unread(o.id) > 0,
                label: Text('${s.chat.unread(o.id)}'),
                backgroundColor: Brand.cylinderRed,
                alignment: Alignment.topRight,
                offset: const Offset(-10, -6),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => JobChatScreen(order: o),
                    ),
                  ),
                  icon: const Icon(Icons.forum_rounded),
                  label: Text(
                    s.chat.last(o.id) == null
                        ? 'Message customer'
                        : 'Chat · ${s.chat.last(o.id)!.text}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (mine && o.status == OrderStatus.assigned) ...[
              FilledButton.icon(
                onPressed: () => startDeliveryFlow(context, s, o),
                icon: const Icon(Icons.two_wheeler_rounded),
                label: const Text('Start delivery'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Brand.danger),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Hand this job back?'),
                      content: const Text(
                        'It goes back to Alpha LPG so another rider can take it. Do this only if you cannot deliver it.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Keep the job'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Hand back'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true || !context.mounted) return;
                  final done = await s.release(o);
                  if (!context.mounted) return;
                  if (done) {
                    Navigator.pop(context);
                    showMessage(context, 'Job handed back.');
                  } else {
                    showMessage(
                      context,
                      'Could not hand it back. Check your internet.',
                      error: true,
                    );
                  }
                },
                icon: const Icon(Icons.undo_rounded),
                label: const Text('I cannot do this job'),
              ),
            ],
            if (mine && o.status == OrderStatus.outForDelivery) ...[
              if (o.arrivedAt == null)
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await s.arrived(o);
                    if (context.mounted) {
                      showMessage(
                        context,
                        ok
                            ? 'The customer knows you are at the door.'
                            : 'Could not send. Check your internet.',
                        error: !ok,
                      );
                    }
                  },
                  icon: const Icon(Icons.pin_drop_rounded),
                  label: const Text('I have arrived'),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.pal.card,
                    border: Border.all(color: Brand.success, width: 2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Brand.success),
                      SizedBox(width: 10),
                      Text(
                        'Customer told you are at the door',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              if (o.awaitingOnlinePayment)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.pal.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.pal.warn, width: 2),
                  ),
                  child: Text(
                    'Online payment (${o.paymentMethod.label}) is not confirmed yet. Alpha LPG confirms it, then you can finish. Do not take cash.',
                    style: TextStyle(
                      color: context.pal.ink,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Brand.success),
                onPressed: () async {
                  final ok = await completeDeliveryFlow(context, s, o);
                  if (ok && context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Mark delivered'),
              ),
            ],
            if (!mine && s.available.any((a) => a.id == o.id))
              FilledButton.icon(
                onPressed: () async {
                  final r = await s.accept(o);
                  if (!context.mounted) return;
                  if (r == AcceptResult.ok) {
                    Navigator.pop(context);
                    showMessage(context, 'Job accepted.');
                  } else {
                    showMessage(
                      context,
                      r == AcceptResult.offline
                          ? 'Go online first to accept jobs.'
                          : r == AcceptResult.tooMany
                          ? 'That is more cylinders than your vehicle can carry. Deliver some first.'
                          : 'Could not accept this order.',
                      error: true,
                    );
                  }
                },
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('Accept job'),
              ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: o.displayNumber));
                  showMessage(context, 'Order number copied');
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text('Copy ${o.displayNumber}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            v,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
