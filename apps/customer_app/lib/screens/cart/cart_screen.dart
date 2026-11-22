import 'package:alpha_ui/alpha_ui.dart' show showAppMessage;
import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Text;

import '../../l10n/lang.dart';

import 'package:material_ui/material_ui.dart' as mu show Text;

import '../../l10n/text.dart';

import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/cart.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';
import '../../utils/haptics.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear your cart?'),
        content: const Text('All cylinders will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) context.read<Cart>().clear();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    final state = context.watch<AppState>();
    final items = cart.toOrderItems(state.productById);
    final price = PriceBreakdown.of(
      items,
      state.settings,
      area: state.selectedAddress?.area ?? '',
    );
    final problem = price.problem(state.settings, status: state.ordering);
    final others = state.products
        .where((p) => p.inStock && cart.quantityOf(p.id) == 0)
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: const ScreenBack(),
        title: Text(cart.isEmpty ? 'Your cart' : 'Your cart (${cart.count})'),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: () => _confirmClear(context),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: cart.isEmpty
          ? EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Your cart is empty',
              message:
                  'Add a cylinder to get started. Most homes use the 11.8kg.',
              action: FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Browse cylinders'),
              ),
            )
          : Constrained(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  if (state.settings.freeDeliveryFrom > 0)
                    FreeDeliveryMeter(
                      subtotal: price.subtotal,
                      threshold: state.settings.freeDeliveryFrom,
                    ),
                  const SizedBox(height: 14),
                  for (final line in cart.lines)
                    if (state.productById(line.productId) case final p?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CartLineTile(product: p, line: line),
                      ),
                  if (price.emptiesHint(items) case final hint?) ...[
                    const SizedBox(height: 4),
                    _InfoBox(icon: Icons.autorenew_rounded, text: hint),
                  ],
                  if (others.isNotEmpty) ...[
                    const SectionTitle('Add more'),
                    SizedBox(
                      height:
                          112 +
                          (MediaQuery.textScalerOf(context).scale(14) - 14) *
                              12,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: others.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => _SuggestionCard(others[i]),
                      ),
                    ),
                  ],
                  const SectionTitle('Bill details'),
                  PriceSummary(price: price, settings: state.settings),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: context.pal.muted,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Prices are confirmed by Alpha LPG when your order is accepted.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.pal.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : CheckoutBar(
              total: price.total,
              caption:
                  '${price.cylinders} cylinder${price.cylinders == 1 ? '' : 's'}',
              label: 'Checkout',
              problem: problem,
              bulk: price.cylinders > state.settings.maxCylindersPerOrder,
              onPressed: () => context.push('/checkout'),
            ),
    );
  }
}

extension EmptiesHint on PriceBreakdown {
  String? emptiesHint(List<OrderItem> items) {
    final empties = items
        .where((i) => i.type == PurchaseType.refill)
        .fold(0, (n, i) => n + i.quantity);
    if (empties == 0) return null;
    return 'Refill price: please keep $empties empty cylinder${empties == 1 ? '' : 's'} '
        'of the same size ready. Our rider will swap ${empties == 1 ? 'it' : 'them'} for full ones.';
  }
}

/// Sticky bottom bar with the total and the primary action.
class CheckoutBar extends StatelessWidget {
  const CheckoutBar({
    super.key,
    required this.total,
    required this.caption,
    required this.label,
    required this.onPressed,
    this.problem,
    this.busy = false,
    this.bulk = false,
  });

  /// Too many cylinders for one order: offer the bulk-order request.
  final bool bulk;

