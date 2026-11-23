import 'package:alpha_ui/alpha_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/common.dart';

/// Step-by-step: stop the phone from killing the app, so new jobs always
/// arrive and the customer can follow the rider.
class BatteryGuideScreen extends StatelessWidget {
  const BatteryGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    Widget step(int n, String title, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Brand.blueDark,
            child: Text(
              '$n',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(text, style: TextStyle(color: pal.muted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Keep the app running')),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.pal.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.pal.warn, width: 2),
              ),
              child: Text(
                'Many phones close apps in the background to save battery. If that happens, you will miss new jobs and customers cannot see where you are. Do these steps once.',
                style: TextStyle(
                  color: context.pal.ink,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 18),
            step(
              1,
              'Open the app settings',
              'Tap the button below. It opens this app\'s page in your phone settings.',
            ),
            step(
              2,
              'Battery: choose "Unrestricted" or "No restrictions"',
              'Go to Battery (or "App battery usage") and pick Unrestricted / Don\'t optimise. Do not choose "Optimised" or "Restricted".',
            ),
            step(
              3,
              'Location: "Allow all the time"',
              'Go to Permissions, then Location, and choose "Allow all the time". Also keep "Use precise location" on.',
            ),
            step(
              4,
              'Notifications: allowed',
              'Make sure notifications are on, so you hear new jobs.',
            ),
            step(
              5,
              'Xiaomi / Redmi / Oppo / Vivo / Realme / Infinix / Tecno',
              'Also turn on "Autostart" for this app, and in the recent apps screen long-press the app card and tap the lock icon so it is not cleared.',
            ),
            step(
              6,
              'Turn off Battery Saver on shift',
              'Battery Saver / Power Saving mode can stop location. Switch it off while you are online.',
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: Geolocator.openAppSettings,
              icon: const Icon(Icons.settings_rounded),
              label: const Text('Open app settings'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: Geolocator.openLocationSettings,
              icon: const Icon(Icons.location_on_rounded),
              label: const Text('Open phone location settings'),
            ),
          ],
        ),
      ),
    );
  }
}
