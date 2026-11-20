import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../state/cart.dart';
import '../../theme/brand.dart';
import '../../utils/launch.dart';
import '../../widgets/address_picker.dart';
import '../../widgets/common.dart';
import '../../widgets/live.dart';
import 'product_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CustomerSegment _filter = CustomerSegment.both;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final products = state.products
        .where(
          (p) =>
              _filter == CustomerSegment.both ||
              p.segment == _filter ||
              p.segment == CustomerSegment.both,
        )
        .toList();
    final width = MediaQuery.sizeOf(context).width;
    final columns = width > 980 ? 4 : (width > 640 ? 3 : 2);

    return AnnotatedRegion(
      value: Brand.lightStatusBar,
      child: Scaffold(
        bottomNavigationBar: const CartBar(),
        body: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _Header()),
            SliverToBoxAdapter(
              child: Constrained(
                maxWidth: 980,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!state.settings.acceptingOrders)
                        _ClosedBanner(state.settings),
                      if (state.signedIn) const _OrderStrip(),
                      Text(
                        'Choose your cylinder',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      _SegmentFilter(
                        value: _filter,
                        onChanged: (v) => setState(() => _filter = v),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Constrained(
                maxWidth: 980,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: products.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      mainAxisExtent: 262,
                    ),
                    itemBuilder: (_, i) => _ProductCard(products[i]),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Constrained(
                maxWidth: 980,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BusinessCard(
                        isBusiness: state.profile?.isBusiness ?? false,
                      ),
                      const SizedBox(height: 14),
                      _HelpCard(settings: state.settings),
                      if (context.read<Backend>().isDemo) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Demo mode: nothing is saved, and orders move through each status automatically so you can see tracking.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Brand.muted),
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

// ---------------------------------------------------------------------------
// Header: logo, "Deliver to", headline, trust points.

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final address = state.selectedAddress;
    final name = state.profile?.name.split(' ').first;
    return Container(
      decoration: const BoxDecoration(
        gradient: Brand.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          // Oversized brand chevrons as a quiet background motif.
          Positioned(
            right: -30,
            top: 40,
            child: Row(
              children: [
                for (final o in [0.10, 0.08, 0.06])
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 120,
                    color: Colors.white.withValues(alpha: o),
                  ),
              ],
            ),
          ),
          SafeArea(
            bottom: false,
            child: Constrained(
              maxWidth: 980,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const BrandLogo(height: 42, white: true),
                        const Spacer(),
                        IconTheme(
                          data: const IconThemeData(color: Colors.white),
                          child: const CartButton(onDark: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _DeliverToPill(
                        title: address == null
                            ? (state.signedIn
                                  ? 'Add delivery address'
                                  : 'Lahore')
                            : '${address.label} · ${address.area}',
                        onTap: () => showAddressPicker(context),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      name == null || name.isEmpty
                          ? 'Need LPG today?'
                          : 'Salam $name, need LPG today?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Full, safety-checked cylinders delivered to your door across Lahore.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TrustChip(Icons.bolt_rounded, 'Same-day delivery'),
                        _TrustChip(Icons.verified_rounded, 'Sealed & weighed'),
                        _TrustChip(Icons.payments_outlined, 'Cash on delivery'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliverToPill extends StatelessWidget {
  const _DeliverToPill({required this.title, required this.onTap});
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.16),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_rounded, color: Brand.flame, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DELIVER TO',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
          ],
        ),
      ),
    ),
  );
}

class _TrustChip extends StatelessWidget {
  const _TrustChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Brand.flame),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------

class _SegmentFilter extends StatelessWidget {
  const _SegmentFilter({required this.value, required this.onChanged});
  final CustomerSegment value;
  final ValueChanged<CustomerSegment> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    clipBehavior: Clip.none,
    child: Row(
      children: [
        for (final (s, label, icon) in [
          (CustomerSegment.both, 'All', Icons.apps_rounded),
          (CustomerSegment.home, 'Home', Icons.home_rounded),
          (CustomerSegment.business, 'Commercial', Icons.storefront_rounded),
        ])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                icon,
                size: 16,
                color: value == s ? Colors.white : Brand.blueDark,
              ),
              label: Text(label),
              selected: value == s,
              showCheckmark: false,
              onSelected: (_) => onChanged(s),
            ),
          ),
      ],
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard(this.product);
  final Product product;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    final qty = cart.quantityOf(product.id, PurchaseType.refill);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Brand.radius),
        boxShadow: Brand.shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(Brand.radius),
          onTap: () => showProductSheet(context, product),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Brand.blueTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 26, 8, 6),
                            child: Hero(
                              tag: 'product-${product.id}',
                              child: ProductImage(product, height: 120),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          top: 8,
                          child: SizeBadge(product.sizeLabel),
                        ),
                        if (product.badge.isNotEmpty)
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: Tag(product.badge),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 4, 2),
                  child: Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatRupees(product.refillPrice),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              product.inStock ? 'Refill' : 'Out of stock',
                              style: TextStyle(
                                fontSize: 11,
                                color: product.inStock
                                    ? Brand.muted
                                    : Brand.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (qty == 0)
                        _RoundAdd(
                          enabled: product.inStock,
                          tooltip: 'Add ${product.name}',
                          onTap: () =>
                              cart.add(product.id, PurchaseType.refill),
                        )
                      else
                        _MiniStepper(
                          qty: qty,
                          onChanged: (q) => cart.setQuantity(
                            product.id,
                            PurchaseType.refill,
                            q,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundAdd extends StatelessWidget {
  const _RoundAdd({
    required this.enabled,
    required this.onTap,
    required this.tooltip,
  });
  final bool enabled;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: enabled ? Brand.blueDark : Brand.line,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: const SizedBox.square(
          dimension: 40,
          child: Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
    ),
  );
}

class _MiniStepper extends StatelessWidget {
  const _MiniStepper({required this.qty, required this.onChanged});
  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    decoration: BoxDecoration(
      color: Brand.navy,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepButton(Icons.remove_rounded, 'Decrease', () => onChanged(qty - 1)),
        Text(
          '$qty',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        _stepButton(Icons.add_rounded, 'Increase', () => onChanged(qty + 1)),
      ],
    ),
  );

  Widget _stepButton(IconData icon, String tip, VoidCallback onTap) => Tooltip(
    message: tip,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox.square(
        dimension: 34,
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    ),
  );
}

class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner(this.settings);
  final AppSettings settings;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Brand.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              settings.closedMessage.isNotEmpty ? settings.closedMessage : 'Online ordering is paused right now. Please call or WhatsApp us.',
            ),
          ),
        ],
      ),
    ),
  );
}

