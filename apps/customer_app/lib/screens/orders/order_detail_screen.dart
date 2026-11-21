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
import '../../widgets/live_rider_map.dart';
import '../../widgets/payment.dart';
import '../../widgets/payment_request_card.dart';
import '../../utils/haptics.dart';

/// Live order tracking: status header with ETA and route, step tracker,
/// rider, items, payment and delivery details.
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
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(leading: const ScreenBack()),
            body: EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load this order',
              message: '${snap.error}',
            ),
          );
        }
        if (o == null) {
          return Scaffold(
            appBar: AppBar(leading: const ScreenBack()),
            body: snap.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : const EmptyState(
                    icon: Icons.search_off,
                    title: 'Order not found',
                  ),
          );
        }
        return _TrackingView(o);
      },
    );
  }
}

// ---------------------------------------------------------------------------

extension _Tracking on LpgOrder {
  /// Shown under the headline; "at your door" once the rider has arrived.
  String get statusLine =>
      status == OrderStatus.outForDelivery && arrivedAt != null
      ? 'Your rider is at your door'
      : status.description;

  String get headline =>
      status == OrderStatus.outForDelivery && arrivedAt != null
      ? 'Rider has arrived'
      : _headline;

  String get _headline => switch (status) {
    OrderStatus.placed => 'Order received',
    OrderStatus.confirmed => 'Order confirmed',
    OrderStatus.assigned => 'Rider assigned',
    OrderStatus.outForDelivery => 'On the way',
    OrderStatus.delivered => 'Delivered',
    OrderStatus.cancelled => 'Order cancelled',
  };

