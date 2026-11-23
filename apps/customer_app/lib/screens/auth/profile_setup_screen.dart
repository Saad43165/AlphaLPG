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
import '../../widgets/common.dart';

/// Shown once after first sign-in, and reused for "Edit profile".
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, this.editing = false});
  final bool editing;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _business;
  late final TextEditingController _email;
  CustomerSegment _type = CustomerSegment.home;
  String _businessType = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().profile;
    _name = TextEditingController(text: p?.name);
    _business = TextEditingController(text: p?.businessName);
    _email = TextEditingController(text: p?.email);
    _type = p?.type ?? CustomerSegment.home;
    _businessType = p?.businessType ?? '';
    for (final c in [_name, _business, _email]) {
      c.addListener(_onEdit);
    }
  }

  void _onEdit() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _business.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final backend = context.read<Backend>();
    final state = context.read<AppState>();
    setState(() => _busy = true);
    try {
      final profile = CustomerProfile(
        uid: state.uid!,
        name: _name.text.trim(),
        phone: _phone(),
        type: _type,
        businessName: _type == CustomerSegment.business
            ? _business.text.trim()
            : '',
        businessType: _type == CustomerSegment.business ? _businessType : '',
        email: _email.text.trim(),
      );
      await backend.profiles.saveProfile(profile, isNew: state.profile == null);
      if (!mounted) return;
      if (widget.editing) {
        context.pop();
        showMessage(context, 'Profile updated');
      } else {
        context.go(context.read<Cart>().isEmpty ? '/' : '/checkout');
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Could not save: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The number to save and show. Quick sign-in forgets the typed number when
  /// the app restarts, so fall back to the one already on the profile.
  String _phone() {
    final fromAuth = context.read<Backend>().auth.phone ?? '';
    if (fromAuth.isNotEmpty) return fromAuth;
    return context.read<AppState>().profile?.phone ?? '';
  }

  static String _prettyPhone(String phone) {
    final d = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length == 12 && d.startsWith('92')) {
      return '+92 ${d.substring(2, 5)} ${d.substring(5)}';
    }
    return phone;
  }

  /// True when something differs from the saved profile (editing only).
  bool get _changed {
    final p = context.read<AppState>().profile;
    if (p == null) return true;
    return _name.text.trim() != p.name ||
        _email.text.trim() != p.email ||
        _type != p.type ||
        _businessType != p.businessType ||
        (_type == CustomerSegment.business &&
            _business.text.trim() != p.businessName);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pal = context.pal;
    final phone = _phone();
    final canSave = !_busy && (!widget.editing || _changed);
    return Scaffold(
      appBar: AppBar(
        leading: const ScreenBack(),
        title: Text(widget.editing ? 'Edit profile' : 'Welcome to Alpha LPG'),
        automaticallyImplyLeading: widget.editing,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: FilledButton(
            onPressed: canSave ? _save : null,
            child: _busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(widget.editing ? 'Save changes' : 'Continue'),
          ),
        ),
      ),
      body: Constrained(
        maxWidth: 520,
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // Who you are: avatar, number (read-only, verified).
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                decoration: BoxDecoration(
                  gradient: Brand.headerGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Brand.blueDeep.withValues(alpha: 0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ListenableBuilder(
                      listenable: _name,
                      builder: (_, _) => Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: Brand.navy,
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 46,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListenableBuilder(
                      listenable: _name,
                      builder: (_, _) => Text(
                        _name.text.trim().isEmpty
                            ? tr('Your name')
                            : _name.text.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!context.read<Backend>().auth.isQuick)
                              const Padding(
                                padding: EdgeInsetsDirectional.only(end: 6),
                                child: Icon(
                                  Icons.verified_rounded,
                                  size: 18,
                                  color: Brand.success,
                                ),
                              ),
                            Flexible(
                              child: Text(
                                _prettyPhone(phone),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Brand.navy,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.read<Backend>().auth.isQuick
                            ? 'Our rider calls this number.'
                            : 'Verified number. You sign in with it.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!widget.editing) ...[
                const SizedBox(height: 14),
                Text(
                  'Tell us a little about you so our riders can reach you.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: pal.muted),
                ),
              ],
              const SizedBox(height: 18),
              _SectionCard(
                title: 'Your details',
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: tr('Your name'),
                      prefixIcon: Icon(Icons.person_outline),
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
                      helperText: tr('Used to send you invoices'),
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return null;
                      return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)
                          ? null
                          : 'That email does not look right';
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'I am ordering for',
                children: [
                  SizedBox(
                    height:
                        (Lang.isUrdu ? 132 : 108) *
                        (MediaQuery.textScalerOf(context).scale(1) > 1.2
                            ? 1.8
                            : 1),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TypeCard(
                            icon: Icons.home_rounded,
                            title: 'My home',
                            subtitle: 'Kitchen & heating',
                            selected: _type == CustomerSegment.home,
                            onTap: () =>
                                setState(() => _type = CustomerSegment.home),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TypeCard(
                            icon: Icons.storefront_rounded,
                            title: 'My business',
                            subtitle: 'Restaurant, hotel, factory',
                            selected: _type == CustomerSegment.business,
                            onTap: () => setState(
                              () => _type = CustomerSegment.business,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _type == CustomerSegment.business
                        ? Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _business,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    labelText: tr('Business name'),
                                    prefixIcon: Icon(Icons.business_outlined),
                                  ),
                                  validator: (v) =>
                                      _type == CustomerSegment.business &&
                                          (v ?? '').trim().isEmpty
                                      ? tr('Please enter the business name')
                                      : null,
                                ),
                                const SizedBox(height: 14),
                                DropdownButtonFormField<String>(
                                  initialValue:
                                      QuoteRequest.businessTypes.contains(
                                        _businessType,
                                      )
                                      ? _businessType
                                      : null,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: tr('Type of business'),
                                    prefixIcon: Icon(Icons.category_outlined),
                                  ),
                                  items: [
                                    for (final t in QuoteRequest.businessTypes)
                                      DropdownMenuItem(
                                        value: t,
                                        child: Text(t),
                                      ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _businessType = v ?? ''),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled, rounded group of fields.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    decoration: BoxDecoration(
      color: context.pal.card,
      borderRadius: BorderRadius.circular(Brand.radius),
      boxShadow: context.pal.shadow,
      border: context.pal.isDark ? Border.all(color: context.pal.line) : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
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
        color: selected ? Brand.blueDark : pal.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? Brand.blueDark : pal.line,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      color: selected ? Colors.white : pal.muted,
                      size: 26,
                    ),
                    const Spacer(),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 20,
                      color: selected ? Colors.white : pal.muted,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: selected ? Colors.white : pal.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : pal.muted,
                    fontSize: 12,
                    height: 1.25,
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
