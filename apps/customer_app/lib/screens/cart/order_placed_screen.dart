import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Text;

import '../../l10n/lang.dart';

import '../../l10n/text.dart';

import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../state/cart.dart';
import '../../theme/brand.dart';
import '../../utils/launch.dart';
import '../../utils/nav.dart';
import '../../widgets/cancel_order.dart';
import '../../widgets/common.dart';
import '../../widgets/live.dart';
import '../../widgets/payment.dart';

/// Shown right after an order is placed. It follows the order live, so it
/// stays correct if the shop confirms it, a rider is sent, or it is cancelled.
class OrderPlacedScreen extends StatelessWidget {
  const OrderPlacedScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        body: SafeArea(
          child: Live<LpgOrder?>(
            cacheKey: orderId,
            stream: () => backend.orders.watchOrder(orderId),
            builder: (context, snap) {
              final o = snap.data;
              return Constrained(
                maxWidth: 480,
                child: o == null
                    ? const _Placing()
                    : _Content(order: o, orderId: orderId),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Placing extends StatelessWidget {
  const _Placing();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(
          'Placing your order…',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _Content extends StatelessWidget {
  const _Content({required this.order, required this.orderId});
  final LpgOrder order;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final pal = context.pal;
    final settings = context.watch<AppState>().settings;
    final cancelled = o.status == OrderStatus.cancelled;
    final prepaid = o.paymentMethod.isPrepaid;
    final paid = o.paymentStatus == PaymentStatus.paid;

    // The headline follows the order's real state.
    final (IconData icon, Color color, String title, String sub) = cancelled
        ? (
            Icons.close_rounded,
            Brand.danger,
            'Order cancelled',
            o.cancelReason.isEmpty
                ? 'This order was cancelled.'
                : o.cancelReason,
          )
        : switch (o.status) {
            OrderStatus.placed => (
              Icons.check_rounded,
              Brand.success,
              'Order placed!',
              'We have received it. Alpha LPG will confirm it shortly.',
            ),
            OrderStatus.confirmed => (
              Icons.thumb_up_alt_rounded,
              Brand.success,
              'Order confirmed',
              'We are finding a rider for you.',
            ),
            OrderStatus.assigned => (
              Icons.local_shipping_rounded,
              Brand.blueDark,
              'Rider assigned',
              '${o.riderName ?? 'Your rider'} is getting your cylinders ready.',
            ),
            OrderStatus.outForDelivery => (
              Icons.local_shipping_rounded,
              Brand.blueDark,
              'On the way',
              '${o.riderName ?? 'Your rider'} is coming to you.',
            ),
            OrderStatus.delivered => (
              Icons.home_rounded,
              Brand.success,
              'Delivered',
              'Thank you for ordering from Alpha LPG.',
            ),
            OrderStatus.cancelled => (
              Icons.close_rounded,
              Brand.danger,
              'Order cancelled',
              '',
            ),
          };

    // What the customer must do now (only the single most important thing).
    final (
      String? todoTitle,
      String? todoText,
      bool todoIsPayment,
    ) = cancelled || o.status == OrderStatus.delivered
        ? (null, null, false)
        : prepaid && !paid
        ? o.paymentIssue.isNotEmpty
              ? ('Payment problem', o.paymentIssue, true)
              : o.receiptAt != null
              ? (
                  'Payment sent: we are checking it',
                  'You do not need to do anything else.',
                  false,
                )
              : o.paymentRequest != null
              ? (
                  'Pay now',
                  'Alpha LPG has sent you the ${o.paymentMethod.label} account. Pay ${formatRupees(o.total)} and send your receipt.',
                  true,
                )
              : (
                  'Payment details coming',
                  'Alpha LPG is preparing the ${o.paymentMethod.label} account. You will get a notification. Do not pay before that.',
                  true,
                )
        : prepaid
        ? (null, null, false)
        : (
            'Keep ${formatRupees(o.total)} cash ready',
            'Pay the rider when your cylinders arrive.',
            false,
          );

    final step = switch (o.status) {
      OrderStatus.placed => 0,
      OrderStatus.confirmed => 1,
      OrderStatus.assigned => 2,
      OrderStatus.outForDelivery => 3,
      OrderStatus.delivered => 4,
      OrderStatus.cancelled => -1,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(icon, size: 48, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(color: pal.muted, height: 1.4),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'Order ${o.displayNumber}',
          textAlign: TextAlign.center,
          style: TextStyle(color: pal.muted, fontWeight: FontWeight.w600),
        ),

        // Where the order is.
        if (!cancelled) ...[const SizedBox(height: 18), _Steps(current: step)],

        // The one thing to do now.
        if (todoTitle != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.pal.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: todoIsPayment ? context.pal.warn : Brand.blueDark,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todoTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(todoText!, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],

        // The order itself: what, where, when, how much.
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(Brand.radius),
            boxShadow: pal.shadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final i in o.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text(
                        '${i.quantity}×',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${i.name} (${tr(i.typeLabel.toLowerCase())})',
                        ),
                      ),
                      Text(
                        formatRupees(i.lineTotal),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              if (o.deliveryFee > 0)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Delivery',
                        style: TextStyle(color: pal.muted),
                      ),
                    ),
                    Text(
                      formatRupees(o.deliveryFee),
                      style: TextStyle(color: pal.muted),
                    ),
                  ],
                ),
              const Divider(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    formatRupees(o.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const Divider(height: 22),
              _InfoRow(
                icon: Icons.schedule_rounded,
                title: o.scheduledFor == null
                    ? 'Delivery today'
                    : 'Scheduled delivery',
                subtitle: o.scheduledFor == null
                    ? 'Usually within 1–3 hours after we confirm.'
                    : o.notes.split('\n').first,
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.location_on_rounded,
                title: o.address.label,
                subtitle: o.address.oneLine,
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: o.paymentMethod.icon,
                title: o.paymentMethod.label,
                subtitle: paid
                    ? 'Paid'
                    : prepaid
                    ? 'Pay online (see above)'
                    : 'Cash to the rider on delivery',
              ),
              if (o.emptiesToCollect > 0 && !cancelled) ...[
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.autorenew_rounded,
                  title:
                      'Keep ${o.emptiesToCollect} empty cylinder${o.emptiesToCollect == 1 ? '' : 's'} ready',
                  subtitle: 'The rider swaps them for full ones.',
                ),
              ],
            ],
          ),
        ),

        // Actions: one clear main button, then the rest.
        const SizedBox(height: 20),
        if (cancelled) ...[
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () {
              context.read<Cart>().reorder(o);
              context.go('/');
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => context.push('/cart'),
              );
            },
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Order again'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => Launch.call(settings.phone),
            icon: const Icon(Icons.call_rounded),
            label: const Text('Call Alpha LPG'),
          ),
        ] else ...[
          if (todoIsPayment && prepaid && !paid)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Brand.flame,
                minimumSize: const Size.fromHeight(54),
              ),
              onPressed: () =>
                  context.goHomeThenPush(['/orders/$orderId/payment']),
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: Text(
                o.paymentRequest != null ? 'Pay now' : 'Open payment',
              ),
            ),
          if (todoIsPayment && prepaid && !paid) const SizedBox(height: 10),
          FilledButton.icon(
            style: (todoIsPayment && prepaid && !paid)
                ? FilledButton.styleFrom(
                    backgroundColor: pal.card,
                    foregroundColor: Brand.blueDark,
                    side: const BorderSide(color: Brand.blueDark),
                    minimumSize: const Size.fromHeight(50),
                  )
                : FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
            onPressed: () => context.goHomeThenPush(['/orders/$orderId']),
            icon: const Icon(Icons.local_shipping_rounded),
            label: const Text('Track my order'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => context.push('/invoice', extra: o),
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text('Invoice'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => context.go('/'),
                  child: const Text('Back to home'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Changing your mind: only while the shop has not confirmed it.
          if (o.status.customerCanCancel)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Brand.danger,
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: () => cancelOrderFlow(context, o),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Cancel this order'),
            )
          else if (o.status != OrderStatus.delivered)
            TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: () => Launch.call(settings.phone),
              icon: const Icon(Icons.call_rounded, size: 18),
              label: const Text('Need to change or cancel? Call us'),
            ),
        ],
      ],
    );
  }
}

/// Received → Confirmed → Rider → On the way → Delivered.
class _Steps extends StatelessWidget {
  const _Steps({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Received',
      'Confirmed',
      'Rider',
      'On the way',
      'Delivered',
    ];
    final pal = context.pal;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: i <= current ? Brand.success : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i <= current ? Brand.success : pal.line,
                      width: 2,
                    ),
                  ),
                  child: i < current || (i == current && current == 4)
                      ? const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: Colors.white,
                        )
                      : i == current
                      ? const Icon(Icons.circle, size: 8, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: i == current
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: i <= current ? null : pal.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.pal.tint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: context.pal.blue, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: context.pal.muted,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