  LinearGradient get heroGradient => switch (status) {
    OrderStatus.delivered => const LinearGradient(
      colors: [Color(0xFF23B26A), Color(0xFF137A47)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    OrderStatus.cancelled => const LinearGradient(
      colors: [Color(0xFF7D8B99), Color(0xFF4F5D6B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    _ => Brand.headerGradient,
  };

  /// Only real facts: when it was delivered, or the slot the customer chose.
  /// (Live "minutes away" comes from the rider's GPS on the map card.)
  String? get etaLine {
    if (status == OrderStatus.cancelled) return null;
    if (status == OrderStatus.delivered) {
      final at = timeOf(OrderStatus.delivered);
      return at == null ? null : 'Delivered at ${formatTime(at)}';
    }
    if (scheduledFor != null) {
      final slot = notes.split('\n').first.replaceFirst('Slot: ', '');
      return 'Scheduled · ${formatDay(scheduledFor!)}, $slot';
    }
    return null;
  }
}

class _TrackingView extends StatelessWidget {
  const _TrackingView(this.o);
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
          'Could not cancel: it may already be confirmed. Please call us.',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final riderVisible = o.riderName != null && o.status.isActive;
    final payFirst =
        o.paymentMethod.isPrepaid &&
        o.paymentStatus != PaymentStatus.paid &&
        o.status != OrderStatus.cancelled;
    return AnnotatedRegion(
      value: Brand.lightStatusBar,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              leading: const ScreenBack(),
              pinned: true,
              backgroundColor: o.heroGradient.colors.first,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              foregroundColor: Colors.white,
              systemOverlayStyle: Brand.lightStatusBar,
              title: Text(
                'Order ${o.displayNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                if (o.status != OrderStatus.cancelled)
                  Badge(
                    isLabelVisible: context.watch<ChatInbox>().unread(o.id) > 0,
                    label: Text('${context.watch<ChatInbox>().unread(o.id)}'),
                    backgroundColor: Brand.cylinderRed,
                    offset: const Offset(-4, 4),
                    child: IconButton(
                      tooltip: 'Messages',
                      onPressed: () => context.push('/orders/${o.id}/chat'),
                      icon: const Icon(Icons.forum_rounded),
                    ),
                  ),
                if (o.status != OrderStatus.cancelled)
                  IconButton(
                    tooltip: 'Invoice',
                    onPressed: () => context.push('/invoice', extra: o),
                    icon: const Icon(Icons.receipt_long_rounded),
                  ),
                IconButton(
                  tooltip: 'Copy order number',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: o.displayNumber));
                    showMessage(context, 'Order number copied');
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
            SliverToBoxAdapter(child: _Hero(o)),
            SliverToBoxAdapter(
              child: Constrained(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (o.status == OrderStatus.delivered) ...[
                        _DeliveredActions(o),
                        const SizedBox(height: 14),
                        if (o.canBeRated) ...[
                          _RateCard(o),
                          const SizedBox(height: 14),
                        ],
                      ],
                      if (o.status == OrderStatus.cancelled) _CancelledCard(o),
                      if (payFirst) ...[
                        _PayFirstBanner(o),
                        const SizedBox(height: 14),
                        _PaymentCard(o),
                        const SizedBox(height: 14),
                      ],
                      if (o.status == OrderStatus.outForDelivery)
                        LiveRiderMap(order: o),
                      if (riderVisible) ...[
                        const SizedBox(height: 14),
                        _RiderCard(o),
                        const SizedBox(height: 10),
                        _ShareRow(o),
                      ],
                      if (o.status != OrderStatus.cancelled) ...[
                        const SizedBox(height: 10),
                        _ChatCard(o),
                      ],
                      if (o.canBeRated &&
                          o.status != OrderStatus.delivered) ...[
                        const SizedBox(height: 14),
                        _RateCard(o),
                      ],
                      if (o.rating != null) ...[
                        const SizedBox(height: 14),
                        _RatedCard(o),
                      ],
                      const _Heading('Order details'),
                      _ItemsCard(o),
                      if (!payFirst) ...[
                        const _Heading('Payment'),
                        _PaymentCard(o),
                      ],
                      const _Heading('Delivery'),
                      _DeliveryCard(o),
                      if (o.status != OrderStatus.cancelled) ...[
                        const _Heading('Order timeline'),
                        _StepTracker(o),
                      ],
                      if (o.status != OrderStatus.placed &&
                          o.status != OrderStatus.cancelled) ...[
                        const SizedBox(height: 14),
                        _ProblemButton(o),
                      ],
                      const SizedBox(height: 20),
                      if (o.status != OrderStatus.delivered)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Launch.whatsapp(
                                  settings.whatsapp,
                                  'Hi Alpha LPG, I have a question about order ${o.displayNumber}.',
                                ),
                                icon: const Icon(
                                  Icons.chat_rounded,
                                  color: Brand.whatsapp,
                                ),
                                label: const Text('Get help'),
                              ),
                            ),
                            if (!o.status.isActive) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(50),
                                  ),
                                  onPressed: () {
                                    context.read<Cart>().reorder(o);
                                    context.push('/cart');
                                  },
                                  icon: const Icon(Icons.replay_rounded),
                                  label: const Text('Order again'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      if (o.status.customerCanCancel) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Brand.danger,
                          ),
                          onPressed: () => _cancel(context),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Cancel order'),
                        ),
                      ],
                      if (o.createdAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Placed ${formatDateTime(o.createdAt!)} · ${o.displayNumber}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.pal.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
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

/// Shown above everything while an online payment is still owed.
class _PayFirstBanner extends StatelessWidget {
  const _PayFirstBanner(this.o);
  final LpgOrder o;

  @override
  Widget build(BuildContext context) {
    final sent = o.paymentRequest != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Brand.flame.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_balance_wallet_rounded, color: Brand.flame),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sent
                  ? 'Payment needed: ${formatRupees(o.total)}. Pay with the details below, then add your receipt. Your order is delivered once Alpha LPG confirms it.'
                  : 'Payment needed: ${formatRupees(o.total)}. Alpha LPG will send the ${o.paymentMethod.label} account here shortly. You can chat with them meanwhile.',
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
    ),
  );
}

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
  color: context.pal.card,
  borderRadius: BorderRadius.circular(Brand.radius),
  boxShadow: context.pal.shadow,
);

// ---------------------------------------------------------------------------
// Hero: status, ETA and the depot → home route.

class _Hero extends StatelessWidget {
  const _Hero(this.o);
  final LpgOrder o;

  @override
  Widget build(BuildContext context) {
    final eta = o.etaLine;
    return Container(
      decoration: BoxDecoration(gradient: o.heroGradient),
      child: Constrained(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                layoutBuilder: (current, _) => current ?? const SizedBox(),
                child: Column(
                  key: ValueKey(o.status),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      o.status == OrderStatus.cancelled &&
                              o.cancelReason.isNotEmpty
                          ? 'Reason: ${o.cancelReason}'
                          : o.statusLine,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              if (o.status == OrderStatus.delivered) ...[
                const SizedBox(height: 16),
                _FactChips(o),
              ] else if (eta != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        o.status == OrderStatus.delivered
                            ? Icons.check_circle_rounded
                            : Icons.schedule_rounded,
                        color: Brand.flame,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          eta,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (o.status.isActive) ...[
                const SizedBox(height: 20),
                _StageBar(o),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTracker extends StatelessWidget {
  const _StepTracker(this.o);
  final LpgOrder o;

  static const _icons = {
    OrderStatus.placed: Icons.receipt_long_rounded,
    OrderStatus.confirmed: Icons.thumb_up_alt_rounded,
    OrderStatus.assigned: Icons.person_pin_circle_rounded,
    OrderStatus.outForDelivery: Icons.two_wheeler_rounded,
    OrderStatus.delivered: Icons.home_rounded,
  };

  static const _short = {
    OrderStatus.placed: 'Placed',
    OrderStatus.confirmed: 'Confirmed',
    OrderStatus.assigned: 'Assigned',
    OrderStatus.outForDelivery: 'On the way',
    OrderStatus.delivered: 'Delivered',
  };

  @override
  Widget build(BuildContext context) {
    final current = OrderStatus.journey.indexOf(o.status);
    final steps = OrderStatus.journey;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
      decoration: _cardDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 46,
                    child: Row(
                      children: [
                        Expanded(
                          child: i == 0
                              ? const SizedBox()
                              : Container(
                                  height: 3,
                                  color: i <= current
                                      ? Brand.blueDark
                                      : context.pal.line,
                                ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: i == current ? 42 : 34,
                          height: i == current ? 42 : 34,
                          decoration: BoxDecoration(
                            color: i < current
                                ? Brand.blueDark
                                : (i == current
                                      ? Brand.blueDark
                                      : Colors.white),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: i <= current
                                  ? Brand.blueDark
                                  : context.pal.line,
                              width: 2,
                            ),
                            boxShadow: i == current
                                ? [
                                    BoxShadow(
                                      color: Brand.blue.withValues(alpha: 0.45),
                                      blurRadius: 14,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            i < current
                                ? Icons.check_rounded
                                : _icons[steps[i]],
                            size: i == current ? 22 : 18,
                            color: i <= current
                                ? Colors.white
                                : context.pal.muted,
                          ),
                        ),
                        Expanded(
                          child: i == steps.length - 1
                              ? const SizedBox()
                              : Container(
                                  height: 3,
                                  color: i < current
                                      ? Brand.blueDark
                                      : context.pal.line,
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _short[steps[i]]!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: i == current
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: i <= current
                              ? context.pal.ink
                              : context.pal.muted,
                        ),
                      ),
                    ),
                  ),
                  if (o.timeOf(steps[i]) case final at?)
                    Text(
                      formatTime(at),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: context.pal.muted,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CancelledCard extends StatelessWidget {
  const _CancelledCard(this.o);
  final LpgOrder o;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(context),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: Color(0xFFFFEEEB),
          child: Icon(Icons.cancel_rounded, color: Brand.danger),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This order was cancelled',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              if (o.cancelReason.isNotEmpty)
                Text(
                  o.cancelReason,
                  style: TextStyle(color: context.pal.muted),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RiderCard extends StatelessWidget {
  const _RiderCard(this.o);
  final LpgOrder o;

  @override
  Widget build(BuildContext context) {
    final name = o.riderName!;
    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => RegExp(r'^[A-Za-z]').hasMatch(w))
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Brand.navy,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: context.pal.card,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Brand.blueDark,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  o.status == OrderStatus.outForDelivery
                      ? 'Heading to you · Alpha LPG rider'
                      : 'Loading your cylinders · Alpha LPG rider',
                  style: TextStyle(color: context.pal.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Badge(
            isLabelVisible: context.watch<ChatInbox>().unread(o.id) > 0,
            label: Text('${context.watch<ChatInbox>().unread(o.id)}'),
            backgroundColor: Brand.cylinderRed,
            child: _RoundAction(
              tooltip: 'Message rider',
              icon: Icons.chat_rounded,
              color: Brand.blueDark,
              onTap: () => context.push('/orders/${o.id}/chat'),
            ),
          ),
          if (o.riderPhone != null) ...[
            const SizedBox(width: 8),
            _RoundAction(
              tooltip: 'Call rider',
              icon: Icons.call_rounded,
              color: Brand.success,
              onTap: () => Launch.call(o.riderPhone!),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    ),
  );
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard(this.o);
  final LpgOrder o;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Column(
        children: [
          for (final i in o.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 54,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.pal.tint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: switch (state.productById(i.productId)) {
                      final p? => ProductImage(p, height: 46),
                      null => const Icon(
                        Icons.propane_tank_rounded,
                        color: Brand.cylinderRed,
                      ),
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i.quantity} × ${i.name}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${i.type.label} · ${formatRupees(i.unitPrice)} each',
                          style: TextStyle(
                            color: context.pal.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatRupees(i.lineTotal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          const Divider(height: 18),
          _kv('Subtotal', formatRupees(o.subtotal)),
          const SizedBox(height: 4),
          _kv(
            'Delivery',
            o.deliveryFee == 0 ? 'FREE' : formatRupees(o.deliveryFee),
            valueColor: o.deliveryFee == 0 ? Brand.success : null,
          ),
          const SizedBox(height: 8),
          _kv('Total', formatRupees(o.total), bold: true),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false, Color? valueColor}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
      fontSize: bold ? 17 : 14,
    );
    return Row(
      children: [
        Text(k, style: style),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            v,
            textAlign: TextAlign.end,
            style: style.copyWith(color: valueColor),
          ),
        ),
      ],
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard(this.o);
  final LpgOrder o;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: _cardDecoration(context),
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.location_on_rounded),
            title: Text(
              o.address.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(o.address.oneLine),
            trailing: o.address.hasLocation
                ? IconButton(
                    tooltip: 'Open in maps',
                    icon: const Icon(Icons.map_rounded),
                    onPressed: () =>
                        Launch.maps(lat: o.address.lat, lng: o.address.lng),
                  )
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.schedule_rounded),
            title: Text(
              o.scheduledFor == null
                  ? 'As soon as possible'
                  : formatDay(o.scheduledFor!),
            ),
            subtitle: o.notes.isEmpty ? null : Text(o.notes),
          ),
          if (o.emptiesToCollect > 0)
            ListTile(
              leading: const Icon(Icons.autorenew_rounded),
              title: Text(
                'Keep ${o.emptiesToCollect} empty cylinder${o.emptiesToCollect == 1 ? '' : 's'} ready',
              ),
              subtitle: const Text('Our rider swaps them for full ones'),
            ),
          ListTile(
            leading: const Icon(Icons.person_rounded),
            title: Text(
              o.businessName.isEmpty
                  ? o.customerName
                  : '${o.customerName} · ${o.businessName}',
            ),
            subtitle: Text(prettyPkMobile(o.customerPhone)),
          ),
        ],
      ),
    ),
  );
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
      color: context.pal.card,
      borderRadius: BorderRadius.circular(Brand.radius),
      boxShadow: context.pal.shadow,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                tooltip: '$i star${i == 1 ? '' : 's'}',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  Haptics.select();
                  setState(() => _stars = i);
                },
                icon: Icon(
                  i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: i <= _stars ? Brand.flame : context.pal.muted,
                  size: 36,
                ),
              ),
          ],
        ),
        SizedBox(
          height: 24,
          child: Center(
            child: Text(
              _labels[_stars],
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
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
        color: context.pal.card,
        borderRadius: BorderRadius.circular(Brand.radius),
        boxShadow: context.pal.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PaymentLogo(o.paymentMethod, width: 56, height: 40),
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
                      style: TextStyle(color: context.pal.muted),
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
          if (o.status != OrderStatus.cancelled) ...[
            const SizedBox(height: 12),
            _PayStatus(o),
          ],
          if (o.paymentReference.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Transaction ID: ${o.paymentReference}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          if (needsTransfer) ...[
            const SizedBox(height: 12),
            if (o.paymentRequest != null) ...[
              PaymentRequestCard(o.paymentRequest!),
              const SizedBox(height: 12),
            ],
            if (o.paymentReference.isEmpty && o.paymentRequest == null)
              PaymentSteps(
                method: o.paymentMethod,
                settings: settings,
                total: o.total,
                orderNumber: o.displayNumber,
              ),
            const SizedBox(height: 10),
            ReceiptSection(o),
            const SizedBox(height: 8),
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

class _FactChips extends StatelessWidget {
  const _FactChips(this.o);
  final LpgOrder o;

  @override
  Widget build(BuildContext context) {
    final paid = o.paymentStatus == PaymentStatus.paid;
    Widget chip(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Brand.flame),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (o.etaLine != null) chip(Icons.schedule_rounded, o.etaLine!),
        chip(
          Icons.propane_tank_rounded,
          '${o.cylinderCount} cylinder${o.cylinderCount == 1 ? '' : 's'}',
        ),
        chip(Icons.payments_rounded, formatRupees(o.total)),
        chip(
          paid ? Icons.verified_rounded : Icons.hourglass_bottom_rounded,
          paid ? 'Paid' : 'Payment pending',
        ),
      ],
    );
  }
}

/// What people actually do after a delivery.
class _DeliveredActions extends StatelessWidget {
  const _DeliveredActions(this.o);
  final LpgOrder o;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    Widget small(
      IconData icon,
      String label,
      VoidCallback onTap, {
      Color? color,
    }) => Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 64),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        onPressed: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12.5)),
          ],
        ),
      ),
    );
    return Column(
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: () {
            context.read<Cart>().reorder(o);
            context.push('/cart');
          },
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Order the same again'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            small(
              Icons.receipt_long_rounded,
              'Invoice',
              () => context.push('/invoice', extra: o),
            ),
            const SizedBox(width: 10),
            small(
              Icons.chat_rounded,
              'Get help',
              () => Launch.whatsapp(
                settings.whatsapp,
                'Hi Alpha LPG, I have a question about order ${o.displayNumber}.',
              ),
              color: Brand.whatsapp,
            ),
            const SizedBox(width: 10),
            small(Icons.copy_rounded, 'Copy no.', () {
              Clipboard.setData(ClipboardData(text: o.displayNumber));
              showMessage(context, 'Order number copied');
            }),
          ],
        ),
      ],
    );
  }
}

/// Preparing → On the way → Delivered, on the coloured header.
class _StageBar extends StatelessWidget {
  const _StageBar(this.o);
  final LpgOrder o;

