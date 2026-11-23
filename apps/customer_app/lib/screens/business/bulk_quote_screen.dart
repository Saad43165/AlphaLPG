import 'package:alpha_ui/alpha_ui.dart' show WhatsAppIcon;
import 'package:alpha_core/alpha_core.dart';

import '../../l10n/lang.dart';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart' hide Text;

import '../../l10n/text.dart';

import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../state/cart.dart';
import '../../theme/brand.dart';
import '../../utils/format.dart';
import '../../utils/launch.dart';
import '../../widgets/common.dart';

/// Bulk order request: restaurants, hotels, factories, or anyone who needs
/// more cylinders than one normal order allows. Goes to the shop (admin app).
class BulkQuoteScreen extends StatefulWidget {
  const BulkQuoteScreen({super.key});

  @override
  State<BulkQuoteScreen> createState() => _BulkQuoteScreenState();
}

class _BulkQuoteScreenState extends State<BulkQuoteScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _business;
  late final TextEditingController _contact;
  late final TextEditingController _phone;
  final _area = TextEditingController();
  final _notes = TextEditingController();
  String _type = QuoteRequest.businessTypes.first;
  String _every = 'Every month';
  final _qty = <String, int>{}; // product id -> cylinders per delivery
  bool _sending = false;
  QuoteRequest? _sentRequest;

  static const _frequencies = [
    'Just once',
    'Every week',
    'Every 2 weeks',
    'Every month',
  ];

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final p = state.profile;
    _business = TextEditingController(text: p?.businessName);
    _contact = TextEditingController(text: p?.name);
    _phone = TextEditingController(
      text: p == null ? '' : prettyPkMobile(p.phone),
    );
    final addr = state.selectedAddress;
    if (addr != null) _area.text = addr.area;
    // Start from what is already in the cart.
    final cart = context.read<Cart>();
    for (final l in cart.lines) {
      _qty[l.productId] = (_qty[l.productId] ?? 0) + l.quantity;
    }
  }

  @override
  void dispose() {
    for (final c in [_business, _contact, _phone, _area, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _cylinders => _qty.values.fold(0, (a, b) => a + b);

  double _kg(List<Product> products) {
    var kg = 0.0;
    for (final p in products) {
      kg += (_qty[p.id] ?? 0) * p.sizeKg;
    }
    return kg;
  }

  Future<void> _submit(List<Product> products, {bool whatsApp = false}) async {
    if (!_form.currentState!.validate()) return;
    final state = context.read<AppState>();
    final lines = [
      for (final p in products)
        if ((_qty[p.id] ?? 0) > 0) '${_qty[p.id]}× ${p.name}',
    ];
    final kg = _kg(products);
    final extra = _notes.text.trim();
    final q = QuoteRequest(
      customerId: state.uid ?? '',
      businessName: _business.text.trim().isEmpty
          ? _contact.text.trim()
          : _business.text.trim(),
      contactName: _contact.text.trim(),
      phone: normalizePkMobile(_phone.text) ?? _phone.text.trim(),
      businessType: _type,
      // Total kg per month if it repeats, otherwise this one delivery.
      monthlyKg:
          (kg *
                  switch (_every) {
                    'Every week' => 4,
                    'Every 2 weeks' => 2,
                    _ => 1,
                  })
              .round(),
      preferredSize: '$_cylinders cylinders',
      area: _area.text.trim(),
      notes: [
        'Needs: ${lines.join(', ')} (${kg.toStringAsFixed(0)} kg each delivery)',
        'Delivery: $_every',
        if (extra.isNotEmpty) extra,
      ].join('\n'),
    );
    setState(() => _sending = true);
    try {
      await context.read<Backend>().quotes.submit(q);
      if (mounted) setState(() => _sentRequest = q);
      if (whatsApp) {
        final wa = state.settings.whatsapp;
        final text = [
          'Assalam-o-Alaikum, I would like a bulk quote.',
          '',
          '${q.businessName} (${q.businessType})',
          q.notes,
          if (q.area.isNotEmpty) 'Area: ${q.area}',
          'Name: ${q.contactName}',
          'Phone: ${q.phone}',
        ].join('\n');
        await (wa.isEmpty
            ? Launch.whatsappShare(text)
            : Launch.whatsapp(wa, text));
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Could not send. Check your internet and try again, or call us.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.settings;
    final pal = context.pal;
    final products = [
      for (final p in state.products)
        if (p.active && !p.isAccessory) p,
    ];
    if (_sentRequest != null)
      return _Sent(request: _sentRequest!, phone: settings.phone);

    Widget heading(int n, String t) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: Brand.blueDark,
            child: Text(
              '$n',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ),
        ],
      ),
    );

    final kg = _kg(products);
    return Scaffold(
      appBar: AppBar(
        leading: const ScreenBack(),
        title: const Text('Bulk order'),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: pal.card,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: pal.isDark ? 0.4 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Constrained(
              maxWidth: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    onPressed: _sending || _cylinders == 0
                        ? null
                        : () => _submit(products),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _cylinders == 0
                          ? 'Choose how many cylinders'
                          : 'Send request · $_cylinders cylinder${_cylinders == 1 ? '' : 's'}',
                    ),
                  ),
                  if (_cylinders > 0)
                    TextButton.icon(
                      onPressed: _sending
                          ? null
                          : () => _submit(products, whatsApp: true),
                      icon: const WhatsAppIcon(size: 18),
                      label: const Text('Send in the app and on WhatsApp'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Constrained(
        maxWidth: 560,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              // What this is.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.pal.card,
                  border: Border.all(color: Brand.blue, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'For restaurants, hotels, factories and big families',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '1. Tell us what you need.   2. We send the rate in the app, or call or WhatsApp you, within one working day.   3. We deliver on your schedule.',
                      style: TextStyle(color: pal.muted, height: 1.45),
                    ),
                  ],
                ),
              ),

              heading(1, 'How many cylinders per delivery?'),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: _panel(context),
                child: Column(
                  children: [
                    for (final (i, p) in products.indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    p.sizeLabel,
                                    style: TextStyle(
                                      color: pal.muted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            QuantityStepper(
                              value: _qty[p.id] ?? 0,
                              max: 999,
                              onChanged: (v) => setState(() => _qty[p.id] = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_cylinders > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    'Total: $_cylinders cylinders · ${NumberFormat('#,###').format(kg.round())} kg of gas',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),

              heading(2, 'How often?'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in _frequencies)
                    ChoiceChip(
                      label: Text(f),
                      selected: _every == f,
                      onSelected: (_) => setState(() => _every = f),
                    ),
                ],
              ),

              heading(3, 'Who and where?'),
              _field(
                _business,
                'Business name (if any)',
                Icons.business_outlined,
                required: false,
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _type,
                decoration: InputDecoration(labelText: tr('Type')),
                items: [
                  for (final t in QuoteRequest.businessTypes)
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 14),
              _field(_contact, 'Your name', Icons.person_outline),
              _field(
                _phone,
                'Mobile number',
                Icons.phone_iphone,
                keyboard: TextInputType.phone,
                caps: TextCapitalization.none,
                validator: (v) => normalizePkMobile(v ?? '') == null
                    ? tr('Enter a valid mobile number')
                    : null,
              ),
              _field(_area, 'Area in Lahore', Icons.map_outlined),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                maxLength: 400,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: tr('Anything else? (optional)'),
                  hintText: tr('Preferred day or time, gate instructions…'),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton.icon(
                  onPressed: () => Launch.call(settings.phone),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: Text('Rather talk? Call ${settings.phone}'),
                ),
              ),
              const _MyRequests(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    bool required = true,
    TextCapitalization caps = TextCapitalization.words,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: c,
      keyboardType: keyboard,
      inputFormatters: formatters,
      textCapitalization: caps,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator:
          validator ??
          (v) => required && (v ?? '').trim().isEmpty ? 'Required' : null,
    ),
  );
}

/// Earlier requests from this customer, with where each one stands.
class _MyRequests extends StatelessWidget {
  const _MyRequests();

  @override
  Widget build(BuildContext context) {
    final uid = context.select<AppState, String?>((s) => s.uid);
    if (uid == null) return const SizedBox.shrink();
    final pal = context.pal;
    return StreamBuilder<List<QuoteRequest>>(
      stream: context.read<Backend>().quotes.watchForCustomer(uid),
      builder: (context, snap) {
        final list = [...?snap.data]
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            ),
          );
        if (list.isEmpty) return const SizedBox.shrink();
        String label(String s) => switch (s) {
          'contacted' => 'Alpha LPG replied',
          'won' => 'Accepted',
          'lost' => 'Closed',
          _ => 'Received: we will call you',
        };
        Color color(String s) => switch (s) {
          'contacted' => Brand.blueDark,
          'won' => Brand.success,
          'lost' => pal.muted,
          _ => context.pal.warn,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(2, 22, 2, 8),
              child: Text(
                'Your earlier requests',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
            for (final q in list.take(5))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: _panel(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                q.preferredSize.isEmpty
                                    ? 'Bulk request'
                                    : q.preferredSize,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                q.createdAt == null
                                    ? ''
                                    : DateFormat('d MMM, h:mm a')
                                          .format(q.createdAt!.toLocal()),
                                style: TextStyle(
                                  color: pal.muted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Text(
                            label(q.status),
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: color(q.status),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (q.hasReply) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.pal.card,
                          border: Border.all(color: Brand.success, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alpha LPG replied',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(q.reply, style: const TextStyle(height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Sent extends StatelessWidget {
  const _Sent({required this.request, required this.phone});
  final QuoteRequest request;
  final String phone;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: const ScreenBack()),
    body: Constrained(
      maxWidth: 480,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Brand.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Request sent',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Alpha LPG will send your rate in the app. We may also WhatsApp or call ${request.contactName} on ${prettyPkMobile(request.phone)} within one working day.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.pal.muted, height: 1.45),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _panel(context),
            child: Text(request.notes, style: const TextStyle(height: 1.5)),
          ),
          const SizedBox(height: 22),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => context.go('/'),
            child: const Text('Back to home'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              final wa = context.read<AppState>().settings.whatsapp;
              wa.isEmpty ? Launch.whatsappShare('') : Launch.whatsapp(wa);
            },
            icon: const WhatsAppIcon(size: 18),
            label: const Text('WhatsApp Alpha LPG'),
          ),
          TextButton.icon(
            onPressed: () => Launch.call(phone),
            icon: const Icon(Icons.call_rounded, size: 18),
            label: Text('Call $phone'),
          ),
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
