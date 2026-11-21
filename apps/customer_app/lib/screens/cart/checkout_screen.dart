import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../state/cart.dart';
import '../../theme/brand.dart';
import '../../utils/format.dart';
import '../../widgets/address_picker.dart';
import '../../widgets/common.dart';
import '../../widgets/payment.dart';
import '../../widgets/slide_to_confirm.dart';
import 'cart_screen.dart';
import '../../utils/haptics.dart';

enum DeliverySlot {
  morning('Morning', 9, 12),
  afternoon('Afternoon', 12, 16),
  evening('Evening', 16, 21);

  const DeliverySlot(this.label, this.from, this.to);
  final String label;
  final int from;
  final int to;

  String get range => '${_h(from)}–${_h(to)}';
  static String _h(int h) => '${h > 12 ? h - 12 : h}${h >= 12 ? 'pm' : 'am'}';
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _asap = true;
  DateTime _day = DateTime.now();
  DeliverySlot _slot = DeliverySlot.morning;
  PaymentMethod _payment = PaymentMethod.cashOnDelivery;
  final _reference = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addAddress() async {
    final state = context.read<AppState>();
    final a = await context.push<Address>('/location');
    if (a != null) state.selectAddress(a.id);
  }

  Future<bool> _place() async {
    final state = context.read<AppState>();
    final backend = context.read<Backend>();
    final cart = context.read<Cart>();
    final profile = state.profile;
    final address = state.selectedAddress;
    if (profile == null) return false;
    if (address == null) {
      showMessage(context, 'Please set your delivery location', error: true);
      return false;
    }
    final items = cart.toOrderItems(state.productById);
    final price = PriceBreakdown.of(items, state.settings);
    final problem = price.problem(state.settings, status: state.ordering);
    if (problem != null) {
      showMessage(context, problem, error: true);
      return false;
    }

    if (_payment.isPrepaid) {
      final tidProblem = validateTransactionId(_reference.text);
      if (tidProblem != null) {
        showMessage(context, tidProblem, error: true);
        return false;
      }
    }
    Haptics.medium();
    try {
      final id = await backend.orders.place(
        LpgOrder(
          customerId: profile.uid,
          customerName: profile.name,
          customerPhone: profile.phone,
          customerType: profile.type,
          businessName: profile.businessName,
          items: items,
          subtotal: price.subtotal,
          deliveryFee: price.deliveryFee,
          total: price.total,
          address: address,
          paymentMethod: _payment,
          paymentReference: _payment.isPrepaid ? _reference.text.trim() : '',
          scheduledFor: _asap
              ? null
              : DateTime(_day.year, _day.month, _day.day, _slot.from),
          notes: [
            if (!_asap) 'Slot: ${_slot.label} ${_slot.range}',
            if (_notes.text.trim().isNotEmpty) _notes.text.trim(),
          ].join('\n'),
        ),
      );
      cart.clear();
      if (mounted) context.go('/order-placed/$id');
      return true;
    } catch (e) {
      if (mounted) {
        final denied = '$e'.contains('permission-denied');
        showMessage(
          context,
          denied
              ? 'Alpha LPG could not accept this order. Prices or settings may have just changed. Go back to the cart and try again, or call the shop.'
              : 'Could not place order. Check your internet and try again.',
          error: true,
        );
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cart = context.watch<Cart>();
    final items = cart.toOrderItems(state.productById);
    final price = PriceBreakdown.of(items, state.settings);
    final address = state.selectedAddress;
    final today = DateTime.now();
    final days = [for (var i = 0; i < 4; i++) today.add(Duration(days: i))];
    final slots = DeliverySlot.values
        .where((s) => !_isSameDay(_day, today) || s.to > today.hour + 1)
        .toList();
    if (!slots.contains(_slot) && slots.isNotEmpty) _slot = slots.first;

    return Scaffold(
      appBar: AppBar(
        leading: const ScreenBack(),
        title: const Text('Checkout'),
      ),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _Section(
              number: 1,
              title: 'Delivery address',
              trailing: address == null
                  ? null
                  : TextButton(
                      onPressed: () => showAddressPicker(context),
                      child: const Text('Change'),
                    ),
              child: address == null
                  ? ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: context.pal.tint,
                        child: Icon(
                          Icons.add_location_alt_rounded,
                          color: Brand.blueDark,
                        ),
                      ),
                      title: const Text(
                        'Add a delivery address',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _addAddress,
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          address.hasLocation
                              ? Icons.location_on_rounded
                              : Icons.location_on_outlined,
                          color: address.hasLocation
                              ? Brand.success
                              : Brand.blueDark,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                address.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                address.oneLine,
                                style: TextStyle(color: context.pal.muted),
                              ),
                              if (state.profile != null)
                                Text(
                                  '${state.profile!.name} · ${prettyPkMobile(state.profile!.phone)}',
                                  style: TextStyle(
                                    color: context.pal.muted,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            _Section(
              number: 2,
              title: 'Delivery time',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ChoiceTile(
                          icon: Icons.bolt_rounded,
                          title: 'Now',
                          subtitle: 'Usually 1–3 hours',
                          selected: _asap,
                          onTap: () => setState(() => _asap = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ChoiceTile(
                          icon: Icons.event_rounded,
                          title: 'Schedule',
                          subtitle: 'Pick a day & slot',
                          selected: !_asap,
                          onTap: () => setState(() => _asap = false),
                        ),
                      ),
                    ],
                  ),
                  if (!_asap) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final d in days)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  _isSameDay(d, today) ? 'Today' : formatDay(d),
                                ),
                                selected: _isSameDay(d, _day),
                                showCheckmark: false,
                                onSelected: (_) => setState(() => _day = d),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (slots.isEmpty)
                      const Text(
                        'No slots left today. Please pick another day.',
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in slots)
                            ChoiceChip(
                              label: Text('${s.label} ${s.range}'),
                              selected: _slot == s,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _slot = s),
                            ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
            _Section(
              number: 3,
              title: 'Payment',
              child: PaymentMethodPicker(
                value: _payment,
                settings: state.settings,
                total: price.total,
                reference: _reference,
                onChanged: (m) => setState(() => _payment = m),
              ),
            ),
            _Section(
              number: 4,
              title: 'Notes for the rider',
              child: TextField(
                controller: _notes,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'e.g. Call on arrival, 2nd floor, gate code…',
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: context.pal.card,
                borderRadius: BorderRadius.circular(Brand.radius),
                boxShadow: context.pal.shadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: const Icon(
                    Icons.receipt_long_rounded,
                    color: Brand.blueDark,
                  ),
                  title: Text(
                    'Order summary · ${price.cylinders} cylinder${price.cylinders == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    for (final i in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${i.quantity} × ${i.name} (${i.type.label})',
                              ),
                            ),
                            Text(formatRupees(i.lineTotal)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            PriceSummary(price: price, settings: state.settings),
            const SizedBox(height: 12),
            Text(
              'By placing this order you agree to keep empty cylinders ready for refill orders. '
              'Alpha LPG will confirm your order and final price.',
              style: TextStyle(fontSize: 12, color: context.pal.muted),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _SlideBar(
        total: price.total,
        caption: _payment.label,
        problem: items.isEmpty ? 'Your cart is empty.' : null,
        onConfirmed: _place,
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Section extends StatelessWidget {
  const _Section({
    required this.number,
    required this.title,
    required this.child,
    this.trailing,
  });

  final int number;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
      decoration: BoxDecoration(
        color: context.pal.card,
        borderRadius: BorderRadius.circular(Brand.radius),
        boxShadow: context.pal.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Brand.navy,
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Lets list-tile ripples paint on top of the card colour.
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    ),
  );
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? context.pal.tint : context.pal.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: selected ? Brand.blueDark : context.pal.line,
        width: selected ? 1.5 : 1,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: selected ? Brand.blueDark : context.pal.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: context.pal.muted, fontSize: 12),
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

/// Sticky bottom bar: the total, and a slide-to-order control.
class _SlideBar extends StatelessWidget {
  const _SlideBar({
    required this.total,
    required this.caption,
    required this.onConfirmed,
    this.problem,
  });

  final int total;
  final String caption;
  final String? problem;
  final Future<bool> Function() onConfirmed;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.pal.card,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: context.pal.isDark ? 0.4 : 0.08,
          ),
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
                    style: const TextStyle(
                      color: Brand.danger,
                      fontWeight: FontWeight.w600,
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
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(
                        width: 96,
                        child: Text(
                          caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.pal.muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SlideToConfirm(
                      label: 'Slide to order',
                      enabled: problem == null,
                      onConfirmed: onConfirmed,
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
