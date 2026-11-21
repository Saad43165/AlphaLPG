import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../theme/brand.dart';
import '../../utils/nav.dart';
import '../../widgets/common.dart';
import '../../widgets/live.dart';
import '../../widgets/payment.dart';

class OrderPlacedScreen extends StatelessWidget {
  const OrderPlacedScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final settings = context.watch<AppState>().settings;
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                  children: [
                    Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.4, end: 1),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        builder: (_, v, child) =>
                            Transform.scale(scale: v, child: child),
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            color: Brand.success,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Brand.success.withValues(alpha: 0.35),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Order placed!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      o == null ? '' : 'Order ${o.displayNumber}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.pal.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (o != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.pal.card,
                          borderRadius: BorderRadius.circular(Brand.radius),
                          boxShadow: context.pal.shadow,
                        ),
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.schedule_rounded,
                              title: o.scheduledFor == null
                                  ? 'Arriving today'
                                  : 'Scheduled delivery',
                              subtitle: o.scheduledFor == null
                                  ? 'Usually within 1–3 hours. We will confirm shortly.'
                                  : o.notes.split('\n').first,
                            ),
                            const Divider(height: 24),
                            _InfoRow(
                              icon: Icons.location_on_rounded,
                              title: o.address.label,
                              subtitle: o.address.oneLine,
                            ),
                            const Divider(height: 24),
                            _InfoRow(
                              icon: o.paymentMethod.icon,
                              title:
                                  '${o.paymentMethod.label} · ${formatRupees(o.total)}',
                              subtitle: o.paymentMethod.isPrepaid
                                  ? (o.paymentReference.isEmpty
                                        ? 'Send the payment and add the transaction ID on your order page'
                                        : 'Transaction ID ${o.paymentReference}')
                                  : 'Please keep cash ready for the rider',
                            ),
                            if (o.emptiesToCollect > 0) ...[
                              const Divider(height: 24),
                              _InfoRow(
                                icon: Icons.autorenew_rounded,
                                title:
                                    'Keep ${o.emptiesToCollect} empty cylinder${o.emptiesToCollect == 1 ? '' : 's'} ready',
                                subtitle:
                                    'Our rider will swap them for full ones',
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (o.paymentMethod.isPrepaid &&
                          o.paymentReference.isEmpty) ...[
                        const SizedBox(height: 14),
                        PaymentSteps(
                          method: o.paymentMethod,
                          settings: settings,
                          total: o.total,
                          orderNumber: o.displayNumber,
                        ),
                      ],
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () =>
                          context.goHomeThenPush(['/orders/$orderId']),
                      icon: const Icon(Icons.local_shipping_rounded),
                      label: const Text('Track my order'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: o == null
                                ? null
                                : () => context.push('/invoice', extra: o),
                            icon: const Icon(Icons.receipt_long_rounded),
                            label: const Text('Invoice'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.go('/'),
                            child: const Text('Home'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
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
        child: Icon(icon, color: Brand.blueDark, size: 20),
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
