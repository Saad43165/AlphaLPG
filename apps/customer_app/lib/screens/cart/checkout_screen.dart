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

/// Orders one customer may have in progress at the same time.
const maxOpenOrders = 3;

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
  final _notes = TextEditingController();

  @override
  void dispose() {
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
    if (state.blocked != null) {
      showMessage(
        context,
        'Alpha LPG cannot take orders from this account right now. Please call ${state.settings.phone}.',
        error: true,
      );
      return false;
    }
    // At most 3 orders in progress at once (stops accidental or spam orders).
    if (state.openOrders >= maxOpenOrders) {
      showMessage(
        context,
        'You already have ${state.openOrders} orders on the way. Please wait for one to be delivered, or call ${state.settings.phone}.',
        error: true,
      );
      return false;
    }
    final items = cart.toOrderItems(state.productById);
    final price = PriceBreakdown.of(
      items,
      state.settings,
      area: state.selectedAddress?.area ?? '',
    );
    final problem = price.problem(state.settings, status: state.ordering);
    if (problem != null) {
      showMessage(context, problem, error: true);
      return false;
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
    final price = PriceBreakdown.of(
      items,
      state.settings,
      area: state.selectedAddress?.area ?? '',
    );
    final address = state.selectedAddress;
    final today = DateTime.now();
    final days = [for (var i = 0; i < 4; i++) today.add(Duration(days: i))];
    final slots = DeliverySlot.values
        .where((s) => !_isSameDay(_day, today) || s.to > today.hour + 1)
        .toList();
    if (!slots.contains(_slot) && slots.isNotEmpty) _slot = slots.first;

    // Everything needed before the order can be placed. The slide stays
    // locked (with the reason on it) until all of it is done.
    final (String? problem, String lockLabel) = items.isEmpty
        ? ('Your cart is empty.', 'Cart is empty')
        : state.blocked != null
        ? (
            'This account cannot place orders. Please call ${state.settings.phone}.',
            'Ordering not available',
          )
        : address == null
        ? ('Add your delivery location in step 1.', 'Add delivery location')
        : (!_asap && slots.isEmpty)
        ? (
            'No delivery slot left on this day. Choose another day.',
            'Choose a delivery time',
          )
        : state.openOrders >= maxOpenOrders
        ? (
            'You already have ${state.openOrders} orders on the way. Please wait for one to arrive.',
            'Too many open orders',
          )
        : switch (price.problem(state.settings, status: state.ordering)) {
            final String p => (p, 'Cannot order yet'),
            null => (null, 'Slide to place order'),
          };

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
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _WhenTile(
                            icon: Icons.bolt_rounded,
                            title: 'As soon as possible',
                            subtitle:
                                'We confirm your order, then send a rider',
                            selected: _asap,
                            onTap: () => setState(() => _asap = true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _WhenTile(
                            icon: Icons.event_available_rounded,
                            title: 'Schedule',
                            subtitle: 'Choose a day and a time slot',
                            selected: !_asap,
                            onTap: () => setState(() => _asap = false),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _asap
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Day',
                                  style: TextStyle(
                                    color: context.pal.muted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 72,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      for (final d in days)
                                        _DayCard(
                                          day: d,
                                          isToday: _isSameDay(d, today),
                                          selected: _isSameDay(d, _day),
                                          onTap: () => setState(() => _day = d),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Time',
                                  style: TextStyle(
                                    color: context.pal.muted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (slots.isEmpty)
                                  const Text(
                                    'No time slots left today. Please pick another day.',
                                  )
                                else
                                  Row(
                                    children: [
                                      for (final sl in DeliverySlot.values)
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              right:
                                                  sl == DeliverySlot.values.last
                                                  ? 0
                                                  : 8,
                                            ),
                                            child: _SlotTile(
                                              slot: sl,
                                              enabled: slots.contains(sl),
                                              selected: _slot == sl,
                                              onTap: () =>
                                                  setState(() => _slot = sl),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Brand.blueDark.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.event_available_rounded,
                                        color: Brand.blueDark,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          slots.isEmpty
                                              ? 'Pick another day'
                                              : 'Delivery on ${_isSameDay(_day, today) ? 'today' : formatDay(_day)}, ${_slot.label.toLowerCase()} ${_slot.range}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
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
        problem: problem,
        label: lockLabel,
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

/// "As soon as possible" / "Schedule": two equal cards with a clear tick.
class _WhenTile extends StatelessWidget {
  const _WhenTile({
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
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? Brand.blueDark.withValues(alpha: 0.1) : pal.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? Brand.blueDark : pal.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: selected ? Brand.blueDark : pal.tint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 21,
                        color: selected ? Colors.white : pal.muted,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 22,
                      color: selected ? Brand.blueDark : pal.line,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: pal.muted, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One day in the scrolling day picker: "Sun" over "22".
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });
  final DateTime day;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;

  static const _names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? Brand.blueDark : pal.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? Brand.blueDark : pal.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isToday ? 'Today' : _names[day.weekday - 1],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white70 : pal.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : pal.ink,
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

/// Morning / Afternoon / Evening, three equal tiles (greyed out when passed).
class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });
  final DeliverySlot slot;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final icon = switch (slot) {
      DeliverySlot.morning => Icons.wb_twilight_rounded,
      DeliverySlot.afternoon => Icons.wb_sunny_rounded,
      DeliverySlot.evening => Icons.nights_stay_rounded,
    };
    final fg = !enabled
        ? pal.muted.withValues(alpha: 0.5)
        : (selected ? Brand.blueDark : pal.ink);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: selected ? Brand.blueDark.withValues(alpha: 0.1) : pal.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? Brand.blueDark : pal.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              children: [
                Icon(icon, size: 22, color: fg),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    slot.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: fg,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    slot.range,
                    style: TextStyle(color: pal.muted, fontSize: 12),
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

/// Sticky bottom bar: the total, and a slide-to-order control.
class _SlideBar extends StatelessWidget {
  const _SlideBar({
    required this.total,
    required this.caption,
    required this.onConfirmed,
    this.problem,
    this.label = 'Slide to place order',
  });

  final int total;
  final String caption;
  final String? problem;

  /// The words on the slide (the reason while it is locked).
  final String label;
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
                      label: label,
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
