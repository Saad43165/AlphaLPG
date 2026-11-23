import 'package:alpha_core/alpha_core.dart';

import '../../l10n/lang.dart';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Text;

import '../../l10n/text.dart';

import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../state/cart.dart';
import '../../theme/brand.dart';
import '../../utils/format.dart';
import '../../utils/nav.dart';
import '../../widgets/common.dart';
import '../../utils/haptics.dart';

/// First-time account setup after phone verification:
///  1. About you      → customers/{uid}.name, email
///  2. Home/business  → customers/{uid}.type, businessName, businessType
///  3. Delivery address (optional) → customers/{uid}/addresses/{id}
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _pages = PageController();
  final _forms = List.generate(3, (_) => GlobalKey<FormState>());
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _business = TextEditingController();
  Address? _picked;
  CustomerSegment _type = CustomerSegment.home;
  String _businessType = QuoteRequest.businessTypes.first;
  int _step = 0;
  bool _saving = false;

  static const _titles = [
    (
      'Welcome! What should we call you?',
      'Our riders use your name when they deliver.',
    ),
    (
      'Who are you ordering for?',
      'We tailor sizes, delivery and billing to you.',
    ),
    ('Where should we deliver?', 'Share your location once. No typing needed.'),
  ];

  @override
  void dispose() {
    for (final c in [_name, _email, _business]) {
      c.dispose();
    }
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// Leaves setup: signs out so the customer is never trapped here.
  Future<void> _cancel() async {
    final backend = context.read<Backend>();
    await backend.auth.signOut();
    if (mounted) context.go('/');
  }

  void _next() {
    if (!_forms[_step].currentState!.validate()) return;
    Haptics.select();
    _goTo(_step + 1);
  }

  /// Opens the map picker; it saves the address itself and returns it.
  Future<void> _pickLocation() async {
    // The profile does not exist yet, so the picker saves the address on its
    // own under the signed-in user.
    final a = await context.push<Address>('/location');
    if (a != null && mounted) setState(() => _picked = a);
  }

  Future<void> _finish() async {
    final backend = context.read<Backend>();
    final state = context.read<AppState>();
    final goCheckout = !context.read<Cart>().isEmpty;
    setState(() => _saving = true);
    try {
      await backend.profiles.saveProfile(
        CustomerProfile(
          uid: state.uid!,
          name: _name.text.trim(),
          phone: backend.auth.phone ?? '',
          email: _email.text.trim(),
          type: _type,
          businessName: _type == CustomerSegment.business
              ? _business.text.trim()
              : '',
          businessType: _type == CustomerSegment.business ? _businessType : '',
        ),
        isNew: true,
      );
      if (!mounted) return;
      showMessage(
        context,
        "You're all set, ${_name.text.trim().split(' ').first}!",
      );
      if (goCheckout) {
        context.goHomeThenPush(['/cart', '/checkout']);
      } else {
        context.go('/');
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Could not save: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = context.read<Backend>().auth.phone;
    final (title, subtitle) = _titles[_step];
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(_step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _step > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => _goTo(_step - 1),
                )
              : null,
          automaticallyImplyLeading: false,
          title: Text('Step ${_step + 1} of 3'),
          actions: [
            if (_step == 0)
              TextButton(onPressed: _cancel, child: const Text('Cancel')),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _step ? Brand.blueDark : context.pal.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i < 2) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
        ),
        body: Constrained(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    key: ValueKey(_step),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(color: context.pal.muted),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _page(0, [
                      if (phone != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.pal.card,
                            border: Border.all(color: Brand.success, width: 2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                color: Brand.success,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                context.read<Backend>().auth.isQuick
                                    ? '${prettyPkMobile(phone)} saved'
                                    : '${prettyPkMobile(phone)} verified',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _name,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: tr('Full name'),
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => (v ?? '').trim().length < 2
                            ? tr('Please enter your name')
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: tr('Email (optional)'),
                          helperText: tr('For invoices and receipts'),
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return null;
                          return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(s)
                              ? null
                              : 'That email does not look right';
                        },
                        onFieldSubmitted: (_) => _next(),
                      ),
                    ]),
                    _page(1, [
                      _TypeOption(
                        icon: Icons.home_rounded,
                        title: 'My home',
                        subtitle: '6kg, 10kg and 11.8kg cylinders for cooking and heating',
                        selected: _type == CustomerSegment.home,
                        onTap: () =>
                            setState(() => _type = CustomerSegment.home),
                      ),
                      const SizedBox(height: 12),
                      _TypeOption(
                        icon: Icons.storefront_rounded,
                        title: 'My business',
                        subtitle: 'Restaurants, hotels, bakeries, factories: 45.4kg and bulk supply',
                        selected: _type == CustomerSegment.business,
                        onTap: () =>
                            setState(() => _type = CustomerSegment.business),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        child: _type == CustomerSegment.business
                            ? Padding(
                                padding: const EdgeInsets.only(top: 18),
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _business,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      decoration: InputDecoration(
                                        labelText: tr('Business name'),
                                        prefixIcon: Icon(
                                          Icons.business_rounded,
                                        ),
                                      ),
                                      validator: (v) =>
                                          _type == CustomerSegment.business &&
                                              (v ?? '').trim().isEmpty
                                          ? tr('Please enter the business name')
                                          : null,
                                    ),
                                    const SizedBox(height: 14),
                                    DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      initialValue: _businessType,
                                      decoration: InputDecoration(
                                        labelText: tr('Type of business'),
                                        prefixIcon: Icon(
                                          Icons.category_outlined,
                                        ),
                                      ),
                                      items: [
                                        for (final t
                                            in QuoteRequest.businessTypes)
                                          DropdownMenuItem(
                                            value: t,
                                            child: Text(t),
                                          ),
                                      ],
                                      onChanged: (v) =>
                                          setState(() => _businessType = v!),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ]),
                    _page(2, [
                      _LocationStep(picked: _picked, onPick: _pickLocation),
                    ]),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: _step < 2
                      ? FilledButton(
                          onPressed: _next,
                          child: const Text('Continue'),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_picked == null) ...[
                              FilledButton.icon(
                                onPressed: _saving ? null : _pickLocation,
                                icon: const Icon(Icons.my_location_rounded),
                                label: const Text('Use my current location'),
                              ),
                              TextButton(
                                onPressed: _saving ? null : _finish,
                                child: const Text('Skip for now'),
                              ),
                            ] else
                              FilledButton(
                                onPressed: _saving ? null : _finish,
                                child: const Text('Save & finish'),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _page(int i, List<Widget> children) => Form(
    key: _forms[i],
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: children,
    ),
  );
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
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
      borderRadius: BorderRadius.circular(Brand.radius),
      side: BorderSide(
        color: selected ? Brand.blueDark : context.pal.line,
        width: selected ? 2 : 1,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(Brand.radius),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? Brand.blueDark : context.pal.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : Brand.blueDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: context.pal.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? Brand.blueDark : context.pal.line,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Step 3: one big card instead of a form.
class _LocationStep extends StatelessWidget {
  const _LocationStep({required this.picked, required this.onPick});
  final Address? picked;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    if (picked != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(Brand.radius),
          border: Border.all(color: Brand.success, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: Color(0x1F1E9E5A),
              child: Icon(Icons.check_rounded, color: Brand.success),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    picked!.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(picked!.oneLine, style: TextStyle(color: pal.muted)),
                ],
              ),
            ),
            TextButton(onPressed: onPick, child: const Text('Change')),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        gradient: Brand.headerGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Brand.blueDeep,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.my_location_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Find me on the map',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We pin your location and fill in the address for you. You only confirm.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, height: 1.4),
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _StepChip(Icons.touch_app_rounded, 'One tap'),
              _StepChip(Icons.edit_off_rounded, 'No typing'),
              _StepChip(Icons.delivery_dining_rounded, 'Rider finds you'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Brand.blueDeep,
      borderRadius: BorderRadius.circular(20),
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
