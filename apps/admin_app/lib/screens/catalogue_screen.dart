import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/order_x.dart';
import '../utils/photo.dart';
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
                    st.acceptingOrders
                        ? Icons.storefront_rounded
                        : Icons.pause_circle_rounded,
                    color: st.acceptingOrders ? Brand.success : Brand.danger,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          st.acceptingOrders
                              ? 'Taking orders'
                              : 'Orders paused',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          st.acceptingOrders
                              ? 'Customers can place orders.'
                              : 'Customers see your closed message.',
                          style: TextStyle(
                            color: context.pal.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: st.acceptingOrders,
                    onChanged: (v) async {
                      final err = await s.saveSettings(
                        _copy(st, acceptingOrders: v),
                      );
                      if (err != null && context.mounted)
                        showMessage(context, err, error: true);
                    },
                  ),
                ],
              ),
            ),
            const Heading('Cylinders, stoves and prices'),
            if (!s.storeReady) _Defaults(session: s),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (from, to) async {
                final err = await s.moveProduct(from, to);
                if (err != null && context.mounted) {
                  showMessage(context, err, error: true);
                }
              },
              children: [
                for (final (i, p) in s.products.indexed)
                  Padding(
                    key: ValueKey(p.id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.transparent,
                      child: Ink(
                        decoration: panel(context),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(Brand.radius),
                          onTap: () => _editProduct(context, p),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: context.pal.tint,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ProductPicture(p, height: 52),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        p.isAccessory
                                            ? 'Accessory  ·  ${rs(p.refillPrice)}'
                                            : 'Refill ${rs(p.refillPrice)}'
                                                  '${p.newCylinderPrice != null ? '  ·  New ${rs(p.newCylinderPrice!)}' : ''}',
                                        style: TextStyle(
                                          color: context.pal.muted,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (!p.active)
                                            const Pill(
                                              Icons.visibility_off_rounded,
                                              'Hidden',
                                              color: Brand.danger,
                                            ),
                                          if (p.active && !p.inStock)
                                            const Pill(
                                              Icons
                                                  .remove_shopping_cart_rounded,
                                              'Out of stock',
                                              color: Brand.warning,
                                            ),
                                          if (p.active && p.inStock)
                                            Pill(
                                              p.lowStock != null
                                                  ? Icons.warning_amber_rounded
                                                  : Icons.check_rounded,
                                              p.stock == null
                                                  ? 'On sale'
                                                  : 'On sale · ${p.stock} left',
                                              color: p.lowStock != null
                                                  ? context.pal.warn
                                                  : Brand.success,
                                            ),
                                          if (!p.hasUploadedImage)
                                            Pill(
                                              Icons.auto_awesome_rounded,
                                              'Auto picture',
                                              color: context.pal.muted,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                ReorderableDragStartListener(
                                  index: i,
                                  child: const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Icon(Icons.drag_handle_rounded),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (s.products.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Hold the handle on the right and drag to change the order customers see.',
                  style: TextStyle(color: context.pal.muted, fontSize: 12.5),
                ),
              ),
            if (s.storeReady && !s.products.any((p) => p.isAccessory))
              _SampleAccessories(session: s),
            OutlinedButton.icon(
              onPressed: () => _editProduct(context, null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add a cylinder, stove or accessory'),
            ),
            const Heading('Delivery, hours and payments'),
            FilledButton.tonalIcon(
              onPressed: context.read<AdminSession>().isOwner
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsEditor(),
                      ),
                    )
                  : null,
              icon: const Icon(Icons.tune_rounded),
              label: Text(
                context.read<AdminSession>().isOwner
                    ? 'Edit shop settings'
                    : 'Shop settings (owner only)',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static AppSettings _copy(AppSettings s, {bool? acceptingOrders}) =>
      AppSettings.fromMap({
        ...s.toMap(),
        'acceptingOrders': acceptingOrders ?? s.acceptingOrders,
      });

  /// A full page (with a back arrow), not a sheet: the long form used to
  /// cover the whole screen with no way back.
  void _editProduct(BuildContext context, Product? p) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: Text(p == null ? 'New cylinder' : 'Edit ${p.name}'),
            ),
            body: SafeArea(child: _ProductEditor(product: p)),
          ),
        ),
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
        const Text(
          'Nothing here yet',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
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

/// One tap adds the sample stoves and regulator (test prices) to the shop.
class _SampleAccessories extends StatefulWidget {
  const _SampleAccessories({required this.session});
  final AdminSession session;

  @override
  State<_SampleAccessories> createState() => _SampleAccessoriesState();
}

class _SampleAccessoriesState extends State<_SampleAccessories> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: panel(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sell stoves and regulators too?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Adds 3 sample items (2-burner glass stove, single burner stove, regulator) with TEST prices. Check every price after adding.',
          style: TextStyle(
            color: context.pal.muted,
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.tonal(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  final base = widget.session.products.length;
                  String? err;
                  var n = 0;
                  for (final p in SeedData.products.where(
                    (p) => p.isAccessory,
                  )) {
                    err = await widget.session.saveProduct(
                      Product(
                        id: p.id,
                        name: p.name,
                        sizeKg: 0,
                        refillPrice: p.refillPrice,
                        description: p.description,
                        imageAsset: p.imageAsset,
                        segment: p.segment,
                        sortOrder: base + (++n),
                      ),
                    );
                    if (err != null) break;
                  }
                  if (!context.mounted) return;
                  setState(() => _busy = false);
                  showMessage(
                    context,
                    err ?? 'Added. Now check each price and add photos.',
                    error: err != null,
                  );
                },
          child: Text(_busy ? 'Adding…' : 'Add sample items'),
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

  /// null = unchanged, '' = back to the automatic picture, else new base64.
  String? _photo;
  bool _photoBusy = false;
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _size = TextEditingController(
    text: widget.product == null ? '' : '${widget.product!.sizeKg}',
  );
  late final _refill = TextEditingController(
    text: widget.product == null ? '' : '${widget.product!.refillPrice}',
  );
  late final _newPrice = TextEditingController(
    text: '${widget.product?.newCylinderPrice ?? ''}',
  );
  late final _desc = TextEditingController(
    text: widget.product?.description ?? '',
  );
  late final _badge = TextEditingController(text: widget.product?.badge ?? '');
  late bool _accessory = widget.product?.isAccessory ?? false;
  late bool _active = widget.product?.active ?? true;
  late bool _inStock = widget.product?.inStock ?? true;
  int? get _stockCount => int.tryParse(_stock.text.trim());

  late final _stock = TextEditingController(
    text: widget.product?.stock?.toString() ?? '',
  );
  late CustomerSegment _segment =
      widget.product?.segment ?? CustomerSegment.both;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _size, _refill, _newPrice, _desc, _badge]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // The automatic picture depends on the size, so refresh the preview.
    _size.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() {
      _photoBusy = true;
      _error = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null) return;
      final data = await compressProductPhoto(await file.readAsBytes());
      if (mounted) setState(() => _photo = data);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is String
              ? e
              : 'Could not use that photo. Please try another one.',
        );
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final s = context.read<AdminSession>();
    final old = widget.product;
    final kg = _accessory ? 0.0 : double.parse(_size.text.trim());
    final id =
        old?.id ??
        (_accessory
            ? 'acc-${DateTime.now().millisecondsSinceEpoch}'
            : 'cyl-${_size.text.trim().replaceAll('.', '-')}kg');
    final next = Product(
      id: id,
      name: _name.text.trim(),
      sizeKg: kg,
      refillPrice: int.parse(_refill.text.trim()),
      newCylinderPrice: _accessory || _newPrice.text.trim().isEmpty
          ? null
          : int.parse(_newPrice.text.trim()),
      description: _desc.text.trim(),
      badge: _badge.text.trim(),
      imageUrl: old?.imageUrl ?? '',
      imageAsset: old?.imageAsset ?? '',
      imageData: _photo ?? old?.imageData ?? '',
      segment: _segment,
      active: _active,
      inStock: _stockCount == null ? _inStock : _stockCount! > 0,
      stock: _stockCount,
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
    padding: EdgeInsets.fromLTRB(
      20,
      4,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _PhotoPicker(
              product: widget.product,
              size: _accessory ? 0 : double.tryParse(_size.text.trim()),
              photo: _photo,
              busy: _photoBusy,
              onPick: _pickPhoto,
              onAuto: () => setState(() => _photo = ''),
            ),
            if (widget.product == null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('This is a stove or accessory'),
                subtitle: const Text(
                  'Not a gas cylinder: one price, no empty cylinder to collect.',
                ),
                value: _accessory,
                onChanged: (v) => setState(() => _accessory = v),
              ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: _accessory
                    ? 'Single burner stove'
                    : '11.8kg Gas Cylinder',
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!_accessory)
                  Expanded(
                    child: TextFormField(
                      controller: _size,
                      enabled: widget.product == null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Size (kg)'),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').trim());
                        return n == null || n <= 0 || n > 100
                            ? 'Enter kg'
                            : null;
                      },
                    ),
                  ),
                if (!_accessory) const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _refill,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: _accessory
                          ? 'Price (Rs)'
                          : 'Refill price (Rs)',
                    ),
                    validator: _money,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_accessory)
              TextFormField(
                controller: _newPrice,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Price with a new cylinder (Rs)',
                  helperText:
                      'Leave empty if you do not sell new cylinders online',
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
              decoration: const InputDecoration(
                labelText: 'Badge (optional)',
                hintText: 'Most popular',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CustomerSegment>(
              initialValue: _segment,
              decoration: const InputDecoration(labelText: 'Shown to'),
              items: [
                for (final v in CustomerSegment.values)
                  DropdownMenuItem(value: v, child: Text(v.label)),
              ],
              onChanged: (v) => setState(() => _segment = v ?? _segment),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible to customers'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            TextField(
              controller: _stock,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _accessory
                    ? 'Pieces in the shop (optional)'
                    : 'Cylinders in the shop (optional)',
                helperText: 'Leave empty to not count. When counted, confirmed orders take from it and 0 shows "out of stock".',
              ),
            ),
            if (_stockCount == null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('In stock'),
                value: _inStock,
                onChanged: (v) => setState(() => _inStock = v),
              ),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(
                  color: Brand.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
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
  late bool _autoHours;
  late bool _pauseNoRiders;
  late int _opensAt;
  late int _closesAt;
  late String _loginMode;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = context.read<AdminSession>().settings;
    _accepting = s.acceptingOrders;
    _autoHours = s.autoHours;
    _pauseNoRiders = s.pauseWhenNoRiders;
    _opensAt = s.opensAt;
    _closesAt = s.closesAt;
    _loginMode = s.loginMode;
    _c = {
      'deliveryFee': TextEditingController(text: '${s.deliveryFee}'),
      'freeDeliveryFrom': TextEditingController(text: '${s.freeDeliveryFrom}'),
      'minOrderTotal': TextEditingController(text: '${s.minOrderTotal}'),
      'maxCylindersPerOrder': TextEditingController(
        text: '${s.maxCylindersPerOrder}',
      ),
      'closedMessage': TextEditingController(text: s.closedMessage),
      'phone': TextEditingController(text: s.phone),
      'whatsapp': TextEditingController(text: s.whatsapp),
      'email': TextEditingController(text: s.email),
      'shopAddress': TextEditingController(text: s.shopAddress),
      'openingHours': TextEditingController(text: s.openingHours),
      'serviceAreas': TextEditingController(text: s.serviceAreas.join(', ')),
      'areaFees': TextEditingController(
        text: [for (final e in s.areaFees.entries) '${e.key} = ${e.value}']
            .join('\n'),
      ),
      'minBuildCustomer': TextEditingController(text: '${s.minBuildCustomer}'),
      'minBuildRider': TextEditingController(text: '${s.minBuildRider}'),
      'minBuildAdmin': TextEditingController(text: '${s.minBuildAdmin}'),
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

  /// "DHA = 250" lines (or comma separated) → {dha: 250}.
  static Map<String, int> _parseAreaFees(String text) {
    final out = <String, int>{};
    for (final part in text.split(RegExp(r'[\n,;]'))) {
      final kv = part.split('=');
      if (kv.length != 2) continue;
      final fee = int.tryParse(kv[1].trim());
      final area = kv[0].trim().toLowerCase();
      if (area.isNotEmpty && fee != null && fee >= 0) out[area] = fee;
    }
    return out;
  }

  String _t(String k) => _c[k]!.text.trim();
  int _n(String k) => int.tryParse(_t(k)) ?? 0;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final cur = context.read<AdminSession>().settings;
    final next = AppSettings(
      acceptingOrders: _accepting,
      autoHours: _autoHours,
      opensAt: _opensAt,
      closesAt: _closesAt,
      pauseWhenNoRiders: _pauseNoRiders,
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
      loginMode: _loginMode,
      areaFees: _parseAreaFees(_t('areaFees')),
      minBuildCustomer: _n('minBuildCustomer'),
      minBuildRider: _n('minBuildRider'),
      minBuildAdmin: _n('minBuildAdmin'),
      // Rewards are edited on their own screen: keep what is saved.
      pointsPerHundred: cur.pointsPerHundred,
      pointValue: cur.pointValue,
      maxPointsPercent: cur.maxPointsPercent,
      referralDiscount: cur.referralDiscount,
      referralBonusPoints: cur.referralBonusPoints,
      reminderDays: cur.reminderDays,
      pointsSince: cur.pointsSince,
      planEnabled: cur.planEnabled,
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
      validator: (v) =>
          (v ?? '').trim().isEmpty ? 'Enter a number (0 if none)' : null,
    ),
  );

  Widget _text(
    String k,
    String label, {
    String? help,
    int lines = 1,
    TextInputType? type,
  }) => Padding(
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
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
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
            const Heading('When orders are accepted'),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: panel(context),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Only take orders in opening hours'),
                    subtitle: const Text(
                      'Outside these hours customers see "We are closed" and cannot order.',
                    ),
                    value: _autoHours,
                    onChanged: (v) => setState(() => _autoHours = v),
                  ),
                  if (_autoHours)
                    Row(
                      children: [
                        Expanded(
                          child: _TimeField(
                            label: 'Opens',
                            minutes: _opensAt,
                            onChanged: (m) => setState(() => _opensAt = m),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TimeField(
                            label: 'Closes',
                            minutes: _closesAt,
                            onChanged: (m) => setState(() => _closesAt = m),
                          ),
                        ),
                      ],
                    ),
                  const Divider(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pause orders when no rider is on shift'),
                    subtitle: const Text(
                      'Customers see "Our riders are offline" until a rider goes online.',
                    ),
                    value: _pauseNoRiders,
                    onChanged: (v) => setState(() => _pauseNoRiders = v),
                  ),
                ],
              ),
            ),
            const Heading('How customers sign in'),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: 'quick',
                  label: Text('Quick'),
                  icon: Icon(Icons.bolt_rounded),
                ),
                ButtonSegment(
                  value: 'sms',
                  label: Text('SMS code'),
                  icon: Icon(Icons.sms_rounded),
                ),
              ],
              selected: {_loginMode},
              onSelectionChanged: (v) => setState(() => _loginMode = v.first),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                _loginMode == 'quick'
                    ? 'Customers type their mobile number only. Works on the free Firebase plan. Call to confirm orders: numbers are not verified.'
                    : 'Customers get a one-time code by SMS. Needs the paid Firebase (Blaze) plan.',
                style: TextStyle(color: context.pal.muted, height: 1.35),
              ),
            ),
            const Heading('Force app updates (advanced)'),
            _num(
              'minBuildCustomer',
              'Oldest customer app build allowed',
              help: '0 = all. Older apps are asked to update. The build number is the +N in the app version.',
            ),
            _num('minBuildRider', 'Oldest rider app build allowed'),
            _num('minBuildAdmin', 'Oldest admin app build allowed'),
            const Heading('Delivery'),
            _num('deliveryFee', 'Delivery fee (Rs)'),
            _num(
              'freeDeliveryFrom',
              'Free delivery from (Rs)',
              help: '0 turns free delivery off',
            ),
            _num('minOrderTotal', 'Minimum order (Rs)'),
            _num('maxCylindersPerOrder', 'Most cylinders per order'),
            _text(
              'serviceAreas',
              'Areas you deliver to',
              help: 'Separate with commas. Empty means all of Lahore.',
              lines: 2,
            ),
            _text(
              'areaFees',
              'Delivery fee by area (optional)',
              help: 'One per line, like  DHA = 250  or  Gulberg = 150. Areas not listed pay the delivery fee above.',
              lines: 4,
            ),
            const Heading('Shop'),
            _text('phone', 'Phone', type: TextInputType.phone),
            _text(
              'whatsapp',
              'WhatsApp number',
              help: 'International form, e.g. 923085745740',
              type: TextInputType.phone,
            ),
            _text('email', 'Email', type: TextInputType.emailAddress),
            _text('shopAddress', 'Address', lines: 2),
            _text('openingHours', 'Opening hours'),
            const Heading('Where customers send money'),
            _text('accountTitle', 'Account title (name on the accounts)'),
            _text(
              'jazzCashAccount',
              'JazzCash number',
              type: TextInputType.phone,
            ),
            _text(
              'easyPaisaAccount',
              'Easypaisa number',
              type: TextInputType.phone,
            ),
            _text('raastId', 'Raast ID'),
            _text('bankDetails', 'Bank name and account / IBAN', lines: 3),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(
                  color: Brand.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Preview of what customers will see, with ways to change it.
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.product,
    required this.size,
    required this.photo,
    required this.busy,
    required this.onPick,
    required this.onAuto,
  });
  final Product? product;
  final double? size;
  final String? photo;
  final bool busy;
  final Future<void> Function(ImageSource) onPick;
  final VoidCallback onAuto;

  @override
  Widget build(BuildContext context) {
    // Build a throw-away product so the preview picks the right automatic
    // picture for the size typed so far.
    final base =
        product ??
        Product(id: 'new', name: '', sizeKg: size ?? 11.8, refillPrice: 0);
    final shown = Product(
      id: base.id,
      name: base.name,
      sizeKg: size ?? base.sizeKg,
      refillPrice: base.refillPrice,
      imageUrl: base.imageUrl,
      imageAsset: base.imageAsset,
      imageData: photo ?? base.imageData,
    );
    final custom = shown.hasUploadedImage;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: panel(context),
      child: Column(
        children: [
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.pal.tint,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(10),
            child: busy
                ? const Center(child: CircularProgressIndicator())
                : ProductPicture(shown, height: 130),
          ),
          const SizedBox(height: 10),
          Text(
            custom ? 'Your photo. Customers see this.' : 'Automatic picture for this size. Customers see this until you add a photo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.pal.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : () => onPick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                label: const Text('Choose photo'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => onPick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_rounded, size: 18),
                label: const Text('Take photo'),
              ),
              if (custom)
                TextButton.icon(
                  onPressed: busy ? null : onAuto,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Use automatic'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A tappable time (opens the clock) shown as "9:00 am".
class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.minutes,
    required this.onChanged,
  });
  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 56),
      alignment: Alignment.centerLeft,
    ),
    onPressed: () async {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: minutes ~/ 60 % 24, minute: minutes % 60),
      );
      if (t != null) onChanged(t.hour * 60 + t.minute);
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: context.pal.muted)),
        Text(
          OrderingStatus.clock(minutes),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ],
    ),
  );
}
