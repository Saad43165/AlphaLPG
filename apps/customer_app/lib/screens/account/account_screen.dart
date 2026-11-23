import 'package:alpha_ui/alpha_ui.dart' show WhatsAppIcon;

import '../../l10n/lang.dart';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Text;

import '../../l10n/text.dart';

import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../theme/brand.dart';
import '../../utils/format.dart';
import '../../utils/launch.dart';
import '../../widgets/common.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.profile;
    final s = state.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!state.signedIn)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Sign in to place orders, save addresses and track deliveries.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.push('/login?from=/account'),
                        child: const Text('Sign in with mobile number'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: Brand.blueDark,
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  title: Text(
                    p?.displayName ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      if (p != null) prettyPkMobile(p.phone),
                      if (p != null) p.type.label,
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: tr('Edit profile'),
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push('/account/edit'),
                  ),
                ),
              ),
            if (state.signedIn) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _quick(
                      context,
                      Icons.receipt_long_rounded,
                      'Orders',
                      () => context.go('/orders'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _quick(
                      context,
                      Icons.location_on_rounded,
                      'Addresses',
                      () => context.push('/account/addresses'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _quick(
                      context,
                      Icons.support_agent_rounded,
                      'Help',
                      () => context.push('/support'),
                    ),
                  ),
                ],
              ),
              const SectionTitle('Offers and business'),
              Card(
                child: Column(
                  children: [
                    _tile(
                      context,
                      Icons.card_giftcard_rounded,
                      s.pointsEnabled
                          ? 'Rewards and invite friends'
                          : 'Invite friends',
                      '/rewards',
                    ),
                    if (s.planEnabled)
                      _tile(
                        context,
                        Icons.event_repeat_rounded,
                        'Refill plan',
                        '/plan',
                      ),
                    _tile(
                      context,
                      Icons.factory_outlined,
                      'Bulk / business quote (we reply with a price)',
                      '/bulk-quote',
                    ),
                  ],
                ),
              ),
            ],
            const SectionTitle('Alpha LPG'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const WhatsAppIcon(size: 26),
                    title: const Text('WhatsApp'),
                    subtitle: Text(prettyPkMobile('+${s.whatsapp}')),
                    onTap: () => Launch.whatsapp(s.whatsapp),
                  ),
                  ListTile(
                    leading: const Icon(Icons.call_outlined),
                    title: const Text('Call'),
                    subtitle: Text(s.phone),
                    onTap: () => Launch.call(s.phone),
                  ),
                  ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: const Text('Email'),
                    subtitle: Text(s.email),
                    onTap: () =>
                        Launch.email(s.email, subject: 'Alpha LPG app'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: const Text('Visit our shop'),
                    subtitle: Text('${s.shopAddress}\n${s.openingHours}'),
                    isThreeLine: true,
                    onTap: () =>
                        Launch.maps(query: 'Alpha LPG ${s.shopAddress}'),
                  ),
                  _tile(
                    context,
                    Icons.menu_book_rounded,
                    'How to use the app',
                    '/guide',
                  ),
                  _tile(
                    context,
                    Icons.health_and_safety_outlined,
                    'LPG safety guide',
                    '/safety',
                  ),
                  _tile(
                    context,
                    Icons.settings_rounded,
                    'Settings',
                    '/settings',
                  ),
                  _tile(
                    context,
                    Icons.help_outline_rounded,
                    'Help & FAQs',
                    '/help',
                  ),
                  _tile(
                    context,
                    Icons.info_outline_rounded,
                    'About Alpha LPG',
                    '/about',
                  ),
                  _tile(
                    context,
                    Icons.privacy_tip_outlined,
                    'Privacy policy',
                    '/privacy',
                  ),
                  _tile(
                    context,
                    Icons.description_outlined,
                    'Terms of service',
                    '/terms',
                  ),
                ],
              ),
            ),
            if (state.signedIn) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () async {
                  final auth = context.read<Backend>().auth;
                  if (auth.isQuick) {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Sign out?'),
                        content: const Text(
                          'Signing out removes your order history from this phone. You can still place new orders by entering your number again.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Stay'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Sign out'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                  }
                  await auth.signOut();
                  if (context.mounted) context.go('/');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
              const SizedBox(height: 6),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Brand.danger),
                onPressed: () => _deleteAccount(context),
                child: const Text('Delete my account'),
              ),
            ],
            const SizedBox(height: 20),
            const Center(child: BrandLogo(height: 36)),
            const SizedBox(height: 6),
            Text(
              'Reliable LPG for homes and businesses across Lahore.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.pal.muted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final backend = context.read<Backend>();
    final uid = backend.auth.uid;
    if (uid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (ok != true || !context.mounted) return;
    try {
      await backend.profiles.deleteAccountData(uid);
      await backend.auth.deleteAccount();
      if (context.mounted) {
        context.go('/');
        showMessage(context, 'Your account has been deleted.');
      }
    } catch (e) {
      if (context.mounted) {
        showMessage(
          context,
          e is AuthException ? e.message : 'Could not delete your account. Please check your internet and try again.',
          error: true,
        );
      }
    }
  }

  /// A big square button for the three things used most.
  Widget _quick(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) => Container(
    decoration: BoxDecoration(
      color: context.pal.card,
      borderRadius: BorderRadius.circular(Brand.radius),
      boxShadow: context.pal.shadow,
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(Brand.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: context.pal.tint,
                child: Icon(icon, color: context.pal.blue, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String route, {
    bool go = false,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => go ? context.go(route) : context.push(route),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Delete your account?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This removes your profile, saved locations and sign-in. '
          'You will not be able to see your old orders. '
          'Orders already placed are kept for the shop\'s records.\n\n'
          'Type DELETE to confirm.',
          style: TextStyle(height: 1.4),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _c,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: tr('DELETE')),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Keep my account'),
      ),
      TextButton(
        style: TextButton.styleFrom(foregroundColor: Brand.danger),
        onPressed: _c.text.trim().toUpperCase() == 'DELETE'
            ? () => Navigator.pop(context, true)
            : null,
        child: const Text('Delete'),
      ),
    ],
  );
}
