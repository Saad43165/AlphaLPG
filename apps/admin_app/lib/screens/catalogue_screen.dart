import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/order_x.dart';
import '../widgets/common.dart';

/// Prices, stock and shop settings: everything the customer app reads live.
class CatalogueScreen extends StatelessWidget {
  const CatalogueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final st = s.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: panel(context),
              child: Row(
                children: [
                  Icon(
                    st.acceptingOrders ? Icons.storefront_rounded : Icons.pause_circle_rounded,
                    color: st.acceptingOrders ? Brand.success : Brand.danger,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          st.acceptingOrders ? 'Taking orders' : 'Orders paused',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          st.acceptingOrders
                              ? 'Customers can place orders.'
                              : 'Customers see your closed message.',
                          style: TextStyle(color: context.pal.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: st.acceptingOrders,
                    onChanged: (v) async {
                      final err = await s.saveSettings(_copy(st, acceptingOrders: v));
                      if (err != null && context.mounted) showMessage(context, err, error: true);
                    },
                  ),
                ],
              ),
            ),
            const Heading('Cylinders and prices'),
            if (!s.storeReady)
              _Defaults(session: s),
            for (final p in s.products)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: Ink(
                    decoration: panel(context),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Brand.radius),
                      onTap: () => _editProduct(context, p),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Refill ${rs(p.refillPrice)}'
                                    '${p.newCylinderPrice != null ? '  ·  New ${rs(p.newCylinderPrice!)}' : ''}',
                                    style: TextStyle(color: context.pal.muted, fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      if (!p.active) const Pill(Icons.visibility_off_rounded, 'Hidden', color: Brand.danger),
                                      if (p.active && !p.inStock)
                                        const Pill(Icons.remove_shopping_cart_rounded, 'Out of stock', color: Color(0xFF8A6D00)),
                                      if (p.active && p.inStock) const Pill(Icons.check_rounded, 'On sale', color: Brand.success),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.edit_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => _editProduct(context, null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add a cylinder size'),
            ),
            const Heading('Delivery, hours and payments'),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsEditor()),
              ),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Edit shop settings'),
            ),
          ],
        ),
      ),
    );
  }

  static AppSettings _copy(AppSettings s, {bool? acceptingOrders}) =>
      AppSettings.fromMap({...s.toMap(), 'acceptingOrders': acceptingOrders ?? s.acceptingOrders});

  void _editProduct(BuildContext context, Product? p) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProductEditor(product: p),
  );
}

class _Defaults extends StatefulWidget {
  const _Defaults({required this.session});
  final AdminSession session;

  @override
  State<_Defaults> createState() => _DefaultsState();
}

class _DefaultsState extends State<_Defaults> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: panel(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nothing here yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 6),
        Text(
          'Customers cannot order until the cylinders and shop settings exist. '
          'Load the four cylinders from alphalpg.pk, then check every price and the delivery fee.',
          style: TextStyle(color: context.pal.muted, height: 1.4),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  final err = await widget.session.loadDefaults();
                  if (!context.mounted) return;
                  setState(() => _busy = false);
                  showMessage(
                    context,
                    err ?? 'Loaded. Now review the prices and edit the shop settings.',
                    error: err != null,
                  );
                },
          child: Text(_busy ? 'Loading…' : 'Load the default catalogue'),
        ),
      ],
    ),
  );
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({this.product});
  final Product? product;

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _size = TextEditingController(
    text: widget.product == null ? '' : '${widget.product!.sizeKg}',
  );
  late final _refill = TextEditingController(text: widget.product == null ? '' : '${widget.product!.refillPrice}');
  late final _newPrice = TextEditingController(text: '${widget.product?.newCylinderPrice ?? ''}');
  late final _desc = TextEditingController(text: widget.product?.description ?? '');
  late final _badge = TextEditingController(text: widget.product?.badge ?? '');
  late bool _active = widget.product?.active ?? true;
  late bool _inStock = widget.product?.inStock ?? true;
  late CustomerSegment _segment = widget.product?.segment ?? CustomerSegment.both;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _size, _refill, _newPrice, _desc, _badge]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final s = context.read<AdminSession>();
    final old = widget.product;
    final kg = double.parse(_size.text.trim());
    final id = old?.id ?? 'cyl-${_size.text.trim().replaceAll('.', '-')}kg';
    final next = Product(
      id: id,
      name: _name.text.trim(),
      sizeKg: kg,
      refillPrice: int.parse(_refill.text.trim()),
      newCylinderPrice: _newPrice.text.trim().isEmpty ? null : int.parse(_newPrice.text.trim()),
      description: _desc.text.trim(),
      badge: _badge.text.trim(),
      imageUrl: old?.imageUrl ?? '',
      imageAsset: old?.imageAsset ?? '',
      segment: _segment,
      active: _active,
      inStock: _inStock,
      sortOrder: old?.sortOrder ?? (s.products.length + 1),
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await s.saveProduct(next);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
      showMessage(context, 'Saved. Customers see the new price straight away.');
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  String? _money(String? v, {bool optional = false}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return optional ? null : 'Required';
    final n = int.tryParse(t);
    return n == null || n <= 0 || n > 1000000 ? 'Whole rupees only' : null;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
    child: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.product == null ? 'New cylinder' : 'Edit ${widget.product!.name}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name', hintText: '11.8kg Gas Cylinder'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _size,
                    enabled: widget.product == null,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Size (kg)'),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      return n == null || n <= 0 || n > 100 ? 'Enter kg' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _refill,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Refill price (Rs)'),
                    validator: _money,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPrice,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Price with a new cylinder (Rs)',
                helperText: 'Leave empty if you do not sell new cylinders online',
              ),
              validator: (v) => _money(v, optional: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Short description'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _badge,
              decoration: const InputDecoration(labelText: 'Badge (optional)', hintText: 'Most popular'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CustomerSegment>(
              initialValue: _segment,
              decoration: const InputDecoration(labelText: 'Shown to'),
              items: [
                for (final v in CustomerSegment.values) DropdownMenuItem(value: v, child: Text(v.label)),
              ],
              onChanged: (v) => setState(() => _segment = v ?? _segment),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible to customers'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('In stock'),
              value: _inStock,
              onChanged: (v) => setState(() => _inStock = v),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Brand.danger, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    ),
  );
}

