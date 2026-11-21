import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

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
                    backgroundColor: Brand.blue,
                    child: Text(
                      (p?.name.isNotEmpty ?? false)
                          ? p!.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
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
                    tooltip: 'Edit profile',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push('/account/edit'),
                  ),
                ),
              ),
            if (state.signedIn) ...[
              const SectionTitle('My account'),
              Card(
                child: Column(
                  children: [
                    _tile(
                      context,
                      Icons.location_on_outlined,
                      'Saved addresses',
                      '/account/addresses',
                    ),
                    _tile(
                      context,
                      Icons.receipt_long_outlined,
                      'Order history',
                      '/orders',
                      go: true,
                    ),
                    _tile(
                      context,
                      Icons.factory_outlined,
                      'Bulk / business quote',
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
                    leading: const Icon(Icons.chat, color: Brand.whatsapp),
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
                ],
              ),
            ),
            if (state.signedIn) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () async {
                  await context.read<Backend>().auth.signOut();
                  if (context.mounted) context.go('/');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
            const SizedBox(height: 20),
            const Center(child: BrandLogo(height: 36)),
            const SizedBox(height: 6),
            const Text(
              'Reliable LPG for homes and businesses across Lahore.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

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
