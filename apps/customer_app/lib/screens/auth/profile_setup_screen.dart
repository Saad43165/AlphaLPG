import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().profile;
    _name = TextEditingController(text: p?.name);
    _business = TextEditingController(text: p?.businessName);
    _email = TextEditingController(text: p?.email);
    _type = p?.type ?? CustomerSegment.home;
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
        phone: backend.auth.phone ?? '',
        type: _type,
        businessName: _type == CustomerSegment.business
            ? _business.text.trim()
            : '',
        businessType: _type == CustomerSegment.business
            ? (state.profile?.businessType ?? '')
            : '',
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? 'Edit profile' : 'Welcome to Alpha LPG'),
        automaticallyImplyLeading: widget.editing,
      ),
      body: Constrained(
        maxWidth: 520,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (!widget.editing) ...[
                Text(
                  'Tell us a little about you so our riders can reach you.',
                  style: text.bodyLarge,
                ),
                const SizedBox(height: 20),
              ],
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v ?? '').trim().length < 2
                    ? 'Please enter your name'
                    : null,
              ),
              const SizedBox(height: 20),
              Text('I am ordering for', style: text.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final t in [
                    CustomerSegment.home,
                    CustomerSegment.business,
                  ])
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: t == CustomerSegment.home ? 6 : 0,
                          left: t == CustomerSegment.business ? 6 : 0,
                        ),
                        child: _TypeCard(
                          icon: t == CustomerSegment.home
                              ? Icons.home_outlined
                              : Icons.storefront_outlined,
                          title: t == CustomerSegment.home
                              ? 'My home'
                              : 'My business',
                          subtitle: t == CustomerSegment.home
                              ? 'Kitchen & heating'
                              : 'Restaurant, hotel, factory…',
                          selected: _type == t,
                          onTap: () => setState(() => _type = t),
                        ),
                      ),
                    ),
                ],
              ),
              if (_type == CustomerSegment.business) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _business,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Business name',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  validator: (v) =>
                      _type == CustomerSegment.business &&
                          (v ?? '').trim().isEmpty
                      ? 'Please enter the business name'
                      : null,
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional, for invoices)',
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
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(widget.editing ? 'Save' : 'Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) => Material(
    color: selected ? Brand.blue.withValues(alpha: 0.1) : context.pal.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: selected ? Brand.blueDark : const Color(0xFFCBD6E2),
        width: selected ? 2 : 1,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Brand.blueDark, size: 28),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}
