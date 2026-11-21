import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../config/env.dart';
import '../services/backend.dart';
import '../state/app_state.dart';
import '../theme/brand.dart';
import '../utils/format.dart';
import '../utils/launch.dart';
import 'common.dart';

/// Side menu: who you are, where things are, and a quick theme switch.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _go(BuildContext context, String route, {bool tab = false}) {
    Navigator.pop(context); // close the drawer
    tab ? context.go(route) : context.push(route);
  }

  Future<void> _signOut(BuildContext context) async {
    final backend = context.read<Backend>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You can sign back in any time with your mobile number.',
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
    if (ok != true || !context.mounted) return;
    Navigator.pop(context);
    await backend.auth.signOut();
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pal = context.pal;
    final p = state.profile;
    final settings = state.settings;
    return Drawer(
      width: 308,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _Header(state: state),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                children: [
                  _Tile(
                    Icons.local_fire_department_rounded,
                    'Order gas',
                    () => _go(context, '/', tab: true),
                  ),
                  _Tile(
                    Icons.receipt_long_rounded,
                    'My orders',
                    () => _go(context, '/orders', tab: true),
                  ),
                  if (state.signedIn)
                    _Tile(
                      Icons.place_rounded,
                      'Saved locations',
                      () => _go(context, '/account/addresses'),
                    ),
                  _Tile(
                    Icons.factory_rounded,
                    'Business quote',
                    () => _go(context, '/bulk-quote'),
                  ),
                  const _Gap(),
                  _Tile(
                    Icons.health_and_safety_rounded,
                    'Safety guide',
                    () => _go(context, '/safety'),
                  ),
                  _Tile(
                    Icons.help_rounded,
                    'Help & FAQs',
                    () => _go(context, '/help'),
                  ),
                  _Tile(
                    Icons.info_rounded,
                    'About Alpha LPG',
                    () => _go(context, '/about'),
                  ),
                  _Tile(Icons.chat_rounded, 'WhatsApp us', () {
                    Navigator.pop(context);
                    Launch.whatsapp(
                      settings.whatsapp,
                      'Assalam-o-Alaikum, I need help with Alpha LPG.',
                    );
                  }, color: Brand.whatsapp),
                  const _Gap(),
                  _Tile(
                    Icons.settings_rounded,
                    'Settings',
                    () => _go(context, '/settings'),
                  ),
                  const SizedBox(height: 8),
                  const _ThemeSwitch(),
                  if (p != null) ...[
                    const _Gap(),
                    _Tile(
                      Icons.logout_rounded,
                      'Sign out',
                      () => _signOut(context),
                      color: Brand.danger,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Row(
                children: [
                  const BrandLogo(height: 22),
                  const SizedBox(width: 10),
                  Text(
                    'v$kAppVersion',
                    style: TextStyle(color: pal.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = state.profile;
    final initials = (p?.name ?? '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: Brand.headerGradient,
        borderRadius: BorderRadius.only(bottomRight: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandLogo(height: 34, white: true),
              const SizedBox(height: 20),
              if (p != null)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text(
                        initials.isEmpty ? '?' : initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            p.isBusiness && p.businessName.isNotEmpty
                                ? p.businessName
                                : prettyPkMobile(p.phone),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                const Text(
                  'Welcome to Alpha LPG',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign in to order, track and save your locations.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Brand.blueDeep,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/login?from=/');
                  },
                  child: const Text('Sign in with mobile'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.label, this.onTap, {this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: (color ?? Brand.blueDark).withValues(
              alpha: pal.isDark ? 0.22 : 0.1,
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            size: 20,
            color:
                color ??
                (pal.isDark ? const Color(0xFF4DB3F0) : Brand.blueDark),
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color ?? pal.ink,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: Divider(color: context.pal.line, height: 1),
  );
}

/// Three little icons to flip between system, light and dark.
class _ThemeSwitch extends StatelessWidget {
  const _ThemeSwitch();

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final pal = context.pal;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: state.themeMode,
      builder: (context, mode, _) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pal.line),
        ),
        child: Row(
          children: [
            for (final (m, icon, label) in const [
              (ThemeMode.system, Icons.brightness_auto_rounded, 'Auto'),
              (ThemeMode.light, Icons.light_mode_rounded, 'Light'),
              (ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
            ])
              Expanded(
                child: GestureDetector(
                  onTap: () => state.setThemeMode(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: mode == m ? Brand.blueDark : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: mode == m ? Colors.white : pal.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: mode == m ? Colors.white : pal.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