/// Live tracking card for an in-progress order, or a one-tap reorder of the
/// last completed one.
class _OrderStrip extends StatelessWidget {
  const _OrderStrip();

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final uid = context.select<AppState, String?>((s) => s.uid);
    if (uid == null) return const SizedBox.shrink();
    return Live<List<LpgOrder>>(
      cacheKey: uid,
      stream: () => backend.orders.watchCustomerOrders(uid, limit: 5),
      builder: (context, snap) {
        final orders = snap.data ?? const <LpgOrder>[];
        if (orders.isEmpty) return const SizedBox.shrink();
        final active = orders.where((o) => o.status.isActive).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: active.isNotEmpty
              ? _TrackingCard(active.first)
              : _ReorderCard(
                  orders.firstWhere(
                    (o) => o.status == OrderStatus.delivered,
                    orElse: () => orders.first,
                  ),
                ),
        );
      },
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard(this.o);
  final LpgOrder o;

  @override
  Widget build(BuildContext context) {
    final step = OrderStatus.journey.indexOf(o.status);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Brand.radius),
        boxShadow: Brand.shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(Brand.radius),
          onTap: () => context.push('/orders/${o.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Brand.blueTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        color: Brand.blueDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.status.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Order ${o.displayNumber}',
                            style: const TextStyle(
                              color: Brand.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'Track',
                      style: TextStyle(
                        color: Brand.blueDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Brand.blueDark,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < OrderStatus.journey.length; i++) ...[
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: 6,
                          decoration: BoxDecoration(
                            color: i <= step ? Brand.blueDark : Brand.line,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      if (i < OrderStatus.journey.length - 1)
                        const SizedBox(width: 4),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  o.status.description,
                  style: const TextStyle(color: Brand.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReorderCard extends StatelessWidget {
  const _ReorderCard(this.o);
  final LpgOrder o;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(Brand.radius),
      boxShadow: Brand.shadow,
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Brand.flame.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.history_rounded, color: Brand.navy),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Order again',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                o.items
                    .map(
                      (i) =>
                          '${i.quantity}× ${i.sizeKg == i.sizeKg.roundToDouble() ? i.sizeKg.toInt() : i.sizeKg}kg',
                    )
                    .join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Brand.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onPressed: () {
            context.read<Cart>().reorder(o);
            context.push('/cart');
          },
          child: const Text('Reorder'),
        ),
      ],
    ),
  );
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.isBusiness});
  final bool isBusiness;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Brand.navy,
      borderRadius: BorderRadius.circular(Brand.radius),
    ),
    clipBehavior: Clip.antiAlias,
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => context.push('/bulk-quote'),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              bottom: -26,
              child: Image.asset(
                'assets/products/45_4kg.png',
                height: 150,
                opacity: const AlwaysStoppedAnimation(0.9),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 110, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Tag('FOR BUSINESSES'),
                  const SizedBox(height: 10),
                  Text(
                    isBusiness
                        ? 'Get your business rate'
                        : 'Restaurant, hotel or factory?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Scheduled 45.4kg deliveries, bulk LPG and monthly billing.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Text(
                        'Request a quote',
                        style: TextStyle(
                          color: Brand.flame,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Brand.flame,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(Brand.radius),
      boxShadow: Brand.shadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Prefer to talk?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(settings.openingHours, style: const TextStyle(color: Brand.muted)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Brand.whatsapp,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Launch.whatsapp(
                  settings.whatsapp,
                  'Assalam-o-Alaikum, I would like to order LPG.',
                ),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('WhatsApp'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Launch.call(settings.phone),
                icon: const Icon(Icons.call_rounded),
                label: const Text('Call'),
              ),
            ),
          ],
        ),
        const Divider(height: 28),
        InkWell(
          onTap: () => context.push('/safety'),
          child: const Row(
            children: [
              Icon(Icons.health_and_safety_rounded, color: Brand.cylinderRed),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Smell gas? Read our safety guide',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Brand.muted),
            ],
          ),
        ),
      ],
    ),
  );
}
