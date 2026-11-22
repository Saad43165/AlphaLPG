import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Text;
import 'package:provider/provider.dart';

import '../../l10n/text.dart';
import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../state/cart.dart';
import '../../state/promo_state.dart';
import '../../theme/brand.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// "Same again every month": a repeat order the customer sets up once. The
/// phone reminds them when it is due and the order is one tap away.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  int _every = 30;
  bool _busy = false;
  LpgOrder? _last;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  Future<void> _loadLast() async {
    final uid = context.read<AppState>().uid;
    if (uid == null) return;
    try {
      final list = await context
          .read<Backend>()
          .orders
          .watchCustomerOrders(uid)
          .first;
      if (!mounted) return;
      setState(() {
        _last = list.where((o) => o.status == OrderStatus.delivered).isEmpty
            ? null
            : list.firstWhere((o) => o.status == OrderStatus.delivered);
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _save(LpgOrder from) async {
    final uid = context.read<AppState>().uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await context.read<Backend>().promo.savePlan(
        uid,
        RefillPlan(
          lines: [
            for (final i in from.items)
              {
                'productId': i.productId,
                'type': i.type.name,
                'quantity': i.quantity,
              },
          ],
          everyDays: _every,
          paymentMethod: from.paymentMethod.name,
          nextDue: DateTime.now().add(Duration(days: _every)),
        ),
      );
      if (mounted) showMessage(context, 'Your refill plan is on.');
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Could not save. Check your internet.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _orderNow(RefillPlan p) {
    final cart = context.read<Cart>();
    final state = context.read<AppState>();
    cart.clear();
    for (final l in p.lines) {
      final id = l['productId'] as String? ?? '';
      if (state.productById(id) == null) continue;
      cart.add(
        id,
        PurchaseType.parse(l['type'] as String?),
        (l['quantity'] as num?)?.toInt() ?? 1,
      );
    }
    context.push('/cart');
  }

  String _linesText(RefillPlan p, AppState state) => [
    for (final l in p.lines)
      '${l['quantity']} × ${state.productById(l['productId'] as String? ?? '')?.name ?? (l['productId'] ?? '')}',
  ].join(', ');

  @override
  Widget build(BuildContext context) {
    final promo = context.watch<PromoState>();
    final state = context.watch<AppState>();
    final pal = context.pal;
    final plan = promo.plan;
    return Scaffold(
      appBar: AppBar(
        leading: const ScreenBack(),
        title: const Text('Refill plan'),
      ),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Brand.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Set up the same order once. We remind you when it is time, and you place it in one tap. Nothing is ordered or charged without you confirming.',
                style: TextStyle(color: pal.muted, height: 1.4),
              ),
            ),
            const SizedBox(height: 14),
            if (plan != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _panel(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _linesText(plan, state),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Every ${plan.everyDays} days · ${plan.nextDue == null ? '' : 'next: ${formatDay(plan.nextDue!)}'}',
                      style: TextStyle(color: pal.muted),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: () => _orderNow(plan),
                      icon: const Icon(Icons.shopping_cart_checkout_rounded),
                      label: Text(
                        plan.isDue() ? 'Order now (it is due)' : 'Order now',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Material(
                      type: MaterialType.transparency,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Remind me'),
                        value: plan.active,
                        onChanged: (v) {
                          final uid = state.uid;
                          if (uid != null) {
                            context.read<Backend>().promo.savePlan(
                              uid,
                              plan.copyWith(active: v),
                            );
                          }
                        },
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        final uid = state.uid;
                        if (uid != null) {
                          context.read<Backend>().promo.deletePlan(uid);
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Remove this plan'),
                      style: TextButton.styleFrom(
                        foregroundColor: Brand.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!_loaded)
              const Center(child: CircularProgressIndicator())
            else if (_last == null)
              const EmptyState(
                icon: Icons.event_repeat_rounded,
                title: 'Order once first',
                message: 'After your first delivery you can repeat that order on a plan.',
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _panel(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Repeat my last order',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        for (final i in _last!.items)
                          '${i.quantity} × ${i.name} (${i.type.label.toLowerCase()})',
                      ].join(', '),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'How often?',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final d in const [14, 21, 30, 45, 60])
                          ChoiceChip(
                            label: Text('Every $d days'),
                            selected: _every == d,
                            onSelected: (_) => setState(() => _every = d),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: _busy ? null : () => _save(_last!),
                      child: const Text('Start my plan'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  BoxDecoration _panel(BuildContext context) => BoxDecoration(
    color: context.pal.card,
    borderRadius: BorderRadius.circular(Brand.radius),
    boxShadow: context.pal.shadow,
  );
}
