import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../theme/brand.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Commercial / bulk supply enquiry → `quoteRequests` (handled in admin app).
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
  final _monthlyKg = TextEditingController();
  final _area = TextEditingController();
  final _notes = TextEditingController();
  String _type = QuoteRequest.businessTypes.first;
  String _size = '45.4 KG';
  bool _sending = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().profile;
    _business = TextEditingController(text: p?.businessName);
    _contact = TextEditingController(text: p?.name);
    _phone = TextEditingController(
      text: p == null ? '' : prettyPkMobile(p.phone),
    );
  }

  @override
  void dispose() {
    for (final c in [_business, _contact, _phone, _monthlyKg, _area, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final state = context.read<AppState>();
    setState(() => _sending = true);
    try {
      await context.read<Backend>().quotes.submit(
        QuoteRequest(
          customerId: state.uid ?? '',
          businessName: _business.text.trim(),
          contactName: _contact.text.trim(),
          phone: normalizePkMobile(_phone.text) ?? _phone.text.trim(),
          businessType: _type,
          monthlyKg: int.tryParse(_monthlyKg.text) ?? 0,
          preferredSize: _size,
          area: _area.text.trim(),
          notes: _notes.text.trim(),
        ),
      );
      setState(() => _sent = true);
    } catch (e) {
      if (mounted) showMessage(context, 'Could not send: $e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Scaffold(
        appBar: AppBar(leading: const ScreenBack()),
        body: EmptyState(
          icon: Icons.mark_email_read_outlined,
          title: 'Request received',
          message: 'Our commercial team will call you within one working day with your rate.',
          action: FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Back to home'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: const ScreenBack(),
        title: const Text('Bulk & commercial supply'),
      ),
      body: Constrained(
        maxWidth: 560,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Brand.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Restaurants, hotels, bakeries and factories get scheduled deliveries, '
                  'priority service and monthly billing. Tell us what you need.',
                ),
              ),
              const SizedBox(height: 20),
              _field(_business, 'Business name', Icons.business_outlined),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type of business',
                ),
                items: [
                  for (final t in QuoteRequest.businessTypes)
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 14),
              _field(_contact, 'Contact person', Icons.person_outline),
              _field(
                _phone,
                'Mobile number',
                Icons.phone_iphone,
                keyboard: TextInputType.phone,
                validator: (v) => normalizePkMobile(v ?? '') == null
                    ? 'Enter a valid mobile number'
                    : null,
              ),
              _field(_area, 'Area in Lahore', Icons.map_outlined),
              _field(
                _monthlyKg,
                'Estimated LPG per month (kg)',
                Icons.scale_outlined,
                keyboard: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const Text('Preferred cylinder'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in [
                    '11.8 KG',
                    '45.4 KG',
                    'Bulk tank',
                    'Not sure',
                  ])
                    ChoiceChip(
                      label: Text(s),
                      selected: _size == s,
                      onSelected: (_) => setState(() => _size = s),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Anything else? (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _sending ? null : _submit,
                child: const Text('Request a quote'),
              ),
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
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: c,
      keyboardType: keyboard,
      inputFormatters: formatters,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator:
          validator ?? (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
    ),
  );
}
