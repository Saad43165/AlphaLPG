import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../state/cart.dart';
import '../../theme/brand.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import 'cart_screen.dart';

enum DeliverySlot {
  morning('Morning', 9, 12),
  afternoon('Afternoon', 12, 16),
  evening('Evening', 16, 21);

  const DeliverySlot(this.label, this.from, this.to);
  final String label;
  final int from;
  final int to;

  String get range => '${_h(from)} – ${_h(to)}';
  static String _h(int h) => '${h > 12 ? h - 12 : h} ${h >= 12 ? 'pm' : 'am'}';
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String? _addressId;
  bool _asap = true;
  DateTime _day = DateTime.now();
  DeliverySlot _slot = DeliverySlot.morning;
  PaymentMethod _payment = PaymentMethod.cashOnDelivery;
  final _notes = TextEditingController();
  bool _placing = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Address? _selectedAddress(List<Address> all) {
    if (all.isEmpty) return null;
    return all.firstWhere((a) => a.id == _addressId, orElse: () => all.last);
  }

  Future<void> _addAddress() async {
    final a = await context.push<Address>('/account/addresses/new');
    if (a != null) setState(() => _addressId = a.id);
  }

  Future<void> _place() async {
    final state = context.read<AppState>();
    final backend = context.read<Backend>();
    final cart = context.read<Cart>();
    final profile = state.profile;
    final address = _selectedAddress(state.addresses);
    if (profile == null) return;
    if (address == null) {
      showMessage(context, 'Please add a delivery address', error: true);
      return;
    }
    final items = cart.toOrderItems(state.productById);
    final price = PriceBreakdown.of(items, state.settings);
    final problem = price.problem(state.settings);
    if (problem != null) {
      showMessage(context, problem, error: true);
      return;
    }

    setState(() => _placing = true);
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
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          'Could not place order. Please try again.\n$e',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cart = context.watch<Cart>();
    final items = cart.toOrderItems(state.productById);
    final price = PriceBreakdown.of(items, state.settings);
    final address = _selectedAddress(state.addresses);
    final today = DateTime.now();
    final days = [for (var i = 0; i < 4; i++) today.add(Duration(days: i))];
    final slots = DeliverySlot.values
        .where((s) => !_isSameDay(_day, today) || s.to > today.hour + 1)
        .toList();
    if (!slots.contains(_slot) && slots.isNotEmpty) _slot = slots.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionTitle(
              'Deliver to',
              trailing: TextButton.icon(
                onPressed: _addAddress,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New'),
              ),
            ),
            if (state.addresses.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.add_location_alt_outlined,
                    color: Brand.blueDark,
                  ),
                  title: const Text('Add a delivery address'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _addAddress,
                ),
              )
            else
              Card(
                child: RadioGroup<String>(
                  groupValue: address?.id,
                  onChanged: (v) => setState(() => _addressId = v),
                  child: Column(
                    children: [
                      for (final a in state.addresses)
                        RadioListTile<String>(
                          value: a.id,
                          title: Text(
                            a.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(a.oneLine),
                          secondary: a.hasLocation
                              ? const Icon(
                                  Icons.location_on,
                                  color: Brand.success,
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
              ),
            const SectionTitle('Delivery time'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.bolt),
                          label: Text('Deliver now'),
                        ),
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.event),
                          label: Text('Schedule'),
                        ),
                      ],
                      selected: {_asap},
                      onSelectionChanged: (s) =>
                          setState(() => _asap = s.first),
                    ),
                    if (!_asap) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final d in days)
                            ChoiceChip(
                              label: Text(
                                _isSameDay(d, today) ? 'Today' : formatDay(d),
                              ),
                              selected: _isSameDay(d, _day),
                              onSelected: (_) => setState(() => _day = d),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (slots.isEmpty)
                        const Text(
                          'No slots left today — please pick another day.',
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in slots)
                              ChoiceChip(
                                label: Text('${s.label} · ${s.range}'),
                                selected: _slot == s,
                                onSelected: (_) => setState(() => _slot = s),
                              ),
                          ],
                        ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'Usually delivered within 1–3 hours during opening hours.',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SectionTitle('Payment'),
            Card(
              child: RadioGroup<PaymentMethod>(
                groupValue: _payment,
                onChanged: (v) => setState(() => _payment = v!),
                child: Column(
                  children: [
                    for (final m in PaymentMethod.available)
                      RadioListTile<PaymentMethod>(
                        value: m,
                        title: Text(m.label),
                        subtitle: Text(switch (m) {
                          PaymentMethod.cashOnDelivery => 'Pay the rider in cash when you receive your cylinders',
                          PaymentMethod.bankTransfer =>
                            state.settings.bankDetails.isNotEmpty
                                ? state.settings.bankDetails
                                : 'We will send account details on WhatsApp',
                          _ => '',
                        }),
                      ),
                    const ListTile(
                      dense: true,
                      leading: Icon(Icons.schedule, size: 18),
                      title: Text('JazzCash & Easypaisa coming soon'),
                    ),
                  ],
                ),
              ),
            ),
            const SectionTitle('Notes for the rider'),
            TextField(
              controller: _notes,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Call on arrival, 2nd floor, gate code…',
              ),
            ),
            const SectionTitle('Order summary'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final i in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
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
            const SizedBox(height: 10),
            PriceSummary(price: price, settings: state.settings),
            const SizedBox(height: 90),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Constrained(
            child: FilledButton(
              onPressed: _placing || items.isEmpty ? null : _place,
              child: _placing
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text('Place order · ${formatRupees(price.total)}'),
            ),
          ),
        ),
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
