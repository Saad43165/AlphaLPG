import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/launch.dart';
import '../utils/order_x.dart';
import '../utils/payment_checks.dart';
import '../widgets/common.dart';
import '../widgets/schedule.dart';
import '../widgets/payment_panel.dart';
import 'chat_screen.dart';
import 'reports_inbox_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    LpgOrder? found;
    for (final x in s.orders) {
      if (x.id == orderId) found = x;
    }
    if (found == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Order not found',
        ),
      );
    }
    final o = found;
    final fmt = DateFormat('d MMM, h:mm a');
    final pal = context.pal;
    final wa = whatsappNumber(o.customerPhone);
    final initials = o.customerName
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final paid = o.paymentStatus == PaymentStatus.paid;
    return Scaffold(
      appBar: AppBar(
        title: Text(o.displayNumber),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StatusChip(o.status),
          ),
        ],
      ),
      bottomNavigationBar: _Actions(order: o),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            // ---- What to do now, and how far along the order is ----------------
            ScheduleBanner(o),
            _NextStep(order: o),
            _Progress(order: o),

            // ---- First order from this customer ----------------------------
            if (s.isNewCustomer(o))
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.pal.card,
                  border: Border.all(color: Brand.blueDark, width: 2),
                  borderRadius: BorderRadius.circular(Brand.radius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New customer: call to confirm',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'This is their first order. Phone numbers are not verified by SMS, '
                      'so call once to confirm the person and the address before sending a rider. '
                      'After their first delivery this reminder goes away.',
                      style: TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: () => Launch.call(o.customerPhone),
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: Text('Call ${prettyPhone(o.customerPhone)}'),
                    ),
                  ],
                ),
              ),

            // ---- Customer reports on this order ----------------------------
            for (final r in s.reports.where((x) => x.orderId == o.id))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ReportCard(r, showOrderLink: false),
              ),

            // ---- Summary: the amount, front and centre -----------------------
            _Section(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ORDER TOTAL',
                            style: TextStyle(
                              color: pal.muted,
                              fontSize: 11.5,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rs(o.total),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Pill(
                      paid
                          ? Icons.check_circle_rounded
                          : Icons.hourglass_top_rounded,
                      paid ? 'Paid' : 'Not paid yet',
                      color: paid ? Brand.success : Brand.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Mini(Icons.propane_tank_rounded, o.itemsCountLabel),
                    const SizedBox(width: 8),
                    _Mini(Icons.payments_rounded, o.paymentMethod.label),
                    const SizedBox(width: 8),
                    _Mini(
                      Icons.schedule_rounded,
                      o.scheduledFor != null
                          ? DateFormat('d MMM, h a').format(o.scheduledFor!)
                          : 'As soon as possible',
                    ),
                  ],
                ),
                if (o.createdAt != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Placed ${fmt.format(o.createdAt!)}',
                    style: TextStyle(color: pal.muted, fontSize: 12.5),
                  ),
                ],
              ],
            ),

            // ---- Customer ----------------------------------------------------
            _Section(
              title: 'Customer',
              icon: Icons.person_rounded,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Brand.navy,
                      child: Text(
                        initials.isEmpty ? '?' : initials,
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          if (o.businessName.isNotEmpty)
                            Text(
                              o.businessName,
                              style: TextStyle(color: pal.muted),
                            ),
                          Text(
                            prettyPhone(o.customerPhone),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _Act(
                        Icons.call_rounded,
                        'Call',
                        () => Launch.call(o.customerPhone),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Act(
                        Icons.chat_rounded,
                        'WhatsApp',
                        wa == null
                            ? null
                            : () => Launch.whatsapp(
                                wa,
                                'Alpha LPG order ${o.displayNumber}: ',
                              ),
                        iconWidget: const WhatsAppIcon(size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (o.status.isActive)
                      Expanded(
                        child: _Act(
                          Icons.forum_rounded,
                          s.chat.unread(o.id) > 0
                              ? 'Chat (${s.chat.unread(o.id)})'
                              : 'Chat',
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => OrderChatScreen(order: o),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // ---- Delivery address -----------------------------------------
            _Section(
              title: 'Deliver to',
              icon: Icons.location_on_rounded,
              children: [
                if (o.address.label.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      o.address.label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                Text(o.address.oneLine, style: const TextStyle(height: 1.4)),
                if (o.customerNotes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: pal.tint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      o.customerNotes,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _Act(
                  Icons.map_rounded,
                  o.address.hasLocation
                      ? 'Open pin in Google Maps'
                      : 'Search address in Google Maps',
                  () => Launch.navigate(
                    lat: o.address.lat,
                    lng: o.address.lng,
                    address: o.address.oneLine,
                  ),
                ),
              ],
            ),

            // ---- Items and money --------------------------------------------
            _Section(
              title: 'Items',
              icon: Icons.receipt_long_rounded,
              children: [
                for (final i in o.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: pal.tint,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${i.quantity}×',
                            style: const TextStyle(fontWeight: FontWeight.w800),
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
                                '${i.typeLabel} · ${rs(i.unitPrice)} each',
                                style: TextStyle(
                                  color: pal.muted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          rs(i.lineTotal),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                Divider(height: 24, color: pal.line),
                _KV('Subtotal', rs(o.subtotal)),
                _KV(
                  'Delivery fee',
                  o.deliveryFee == 0 ? 'Free' : rs(o.deliveryFee),
                ),
                _KV('Total', rs(o.total), big: true),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: pal.tint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.recycling_rounded, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Rider collects ${o.emptiesToCollect} empty cylinder${o.emptiesToCollect == 1 ? '' : 's'}.',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ---- Payment ----------------------------------------------------
            _Section(
              title: 'Payment',
              icon: Icons.account_balance_wallet_rounded,
              children: [
                _KV('Method', o.paymentMethod.label),
                _KV(
                  'Status',
                  paid ? 'Paid' : 'Not paid yet',
                  valueColor: paid ? Brand.success : Brand.warning,
                ),
                if (o.paymentReference.isNotEmpty)
                  _KV(
                    'Transaction ID',
                    o.paymentReference,
                    onCopy: () {
                      Clipboard.setData(
                        ClipboardData(text: o.paymentReference),
                      );
                      showMessage(context, 'Transaction ID copied');
                    },
                  ),
                if (o.cashCollected != null)
                  _KV('Cash taken by rider', rs(o.cashCollected!)),
                if (o.emptiesCollected != null)
                  _KV('Empties returned', '${o.emptiesCollected}'),
                if (o.awaitingPaymentCheck) ...[
                  const SizedBox(height: 10),
                  _Note(
                    o.paymentReference.isEmpty
                        ? 'No transaction ID yet. Check your ${o.paymentMethod.label} account before marking this paid.'
                        : 'Check this transaction ID in your ${o.paymentMethod.label} account, then tap Mark paid.',
                  ),
                ],
                PaymentPanel(o),
              ],
            ),

            // ---- Delivery photo ---------------------------------------------
            if (o.status == OrderStatus.delivered)
              StreamBuilder<List<PaymentReceipt>>(
                stream: s.backend.orders.watchDeliveryProofs(o.id),
                builder: (context, snap) {
                  final list = snap.data ?? const <PaymentReceipt>[];
                  return _Section(
                    title: 'Delivery photo',
                    icon: Icons.photo_camera_rounded,
                    children: [
                      if (list.isEmpty)
                        const Text('The rider did not take a delivery photo.')
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final p in list)
                              ReceiptImage(p.data, size: 110),
                          ],
                        ),
                    ],
                  );
                },
              ),

            // ---- Rider ------------------------------------------------------
            if (o.riderName != null)
              _Section(
                title: 'Rider',
                icon: Icons.two_wheeler_rounded,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Brand.blueDark,
                        child: Icon(Icons.two_wheeler, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.riderName!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            if (o.riderPhone != null)
                              Text(prettyPhone(o.riderPhone!)),
                          ],
                        ),
                      ),
                      if (o.riderPhone != null)
                        IconButton.filledTonal(
                          tooltip: 'Call rider',
                          onPressed: () => Launch.call(o.riderPhone!),
                          icon: const Icon(Icons.call_rounded),
                        ),
                    ],
                  ),
                  if (o.arrivedAt != null) ...[
                    const SizedBox(height: 10),
                    Pill(
                      Icons.pin_drop_rounded,
                      'Arrived at the door ${fmt.format(o.arrivedAt!)}',
                      color: Brand.success,
                    ),
                  ],
                  if (o.status == OrderStatus.outForDelivery)
                    _LiveRider(orderId: o.id),
                ],
              ),

            if (o.rating != null)
              _Section(
                title: 'Customer rating',
                icon: Icons.star_rounded,
                children: [
                  Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(
                          i <= o.rating!
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: context.pal.warn,
                          size: 26,
                        ),
                    ],
                  ),
                  if (o.feedback.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(o.feedback),
                  ],
                ],
              ),

            // ---- Timeline (collapsed: it is long) ----------------------------
            Container(
              margin: const EdgeInsets.only(top: 12),
              decoration: panel(context),
              child: Material(
                type: MaterialType.transparency,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: context.pal.card,
                        border: Border.all(color: Brand.blueDark, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.timeline_rounded,
                        size: 18,
                        color: Brand.blueDark,
                      ),
                    ),
                    title: const Text(
                      'History',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text('${o.history.length} steps'),
                    children: [
                      for (final (i, e) in o.history.indexed)
                        _TimelineRow(
                          title: e.note.isEmpty
                              ? e.status.label
                              : '${e.status.label} · ${e.note}',
                          time: fmt.format(e.at),
                          last: i == o.history.length - 1,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line telling the admin what to do with this order right now.
class _NextStep extends StatelessWidget {
  const _NextStep({required this.order});
  final LpgOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final rider = o.riderName ?? 'The rider';
    final pay = o.payStage;
    final payNote = switch (pay) {
      PayStage.sendDetails =>
        ' Also send the ${o.paymentMethod.label} payment details.',
      PayStage.receipt => ' A payment receipt is waiting for you to check.',
      PayStage.issue => ' Waiting for the customer to send a new receipt.',
      PayStage.waiting => ' Waiting for the customer to pay.',
      null => '',
    };
    final (
      IconData icon,
      Color color,
      String title,
      String text,
    ) = switch (o.status) {
      OrderStatus.placed => (
        Icons.touch_app_rounded,
        Brand.blueDark,
        'Confirm this order',
        'Check the items and address, then confirm.$payNote',
      ),
      OrderStatus.confirmed =>
        o.isUpcoming()
            ? (
                Icons.event_available_rounded,
                const Color(0xFF6A3FC1),
                'Confirmed: send a rider on the day',
                'Nothing to do for the rider yet. It becomes a normal job ${LpgOrder.scheduleLead.inHours} hours before the window.$payNote',
              )
            : (
                Icons.two_wheeler_rounded,
                context.pal.warn,
                'Give it to a rider',
                'Choose a rider who is on shift.$payNote',
              ),
      OrderStatus.assigned => (
        Icons.hourglass_top_rounded,
        Brand.blueDark,
        'Waiting for $rider to start',
        '$rider has this order. You can still take it back until they leave.$payNote',
      ),
      OrderStatus.outForDelivery =>
        o.arrivedAt != null
            ? (
                Icons.pin_drop_rounded,
                Brand.success,
                '$rider has arrived',
                "They are at the customer's door now.$payNote",
              )
            : (
                Icons.navigation_rounded,
                Brand.success,
                '$rider is on the way',
                'Follow the live location below.$payNote',
              ),
      OrderStatus.delivered =>
        o.paymentStatus == PaymentStatus.paid
            ? (
                Icons.check_circle_rounded,
                Brand.success,
                'Delivered and paid',
                'Nothing more to do for this order.',
              )
            : (
                Icons.payments_rounded,
                context.pal.warn,
                'Delivered: payment not confirmed',
                'Check the money, then tap Mark paid.$payNote',
              ),
      OrderStatus.cancelled => (
        Icons.cancel_rounded,
        Brand.danger,
        'Order cancelled',
        o.cancelReason.isEmpty ? 'This order was cancelled.' : o.cancelReason,
      ),
    };
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.pal.card,
        borderRadius: BorderRadius.circular(Brand.radius),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Placed → Confirmed → Rider → On the way → Delivered.
class _Progress extends StatelessWidget {
  const _Progress({required this.order});
  final LpgOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    if (o.status == OrderStatus.cancelled) return const SizedBox.shrink();
    const labels = ['Placed', 'Confirmed', 'Rider', 'On the way', 'Delivered'];
    final at = switch (o.status) {
      OrderStatus.placed => 0,
      OrderStatus.confirmed => 1,
      OrderStatus.assigned => 2,
      OrderStatus.outForDelivery => 3,
      OrderStatus.delivered => 4,
      OrderStatus.cancelled => 0,
    };
    final pal = context.pal;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: panel(context),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: i <= at ? Brand.success : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i <= at ? Brand.success : pal.line,
                        width: 2,
                      ),
                    ),
                    child: i < at || (i == at && at == 4)
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                        : i == at
                        ? const Icon(Icons.circle, size: 9, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: i == at ? FontWeight.w800 : FontWeight.w500,
                        color: i <= at ? null : pal.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A titled card. The title row is optional (the summary card has none).
class _Section extends StatelessWidget {
  const _Section({this.title, this.icon, required this.children});
  final String? title;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(16),
    decoration: panel(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: context.pal.card,
                    border: Border.all(color: Brand.blueDark, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: Brand.blueDark),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        ...children,
      ],
    ),
  );
}

/// Label on the left, value on the right: every amount lines up.
class _KV extends StatelessWidget {
  const _KV(this.k, this.v, {this.big = false, this.valueColor, this.onCopy});
  final String k, v;
  final bool big;
  final Color? valueColor;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          k,
          style: TextStyle(
            color: big ? null : context.pal.muted,
            fontWeight: big ? FontWeight.w800 : FontWeight.w500,
            fontSize: big ? 16 : 14,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            v,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: big ? 20 : 14.5,
              color: valueColor,
            ),
          ),
        ),
        if (onCopy != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Copy',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
      ],
    ),
  );
}

/// A small tile with an icon and a short value (three across).
class _Mini extends StatelessWidget {
  const _Mini(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: context.pal.tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Brand.blueDark),
          const SizedBox(height: 4),
          Text(
            text,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

/// An equal-width action button.
class _Act extends StatelessWidget {
  const _Act(this.icon, this.label, this.onTap, {this.iconWidget});
  final Widget? iconWidget;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 46),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    onPressed: onTap,
    icon: iconWidget ?? Icon(icon, size: 19),
    label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.pal.card,
      border: Border.all(color: Brand.warning, width: 2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 18, color: Brand.warning),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
      ],
    ),
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.title,
    required this.time,
    required this.last,
  });
  final String title, time;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 20,
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 5),
                decoration: const BoxDecoration(
                  color: Brand.blueDark,
                  shape: BoxShape.circle,
                ),
              ),
              if (!last)
                Expanded(child: Container(width: 2, color: context.pal.line)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  time,
                  style: TextStyle(color: context.pal.muted, fontSize: 12.5),
                ),
              ],
            ),
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
              ? Text(
                  'Waiting for the rider\'s first location…',
                  style: TextStyle(color: context.pal.muted),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          l.isFresh()
                              ? Icons.my_location_rounded
                              : Icons.location_off_rounded,
                          size: 18,
                          color: l.isFresh() ? Brand.success : Brand.danger,
                        ),
                        const SizedBox(width: 8),
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => Launch.navigate(lat: l.lat, lng: l.lng),
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: const Text('See rider on map'),
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
    if (widget.order.isUpcoming() && widget.order.riderId == null) {
      final go = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('This order is for later'),
          content: Text(
            'The customer wants it ${scheduleLabel(widget.order)}. '
            'If you give it to a rider now, they see it as their job straight away. '
            'Usually you assign on the day.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Later'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Assign now'),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    final r = await showModalBottomSheet<RiderProfile>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => RiderPicker(
        riders: s.riders,
        current: widget.order.riderId,
        order: widget.order,
        allOrders: s.orders,
      ),
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
          decoration: const InputDecoration(
            labelText: 'Reason (the customer will see it)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep order'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Brand.danger),
            onPressed: () => Navigator.pop(
              ctx,
              c.text.trim().isEmpty ? 'Cancelled by Alpha LPG' : c.text.trim(),
            ),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    c.dispose();
    if (reason != null && mounted) {
      await _do(
        () => context.read<AdminSession>().cancel(widget.order, reason),
        'Order cancelled',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final s = context.read<AdminSession>();
    final buttons = <Widget>[];
    if (o.status == OrderStatus.placed) {
      buttons.add(
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _do(() => s.confirm(o), 'Order confirmed'),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Confirm order'),
        ),
      );
    }
    if (o.status == OrderStatus.placed ||
        o.status == OrderStatus.confirmed ||
        o.status == OrderStatus.assigned) {
      buttons.add(
        FilledButton.tonalIcon(
          onPressed: _busy ? null : _assign,
          icon: const Icon(Icons.two_wheeler),
          label: Text(o.riderId == null ? 'Assign rider' : 'Change rider'),
        ),
      );
    }
    if (o.awaitingPaymentCheck ||
        (o.paymentStatus == PaymentStatus.pending &&
            o.status == OrderStatus.delivered)) {
      buttons.add(
        FilledButton.tonalIcon(
          onPressed: _busy
              ? null
              : () async {
                  final severe = paymentWarnings(
                    o,
                    s.orders,
                  ).where((w) => w.severe).toList();
                  if (severe.isNotEmpty) {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Mark paid anyway?'),
                        content: Text(
                          severe.map((w) => '• ${w.text}').join('\n\n'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Go back'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Mark paid'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                  }
                  await _do(() => s.markPaid(o), 'Marked as paid');
                },
          icon: const Icon(Icons.verified_rounded),
          label: const Text('Mark paid'),
        ),
      );
    }
    // Only while the rider has not left yet. Once they are on the way the
    // order stays with them (call or message them instead).
    if (o.riderId != null && o.status == OrderStatus.assigned) {
      buttons.add(
        OutlinedButton(
          onPressed: _busy
              ? null
              : () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('Take this order back?'),
                      content: Text(
                        '${o.riderName ?? 'The rider'} will be told straight away that '
                        '${o.displayNumber} is no longer theirs. The order goes back to '
                        'the list so you can give it to someone else.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(d, false),
                          child: const Text('Keep with rider'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(d, true),
                          child: const Text('Take back'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await _do(
                      () => s.unassign(o),
                      'Taken back. ${o.riderName ?? 'The rider'} has been told.',
                    );
                  }
                },
          child: const Text('Take back from rider'),
        ),
      );
    }
    if (o.status == OrderStatus.assigned ||
        o.status == OrderStatus.outForDelivery) {
      buttons.add(
        OutlinedButton(
          onPressed: _busy
              ? null
              : o.awaitingPaymentCheck
              ? () => showMessage(
                  context,
                  'Confirm the ${o.paymentMethod.label} payment first (Mark paid), then deliver.',
                  error: true,
                )
              : () => _do(() => s.markDelivered(o), 'Marked delivered'),
          child: const Text('Mark delivered'),
        ),
      );
    }
    // Staff cannot cancel an order that has already been paid.
    if (o.status.isActive &&
        !s.isOwner &&
        o.paymentStatus == PaymentStatus.paid) {
      buttons.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'This order is paid, so only the owner can cancel it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.pal.muted, fontSize: 12.5),
          ),
        ),
      );
    }
    if (o.status.isActive &&
        (s.isOwner || o.paymentStatus != PaymentStatus.paid)) {
      buttons.add(
        TextButton(
          onPressed: _busy ? null : _cancel,
          style: TextButton.styleFrom(foregroundColor: Brand.danger),
          child: const Text('Cancel order'),
        ),
      );
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

class RiderPicker extends StatelessWidget {
  const RiderPicker({
    super.key,
    required this.riders,
    this.current,
    required this.order,
    this.allOrders = const [],
    this.extraCylinders,
    this.count = 1,
  });
  final List<RiderProfile> riders;
  final String? current;
  final LpgOrder order;
  final List<LpgOrder> allOrders;

  /// Cylinders being handed over (all of them when several orders go to one
  /// rider). Defaults to this order's own.
  final int? extraCylinders;

  /// How many orders are being handed over.
  final int count;

  int get _adding => extraCylinders ?? order.cylinderCount;

  int _carried(RiderProfile r) =>
      cylindersCarried(allOrders.where((o) => o.riderId == r.uid));

  int _jobs(RiderProfile r) =>
      allOrders.where((o) => o.riderId == r.uid && o.status.isActive).length;

  double? _km(RiderProfile r) => r.hasPosition && order.address.hasLocation
      ? distanceKm(r.lat!, r.lng!, order.address.lat!, order.address.lng!)
      : null;

  @override
  Widget build(BuildContext context) {
    // Live riders first, then free ones, then the closest.
    final list =
        [
          for (final r in riders)
            if (r.active) r,
        ]..sort((a, b) {
          int rank(RiderProfile r) =>
              (r.isLive() ? 0 : 4) + (_jobs(r) == 0 ? 0 : 2);
          final c = rank(a).compareTo(rank(b));
          if (c != 0) return c;
          return (_km(a) ?? 999).compareTo(_km(b) ?? 999);
        });
    final best = list.isEmpty || !list.first.isLive() || _km(list.first) == null
        ? null
        : list.first.uid;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: list.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No riders yet. Add one in the Riders tab.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      count > 1
                          ? 'Choose a rider for $count orders'
                          : 'Choose a rider',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (!list.any((r) => r.isLive()))
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        'No rider is on shift right now. A rider must be online in the Rider app before you can give them an order.',
                        style: TextStyle(color: Brand.danger, height: 1.35),
                      ),
                    ),
                  for (final r in list)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: context.pal.tint,
                        child: Icon(
                          Icons.two_wheeler,
                          color: r.online ? Brand.success : Colors.grey,
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(child: Text(r.name)),
                          if (r.uid == best) ...[
                            const SizedBox(width: 8),
                            const Pill(
                              Icons.near_me_rounded,
                              'Nearest',
                              color: Brand.success,
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        [
                          r.isLive()
                              ? 'Online'
                              : (r.online ? 'Not responding' : 'Offline'),
                          if (_km(r) != null)
                            '${_km(r)!.toStringAsFixed(1)} km away',
                          _jobs(r) == 0
                              ? 'free'
                              : '${_jobs(r)} job${_jobs(r) == 1 ? '' : 's'} now',
                          if (r.capacity > 0)
                            'carrying ${_carried(r)} of ${r.capacity} cylinders'
                          else if (_carried(r) > 0)
                            'carrying ${_carried(r)} cylinders',
                        ].join(' · '),
                        style: TextStyle(
                          color: r.overCapacity(_carried(r), _adding)
                              ? Brand.danger
                              : null,
                        ),
                      ),
                      trailing: r.uid == current
                          ? const Icon(Icons.check_rounded)
                          : (r.overCapacity(_carried(r), _adding)
                                ? const Pill(
                                    Icons.warning_amber_rounded,
                                    'Too many',
                                    color: Brand.danger,
                                  )
                                : null),
                      enabled: r.isLive(),
                      onTap: r.isLive()
                          ? () async {
                              if (r.overCapacity(_carried(r), _adding)) {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (d) => AlertDialog(
                                    title: const Text(
                                      'More than they can carry',
                                    ),
                                    content: Text(
                                      '${r.name} would carry ${_carried(r) + _adding} cylinders, '
                                      'and their vehicle takes ${r.capacity}. Give it to them anyway?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(d, false),
                                        child: const Text(
                                          'Choose someone else',
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(d, true),
                                        child: const Text('Give anyway'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok != true || !context.mounted) return;
                              }
                              Navigator.pop(context, r);
                            }
                          : null,
                    ),
                ],
              ),
      ),
    );
  }
}
