import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/cart.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    final state = context.watch<AppState>();
    final items = cart.toOrderItems(state.productById);
    final price = PriceBreakdown.of(items, state.settings);
    final problem = price.problem(state.settings);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your cart'),
        actions: [
          if (!cart.isEmpty)
            TextButton(onPressed: cart.clear, child: const Text('Clear')),
        ],
      ),
      body: cart.isEmpty
          ? EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Your cart is empty',
              message: 'Add a cylinder to get started.',
              action: FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Browse cylinders'),
              ),
            )
          : Constrained(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final line in cart.lines)
                    if (state.productById(line.productId) case final p?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CartLineTile(product: p, line: line),
                      ),
                  const SizedBox(height: 8),
                  PriceSummary(price: price, settings: state.settings),
                  if (price.emptiesHint(items) case final hint?) ...[
                    const SizedBox(height: 12),
                    _InfoBox(icon: Icons.autorenew, text: hint),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Constrained(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (problem != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            problem,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFB3261E)),
                          ),
                        ),
                      FilledButton(
                        onPressed: problem == null
                            ? () => context.push('/checkout')
                            : null,
                        child: Text('Checkout · ${formatRupees(price.total)}'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

extension on PriceBreakdown {
  String? emptiesHint(List<OrderItem> items) {
    final empties = items
        .where((i) => i.type == PurchaseType.refill)
        .fold(0, (n, i) => n + i.quantity);
    if (empties == 0) return null;
    return 'Refill prices: please keep $empties empty cylinder${empties == 1 ? '' : 's'} '
        'of the same size ready for our rider.';
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.product, required this.line});
  final Product product;
  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<Cart>();
    final unit = product.priceFor(line.type);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 72,
              decoration: BoxDecoration(
                color: Brand.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(6),
              child: ProductImage(product, height: 60),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${line.type.label} · ${formatRupees(unit)} each',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!product.inStock)
                    const Text(
                      'Out of stock — will be removed at checkout',
                      style: TextStyle(color: Color(0xFFB3261E), fontSize: 12),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    formatRupees(unit * line.quantity),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            QuantityStepper(
              value: line.quantity,
              onChanged: (q) => cart.setQuantity(line.productId, line.type, q),
            ),
          ],
        ),
      ),
    );
  }
}

class PriceSummary extends StatelessWidget {
  const PriceSummary({super.key, required this.price, required this.settings});
  final PriceBreakdown price;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final toFree = settings.freeDeliveryFrom - price.subtotal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(
              'Subtotal (${price.cylinders} cylinders)',
              formatRupees(price.subtotal),
            ),
            const SizedBox(height: 6),
            _row(
              'Delivery',
              price.freeDelivery ? 'FREE' : formatRupees(price.deliveryFee),
              valueColor: price.freeDelivery ? Brand.success : null,
            ),
            if (!price.freeDelivery &&
                settings.freeDeliveryFrom > 0 &&
                toFree > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add ${formatRupees(toFree)} more for free delivery',
                    style: const TextStyle(fontSize: 12, color: Brand.blueDark),
                  ),
                ),
              ),
            const Divider(height: 24),
            _row('Total', formatRupees(price.total), bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 18 : 14,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style.copyWith(color: valueColor)),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Brand.blue.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Brand.blueDark, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