  final int total;
  final String caption;
  final String label;
  final String? problem;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.pal.card,
      boxShadow: [
        BoxShadow(
          color: Brand.navy.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Constrained(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (problem != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    problem!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Brand.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (bulk)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => context.push('/bulk-quote'),
                      icon: const Icon(Icons.local_shipping_rounded),
                      label: const Text('Request a bulk order instead'),
                    ),
                  ),
                ),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatRupees(total),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        caption,
                        style: TextStyle(
                          color: context.pal.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: problem == null && !busy ? onPressed : null,
                      child: busy
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class FreeDeliveryMeter extends StatelessWidget {
  const FreeDeliveryMeter({
    super.key,
    required this.subtotal,
    required this.threshold,
  });
  final int subtotal;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    final done = subtotal >= threshold;
    final progress = (subtotal / threshold).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: done ? Brand.success.withValues(alpha: 0.1) : context.pal.tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done
                    ? Icons.celebration_rounded
                    : Icons.local_shipping_outlined,
                color: done ? Brand.success : Brand.blueDark,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: mu.Text.rich(
                  done
                      ? TextSpan(
                          text: tr('You get FREE delivery on this order'),
                        )
                      : TextSpan(
                          children: () {
                            final parts = tr('Add {} more for free delivery')
                                .split('{}');
                            return [
                              TextSpan(text: parts.first),
                              TextSpan(
                                text: formatRupees(threshold - subtotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(text: parts.length > 1 ? parts[1] : ''),
                            ];
                          }(),
                        ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 400),
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                color: done ? Brand.success : Brand.blueDark,
                backgroundColor: context.pal.card,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.product, required this.line});
  final Product product;
  final CartLine line;

  void _remove(BuildContext context) {
    final cart = context.read<Cart>();
    cart.setQuantity(line.productId, line.type, 0);
    Haptics.medium();
    showAppMessage(
      context,
      '${product.name} removed',
      actionLabel: 'Undo',
      onAction: () =>
          cart.setQuantity(line.productId, line.type, line.quantity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.read<Cart>();
    final unit = product.priceFor(line.type);
    return Dismissible(
      key: ValueKey(line.key),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _remove(context),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Brand.danger,
          borderRadius: BorderRadius.circular(Brand.radius),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.pal.card,
          borderRadius: BorderRadius.circular(Brand.radius),
          boxShadow: context.pal.shadow,
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 84,
              decoration: BoxDecoration(
                color: context.pal.tint,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(6),
              child: ProductImage(product, height: 72),
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
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Tag(
                        line.type.label,
                        color: context.pal.tint,
                        dark: !context.pal.isDark,
                      ),
                      Text(
                        '${formatRupees(unit)} each',
                        style: TextStyle(
                          color: context.pal.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (!product.inStock)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Out of stock: will be removed at checkout',
                        style: TextStyle(color: Brand.danger, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 6,
                    spacing: 8,
                    children: [
                      Text(
                        formatRupees(unit * line.quantity),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      QuantityStepper(
                        value: line.quantity,
                        onChanged: (q) {
                          Haptics.select();
                          if (q == 0) {
                            _remove(context);
                          } else {
                            cart.setQuantity(line.productId, line.type, q);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard(this.p);
  final Product p;

  @override
  Widget build(BuildContext context) => Container(
    width: 220,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: context.pal.card,
      borderRadius: BorderRadius.circular(Brand.radius),
      boxShadow: context.pal.shadow,
    ),
    child: Row(
      children: [
        Container(
          width: 64,
          height: double.infinity,
          decoration: BoxDecoration(
            color: context.pal.tint,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(6),
          child: ProductImage(p, height: 70),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                p.sizeLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                formatRupees(p.refillPrice),
                style: TextStyle(color: context.pal.muted, fontSize: 13),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 32,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    side: const BorderSide(color: Brand.blueDark),
                    foregroundColor: Brand.blueDark,
                  ),
                  onPressed: () {
                    Haptics.light();
                    context.read<Cart>().add(p.id, PurchaseType.refill);
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class PriceSummary extends StatelessWidget {
  const PriceSummary({super.key, required this.price, required this.settings});
  final PriceBreakdown price;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.pal.card,
      borderRadius: BorderRadius.circular(Brand.radius),
      boxShadow: context.pal.shadow,
    ),
    child: Column(
      children: [
        _row(
          context,
          'Cylinders (${price.cylinders})',
          formatRupees(price.subtotal),
        ),
        const SizedBox(height: 8),
        _row(
          context,
          'Delivery fee',
          price.freeDelivery ? 'FREE' : formatRupees(price.deliveryFee),
          valueColor: price.freeDelivery ? Brand.success : null,
          strike: price.freeDelivery && settings.deliveryFee > 0
              ? formatRupees(settings.deliveryFee)
              : null,
        ),
        if (price.couponDiscount > 0) ...[
          const SizedBox(height: 8),
          _row(
            context,
            'Discount code',
            '- ${formatRupees(price.couponDiscount)}',
            valueColor: Brand.success,
          ),
        ],
        if (price.pointsDiscount > 0) ...[
          const SizedBox(height: 8),
          _row(
            context,
            'Points used (${price.pointsUsed})',
            '- ${formatRupees(price.pointsDiscount)}',
            valueColor: Brand.success,
          ),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(),
        ),
        _row(context, 'To pay', formatRupees(price.total), bold: true),
      ],
    ),
  );

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
    String? strike,
  }) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 18 : 14,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        if (strike != null) ...[
          Text(
            strike,
            style: TextStyle(
              color: context.pal.muted,
              decoration: TextDecoration.lineThrough,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
        ],
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
      color: Brand.flame.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Brand.warning, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
      ],
    ),
  );
}