class SettingsEditor extends StatefulWidget {
  const SettingsEditor({super.key});

  @override
  State<SettingsEditor> createState() => _SettingsEditorState();
}

class _SettingsEditorState extends State<SettingsEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  late bool _accepting;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = context.read<AdminSession>().settings;
    _accepting = s.acceptingOrders;
    _c = {
      'deliveryFee': TextEditingController(text: '${s.deliveryFee}'),
      'freeDeliveryFrom': TextEditingController(text: '${s.freeDeliveryFrom}'),
      'minOrderTotal': TextEditingController(text: '${s.minOrderTotal}'),
      'maxCylindersPerOrder': TextEditingController(text: '${s.maxCylindersPerOrder}'),
      'closedMessage': TextEditingController(text: s.closedMessage),
      'phone': TextEditingController(text: s.phone),
      'whatsapp': TextEditingController(text: s.whatsapp),
      'email': TextEditingController(text: s.email),
      'shopAddress': TextEditingController(text: s.shopAddress),
      'openingHours': TextEditingController(text: s.openingHours),
      'serviceAreas': TextEditingController(text: s.serviceAreas.join(', ')),
      'accountTitle': TextEditingController(text: s.accountTitle),
      'jazzCashAccount': TextEditingController(text: s.jazzCashAccount),
      'easyPaisaAccount': TextEditingController(text: s.easyPaisaAccount),
      'raastId': TextEditingController(text: s.raastId),
      'bankDetails': TextEditingController(text: s.bankDetails),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _t(String k) => _c[k]!.text.trim();
  int _n(String k) => int.tryParse(_t(k)) ?? 0;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final next = AppSettings(
      acceptingOrders: _accepting,
      closedMessage: _t('closedMessage'),
      deliveryFee: _n('deliveryFee'),
      freeDeliveryFrom: _n('freeDeliveryFrom'),
      minOrderTotal: _n('minOrderTotal'),
      maxCylindersPerOrder: _n('maxCylindersPerOrder'),
      phone: _t('phone'),
      whatsapp: _t('whatsapp').replaceAll(RegExp(r'\D'), ''),
      email: _t('email'),
      shopAddress: _t('shopAddress'),
      openingHours: _t('openingHours'),
      serviceAreas: [
        for (final a in _t('serviceAreas').split(','))
          if (a.trim().isNotEmpty) a.trim(),
      ],
      bankDetails: _t('bankDetails'),
      accountTitle: _t('accountTitle'),
      jazzCashAccount: _t('jazzCashAccount'),
      easyPaisaAccount: _t('easyPaisaAccount'),
      raastId: _t('raastId'),
    );
    final err = await context.read<AdminSession>().saveSettings(next);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
      showMessage(context, 'Settings saved.');
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  Widget _num(String k, String label, {String? help}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _c[k],
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, helperText: help),
      validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a number (0 if none)' : null,
    ),
  );

  Widget _text(String k, String label, {String? help, int lines = 1, TextInputType? type}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _c[k],
      maxLines: lines,
      keyboardType: type,
      decoration: InputDecoration(labelText: label, helperText: help),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Shop settings')),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Save settings'),
        ),
      ),
    ),
    body: Constrained(
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Taking orders'),
              value: _accepting,
              onChanged: (v) => setState(() => _accepting = v),
            ),
            _text('closedMessage', 'Message when paused', lines: 2),
            const Heading('Delivery'),
            _num('deliveryFee', 'Delivery fee (Rs)'),
            _num('freeDeliveryFrom', 'Free delivery from (Rs)', help: '0 turns free delivery off'),
            _num('minOrderTotal', 'Minimum order (Rs)'),
            _num('maxCylindersPerOrder', 'Most cylinders per order'),
            _text('serviceAreas', 'Areas you deliver to', help: 'Separate with commas. Empty means all of Lahore.', lines: 2),
            const Heading('Shop'),
            _text('phone', 'Phone', type: TextInputType.phone),
            _text('whatsapp', 'WhatsApp number', help: 'International form, e.g. 923085745740', type: TextInputType.phone),
            _text('email', 'Email', type: TextInputType.emailAddress),
            _text('shopAddress', 'Address', lines: 2),
            _text('openingHours', 'Opening hours'),
            const Heading('Where customers send money'),
            _text('accountTitle', 'Account title (name on the accounts)'),
            _text('jazzCashAccount', 'JazzCash number', type: TextInputType.phone),
            _text('easyPaisaAccount', 'Easypaisa number', type: TextInputType.phone),
            _text('raastId', 'Raast ID'),
            _text('bankDetails', 'Bank name and account / IBAN', lines: 3),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Brand.danger, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );
}
