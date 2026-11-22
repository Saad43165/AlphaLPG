import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/launch.dart';
import '../utils/version.dart';
import '../widgets/common.dart';
import 'battery_guide_screen.dart';
import 'guide_screen.dart';
import 'earnings_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RiderSession>();
    final p = s.profile;
    final pal = context.pal;
    final shop = s.settings;
    final initials = (p?.name ?? '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Constrained(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: panel(context),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Brand.navy,
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
                        p?.name ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        prettyPhone(p?.phone ?? ''),
                        style: TextStyle(color: pal.muted),
                      ),
                      Text(
                        '${p?.vehicle ?? ''} · ${s.backend.auth.email ?? ''}',
                        style: TextStyle(color: pal.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: panel(context),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.bar_chart_rounded,
                      color: Brand.blueDark,
                    ),
                    title: const Text(
                      'My earnings and cash',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Deliveries, cash to hand in, ratings',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: s,
                          child: const EarningsScreen(),
                        ),
                      ),
                    ),
                  ),
                  Divider(height: 1, indent: 66, color: pal.line),
                  ListTile(
                    leading: const Icon(
                      Icons.menu_book_rounded,
                      color: Brand.blueDark,
                    ),
                    title: const Text(
                      'How the app works',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Guide in English and اردو'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GuideScreen(shopPhone: shop.phone),
                      ),
                    ),
                  ),
                  Divider(height: 1, indent: 66, color: pal.line),
                  ListTile(
                    leading: const Icon(
                      Icons.battery_charging_full_rounded,
                      color: Brand.blueDark,
                    ),
                    title: const Text(
                      'Keep the app running',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Do this once so you never miss a job',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BatteryGuideScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Heading('Appearance'),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: s.themeMode,
            builder: (context, mode, _) => SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded),
                  label: Text('Auto'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded),
                  label: Text('Dark'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (v) => s.setThemeMode(v.first),
            ),
          ),
          const Heading('Need help?'),
          Container(
            decoration: panel(context),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.call_rounded),
                    title: const Text('Call Alpha LPG'),
                    subtitle: Text(shop.phone),
                    onTap: () => Launch.call(shop.phone),
                  ),
                  Divider(
                    color: pal.line,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  ListTile(
                    leading: const WhatsAppIcon(size: 26),
                    title: const Text('WhatsApp Alpha LPG'),
                    onTap: () => Launch.whatsapp(
                      shop.whatsapp,
                      'Assalam-o-Alaikum, this is rider ${p?.name ?? ''}.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Heading('Location sharing'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: panel(context),
            child: Text(
              'Your location is shared with the customer only while an order is "On the way", and stops when you mark it delivered. It is never shared when you have no active delivery.',
              style: TextStyle(color: pal.muted, height: 1.45),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Brand.danger),
            onPressed: () async {
              Navigator.of(context).popUntil((r) => r.isFirst);
              await s.signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Alpha LPG Rider v$kRiderVersion',
              style: TextStyle(color: pal.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