  int get _stage => switch (o.status) {
    OrderStatus.outForDelivery => 1,
    OrderStatus.delivered => 2,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    const labels = ['Preparing', 'On the way', 'Delivered'];
    const icons = [
      Icons.inventory_2_rounded,
      Icons.two_wheeler_rounded,
      Icons.home_rounded,
    ];
    final stage = _stage;
    Widget node(int i) {
      final done = i < stage;
      final now = i == stage;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: now ? 46 : 38,
            height: now ? 46 : 38,
            decoration: BoxDecoration(
              color: done || now
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              boxShadow: now
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              done ? Icons.check_rounded : icons[i],
              size: now ? 24 : 20,
              color: done || now
                  ? o.heroGradient.colors.last
                  : Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            labels[i],
            style: TextStyle(
              color: Colors.white.withValues(alpha: done || now ? 1 : 0.75),
              fontWeight: now ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ],
      );
    }

    Widget line(int i) => Expanded(
      child: Padding(
        // Level with the middle of the 46px node row.
        padding: const EdgeInsets.only(bottom: 22),
        child: Container(
          height: 4,
          decoration: BoxDecoration(
            color: i < stage
                ? Colors.white
                : Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [node(0), line(0), node(1), line(1), node(2)],
    );
  }
}

/// "Share delivery details" with family, over WhatsApp.
class _ShareRow extends StatelessWidget {
  const _ShareRow(this.o);
  final LpgOrder o;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
      onPressed: () => Launch.whatsappShare(
        'My Alpha LPG gas order ${o.displayNumber} is '
        '${o.status == OrderStatus.outForDelivery ? 'on the way' : 'being prepared'}.'
        '\nRider: ${o.riderName}${o.riderPhone != null ? ' (${o.riderPhone})' : ''}'
        '\nDelivering to: ${o.address.oneLine}',
      ),
      icon: const Icon(Icons.share_rounded, size: 18),
      label: const Text('Share delivery details'),
    ),
  );
}

/// "Something wrong with this order?" → WhatsApp with the order number and
/// the problem already typed.
class _ProblemButton extends StatelessWidget {
  const _ProblemButton(this.o);
  final LpgOrder o;

