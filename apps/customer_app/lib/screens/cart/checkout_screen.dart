import 'package:alpha_core/alpha_core.dart';

import '../../l10n/lang.dart';

import 'package:alpha_ui/alpha_ui.dart' as ui;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart' hide Text;

import '../../l10n/text.dart';

import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../state/cart.dart';
import '../../state/promo_state.dart';
import '../../widgets/promo_panel.dart';
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
  final _notes = TextEditingController();
  final _tid = TextEditingController();

  /// Payment screenshot (base64) the customer attached for an online payment.
  String? _proof;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    // Start with the way the customer paid last time.
    _payment = context.read<AppState>().lastPayment;
  }

  @override
  void dispose() {
    _notes.dispose();
    _tid.dispose();
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
    final items = cart.toOrderItems(state.productById);
    final promo = context.read<PromoState>();
    final price = promo.priced(
      PriceBreakdown.of(
        items,
        state.settings,
        area: state.selectedAddress?.area ?? '',
      ),
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
          // The verified sign-in number wins: the shop's rules compare it with
          // the phone number on the order.
          customerPhone: (backend.auth.phone ?? '').isNotEmpty
              ? backend.auth.phone!
              : profile.phone,
          customerType: profile.type,
          businessName: profile.businessName,
          items: items,
          subtotal: price.subtotal,
          deliveryFee: price.deliveryFee,
          total: price.total,
          couponCode: price.couponDiscount > 0 ? promo.coupon!.code : '',
          couponDiscount: price.couponDiscount,
          pointsUsed: price.pointsUsed,
          pointsDiscount: price.pointsDiscount,
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
      // Online payment: the proof travels with the order.
      if (_payment.isPrepaid && _hasProof) {
        try {
          await backend.orders.submitPayment(
            id,
            uid: profile.uid,
            reference: _tid.text.trim(),
            amount: price.total,
            data: _proof,
          );
          await backend.orders.sendMessage(
            id,
            uid: profile.uid,
            role: MessageRole.customer,
            name: 'Customer',
            text:
                '📎 I paid ${formatRupees(price.total)} via ${_payment.label}. Transaction ID: ${_tid.text.trim()}.',
          );
        } catch (_) {
          // The order is placed; the proof can be sent again from the order.
        }
      }
      cart.clear();
      promo.clear();
      promo.afterOrder();
      if (mounted) context.go('/order-placed/$id');
      return true;
    } catch (e) {
      if (mounted) {
        final denied = '$e'.contains('permission-denied');
        final why = denied ? _whyRefused(state, items, profile.phone) : null;
        showMessage(
          context,
          denied
              ? 'Alpha LPG could not accept this order. ${why ?? 'Prices or settings may have just changed. Go back to the cart and try again, or call the shop.'}'
              : 'Could not place order. Check your internet and try again.',
          error: true,
        );
      }
    }
    return false;
  }

  /// The shop's database refused the order. Find the likely reason on this
  /// phone so the customer (and we) are not left guessing.
  String? _whyRefused(AppState state, List<OrderItem> items, String phone) {
    final auth = context.read<Backend>().auth.phone ?? '';
    final number = auth.isNotEmpty ? auth : phone;
    if (!RegExp(r'^\+923[0-9]{9}$').hasMatch(number)) {
      return 'Your phone number ($number) is not a valid Pakistani mobile number. Sign out and sign in again with your number.';
    }
    for (final i in items) {
      final p = state.productById(i.productId);
      if (p == null)
        return '${i.name} is no longer in the catalogue. Remove it from the cart.';
      if (p.priceFor(i.type) != i.unitPrice) {
        return 'The price of ${i.name} just changed. Go back to the cart and try again.';
      }
    }
    return null;
  }

  bool get _hasProof => _proof != null && _tid.text.trim().length >= 4;

  Future<void> _pickProof() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose a screenshot'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2200,
        imageQuality: 90,
      );
      if (file == null) return;
      setState(() => _picking = true);
      final data = await ui.compressReceiptPhoto(await file.readAsBytes());
      if (mounted) setState(() => _proof = data);
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is String ? e : 'Could not use that picture.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showMessage(context, 'Copied');
  }

  /// "When": as soon as possible, or a day and a time slot.
  Future<void> _chooseTime() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheet) {
        void both(VoidCallback f) {
          setState(f);
          setSheet(() {});
        }

        final today = DateTime.now();
        final days = [for (var i = 0; i < 4; i++) today.add(Duration(days: i))];
        final slots = DeliverySlot.values
            .where((x) => !_isSameDay(_day, today) || x.to > today.hour + 1)
            .toList();
        if (!slots.contains(_slot) && slots.isNotEmpty) _slot = slots.first;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Delivery time',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                ),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _WhenTile(
                          icon: Icons.bolt_rounded,
                          title: 'As soon as possible',
                          subtitle: 'We confirm, then send a rider',
                          selected: _asap,
                          onTap: () => both(() => _asap = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _WhenTile(
                          icon: Icons.event_available_rounded,
                          title: 'Schedule',
                          subtitle: 'Choose a day and a time',
                          selected: !_asap,
                          onTap: () => both(() => _asap = false),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_asap) ...[
                  const SizedBox(height: 16),
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
                            onTap: () => both(() => _day = d),
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
                                right: sl == DeliverySlot.values.last ? 0 : 8,
                              ),
                              child: _SlotTile(
                                slot: sl,
                                enabled: slots.contains(sl),
                                selected: _slot == sl,
                                onTap: () => both(() => _slot = sl),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(sheet),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  /// "Pay with": cash, or one of the online methods.
  Future<void> _choosePayment(AppState state, int total) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Pay with',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                ),
                const SizedBox(height: 12),
                PaymentMethodPicker(
                  value: _payment,
                  settings: state.settings,
                  total: total,
                  onChanged: (m) {
                    state.setLastPayment(m);
                    setState(() => _payment = m);
                    Navigator.pop(sheet);
                  },
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cart = context.watch<Cart>();
    final items = cart.toOrderItems(state.productById);
    final promo = context.watch<PromoState>();
    final base = PriceBreakdown.of(
      items,
      state.settings,
      area: state.selectedAddress?.area ?? '',
    );
    final price = promo.priced(base);
    final address = state.selectedAddress;
    final today = DateTime.now();
    final slots = DeliverySlot.values
        .where((s) => !_isSameDay(_day, today) || s.to > today.hour + 1)
        .toList();
    if (!slots.contains(_slot) && slots.isNotEmpty) _slot = slots.first;
    final pal = context.pal;

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
        ? ('Add your delivery location first.', 'Add delivery location')
        : (!_asap && slots.isEmpty)
        ? (
            'No delivery slot left on this day. Choose another day.',
            'Choose a delivery time',
          )
        : switch (price.problem(state.settings, status: state.ordering)) {
            final String p => (p, 'Cannot order yet'),
            null => (null, 'Slide to place order'),
          };

    final account = _payment.accountIn(state.settings).trim();

    Widget row({
      Key? key,
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      String action = 'Change',
    }) => InkWell(
      key: key,
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: pal.tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: pal.blue, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: pal.muted,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              action,
              style: TextStyle(
                color: pal.blue,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );

    Widget card(List<Widget> children) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(Brand.radius),
        border: Border.all(color: pal.line),
      ),
      child: Column(children: children),
    );

    return Scaffold(
      appBar: AppBar(
        leading: const ScreenBack(),
        title: const Text('Checkout'),
      ),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            card([
              row(
                key: const Key('address-row'),
                icon: Icons.location_on_outlined,
                title: address == null
                    ? 'Add a delivery address'
                    : 'Deliver to ${address.label}',
                subtitle: address == null
                    ? 'We need to know where to bring it'
                    : '${address.oneLine}${state.profile == null ? '' : '\n${state.profile!.name} · ${prettyPkMobile(state.profile!.phone)}'}',
                action: address == null ? 'Add' : 'Change',
                onTap: address == null
                    ? _addAddress
                    : () => showAddressPicker(context),
              ),
              Divider(height: 1, color: pal.line),
              row(
                key: const Key('time-row'),
                icon: Icons.schedule_rounded,
                title: _asap
                    ? 'As soon as possible'
                    : '${_isSameDay(_day, today) ? 'Today' : formatDay(_day)}, ${_slot.label}',
                subtitle: _asap
                    ? 'We confirm your order, then send a rider'
                    : _slot.range,
                onTap: _chooseTime,
              ),
              Divider(height: 1, color: pal.line),
              row(
                key: const Key('pay-row'),
                icon: _payment.icon,
                title: _payment.label,
                subtitle: _payment.tagline,
                onTap: () => _choosePayment(state, price.total),
              ),
            ]),

            // Online payment: pay first, and send the proof with the order.
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              alignment: Alignment.topCenter,
              child: !_payment.isPrepaid
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: pal.card,
                        borderRadius: BorderRadius.circular(Brand.radius),
                        border: Border.all(color: pal.line),
                      ),
                      child: account.isEmpty
                          ? Text(
                              'Alpha LPG sends the ${_payment.label} account to your order screen right after you place the order. Pay it there and send the receipt.',
                              style: TextStyle(color: pal.muted, height: 1.45),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Pay ${formatRupees(price.total)} with ${_payment.label}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _CopyRow(
                                  label: 'Send to',
                                  value: account,
                                  onCopy: () => _copy(account),
                                ),
                                _CopyRow(
                                  label: 'Amount',
                                  value: formatRupees(price.total),
                                  onCopy: () => _copy('${price.total}'),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Pay in your ${_payment.label} app, then add the proof here. You can also place the order now and add it later.',
                                  style: TextStyle(
                                    color: pal.muted,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: _picking ? null : _pickProof,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _proof == null
                                            ? pal.line
                                            : pal.green,
                                        width: _proof == null ? 1.5 : 2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _proof == null
                                              ? Icons.cloud_upload_outlined
                                              : Icons.check_circle_rounded,
                                          color: _proof == null
                                              ? pal.muted
                                              : pal.green,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          _picking
                                              ? 'Adding…'
                                              : _proof == null
                                              ? 'Add payment screenshot'
                                              : 'Screenshot added. Tap to change',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _tid,
                                  onChanged: (_) => setState(() {}),
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    labelText: tr('Transaction ID'),
                                    hintText: 'TID-982347102',
                                    prefixIcon: const Icon(Icons.tag_rounded),
                                  ),
                                ),
                              ],
                            ),
                    ),
            ),

            // Order summary.
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pal.card,
                borderRadius: BorderRadius.circular(Brand.radius),
                border: Border.all(color: pal.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Order summary · ${price.countLabel}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final i in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${i.quantity} × ${i.name} (${i.typeLabel})',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(formatRupees(i.lineTotal)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  PriceSummary(price: price, settings: state.settings),
                ],
              ),
            ),

            // Optional extras, tucked away.
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: pal.card,
                borderRadius: BorderRadius.circular(Brand.radius),
                border: Border.all(color: pal.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const Key('discounts-tile'),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: Icon(Icons.local_offer_outlined, color: pal.blue),
                  title: const Text(
                    'Have a code or points?',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  children: [
                    PromoPanel(subtotal: base.subtotal, lines: base.lines),
                  ],
                ),
              ),
            ),
            TextField(
              controller: _notes,
              maxLines: 2,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.sticky_note_2_outlined),
                hintText: tr('Note for the rider (optional)'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'By placing this order you agree to keep empty cylinders ready for refill orders. '
              'Alpha LPG will confirm your order and final price.',
              style: TextStyle(fontSize: 12, color: pal.muted),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _SlideBar(
        total: price.total,
        caption: _payment.isPrepaid && _hasProof
            ? '${_payment.label} · proof added'
            : _payment.label,
        problem: problem,
        label: lockLabel,
        onConfirmed: _place,
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// "Send to / 0300…  [Copy]".
class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });
  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: pal.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: pal.muted, fontSize: 12.5)),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }
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
        color: selected ? pal.tint : pal.surface,
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
                      color: selected ? context.pal.blue : pal.line,
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
    final fg = !enabled ? pal.muted : (selected ? Brand.blueDark : pal.ink);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: selected ? pal.tint : pal.surface,
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
                    style: TextStyle(
                      color: context.pal.red,
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