  static const _reasons = [
    ('Rider is late', Icons.schedule_rounded),
    ('Wrong cylinder or quantity', Icons.swap_horiz_rounded),
    ('Cylinder not delivered', Icons.report_gmailerrorred_rounded),
    ('Payment or price problem', Icons.payments_rounded),
    ('Rider behaviour', Icons.person_off_rounded),
    ('Something else', Icons.chat_bubble_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        final whatsapp = context.read<AppState>().settings.whatsapp;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What went wrong?',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  'We will message you on WhatsApp about order ${o.displayNumber}.',
                  style: TextStyle(color: context.pal.muted),
                ),
                const SizedBox(height: 8),
                for (final (label, icon) in _reasons)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(icon, color: Brand.blueDark),
                    title: Text(label),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(sheet);
                      Launch.whatsapp(
                        whatsapp,
                        'Hi Alpha LPG, there is a problem with order '
                        '${o.displayNumber}: $label.',
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    ),
    icon: const Icon(Icons.flag_outlined),
    label: const Text('Something wrong with this order?'),
  );
}

/// Says plainly where this payment stands and who marks it paid.
class _PayStatus extends StatelessWidget {
  const _PayStatus(this.o);
  final LpgOrder o;

  @override
  Widget build(BuildContext context) {
    final paid = o.paymentStatus == PaymentStatus.paid;
    final cod = o.paymentMethod == PaymentMethod.cashOnDelivery;
    final total = formatRupees(o.total);
    final (IconData icon, Color color, String text) = paid
        ? (
            Icons.verified_rounded,
            Brand.success,
            cod
                ? 'Paid in cash${o.cashCollected != null && o.cashCollected! > 0 ? ' · ${formatRupees(o.cashCollected!)} collected by ${o.riderName ?? 'the rider'}' : ''}.'
                : 'Payment confirmed by Alpha LPG.',
          )
        : cod
        ? o.status == OrderStatus.delivered
              ? (
                  Icons.hourglass_bottom_rounded,
                  const Color(0xFF8A6D00),
                  'Delivered. Alpha LPG will confirm your cash payment here.',
                )
              : (
                  Icons.payments_rounded,
                  Brand.blueDark,
                  'Pay $total in cash to the rider at the door. The rider records it and this order then shows Paid.',
                )
        : o.paymentIssue.isNotEmpty
        ? (
            Icons.error_outline_rounded,
            Brand.danger,
            'We could not confirm your payment. See the note below and send a new receipt.',
          )
        : o.receiptAt != null
        ? (
            Icons.hourglass_top_rounded,
            Brand.blueDark,
            'Receipt received. Alpha LPG is checking it and this changes to Paid once confirmed.',
          )
        : o.paymentRequest != null && o.paymentReference.isEmpty
        ? (
            Icons.account_balance_wallet_rounded,
            const Color(0xFF8A6D00),
            'Pay $total using the details above, then add your receipt.',
          )
        : o.paymentReference.isEmpty
        ? (
            Icons.account_balance_wallet_rounded,
            const Color(0xFF8A6D00),
            'Send $total, then add your transaction ID so we can match it.',
          )
        : (
            Icons.hourglass_top_rounded,
            Brand.blueDark,
            'Thanks! We are checking transaction ${o.paymentReference}. This changes to Paid as soon as Alpha LPG confirms it.',
          );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(height: 1.4, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Entry to the order chat, with the latest message and an unread count.
class _ChatCard extends StatelessWidget {
  const _ChatCard(this.o);
  final LpgOrder o;

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatInbox>();
    final unread = chat.unread(o.id);
    final last = chat.last(o.id);
    return Builder(
      builder: (context) {
        return Material(
          color: Colors.transparent,
          child: Ink(
            decoration: _cardDecoration(context),
            child: InkWell(
              borderRadius: BorderRadius.circular(Brand.radius),
              onTap: () => context.push('/orders/${o.id}/chat'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Badge(
                      isLabelVisible: unread > 0,
                      label: Text('$unread'),
                      backgroundColor: Brand.cylinderRed,
                      child: const CircleAvatar(
                        backgroundColor: Brand.blueDark,
                        child: Icon(Icons.forum_rounded, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.riderName != null
                                ? 'Chat with ${o.riderName} and Alpha LPG'
                                : 'Chat with Alpha LPG',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            last == null
                                ? 'Tell the rider where to find you'
                                : '${last.role == MessageRole.customer ? 'You' : (last.name.isEmpty ? last.role.fallbackName : last.name)}: ${last.text}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: unread > 0
                                  ? context.pal.ink
                                  : context.pal.muted,
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
