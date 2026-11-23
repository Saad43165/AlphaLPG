import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/launch.dart';
import '../widgets/common.dart';
import 'account_screen.dart';
import 'battery_guide_screen.dart';
import 'available_screen.dart';
import 'history_screen.dart';
import 'jobs_screen.dart';

/// Header with the on/off-shift switch, a location banner, and four tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RiderSession>();
    final pal = context.pal;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Brand.lightStatusBar,
      child: Scaffold(
        body: Column(
          children: [
            _Header(session: s),
            _Notices(session: s),
            if (s.showBatteryTip) _BatteryTip(session: s),
            _LocationBanner(session: s),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  JobsScreen(onFindJobs: () => setState(() => _tab = 1)),
                  AvailableScreen(onAccepted: () => setState(() => _tab = 0)),
                  const HistoryScreen(),
                  const AccountScreen(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            NavigationDestination(
              icon: Badge.count(
                count: s.jobs.length,
                isLabelVisible: s.jobs.isNotEmpty,
                child: const Icon(Icons.two_wheeler_outlined),
              ),
              selectedIcon: Badge.count(
                count: s.jobs.length,
                isLabelVisible: s.jobs.isNotEmpty,
                child: const Icon(Icons.two_wheeler_rounded),
              ),
              label: 'My jobs',
            ),
            NavigationDestination(
              icon: Badge.count(
                count: s.available.length,
                isLabelVisible: s.available.isNotEmpty && s.online,
                backgroundColor: Brand.cylinderRed,
                child: const Icon(Icons.notifications_none_rounded),
              ),
              selectedIcon: Badge.count(
                count: s.available.length,
                isLabelVisible: s.available.isNotEmpty && s.online,
                backgroundColor: Brand.cylinderRed,
                child: const Icon(Icons.notifications_rounded),
              ),
              label: 'New',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined, color: pal.muted),
              selectedIcon: const Icon(Icons.receipt_long_rounded),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: pal.muted),
              selectedIcon: const Icon(Icons.person_rounded),
              label: 'Me',
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session});
  final RiderSession session;

  @override
  Widget build(BuildContext context) {
    final online = session.online;
    final name = (session.profile?.name ?? '').split(' ').first;
    return Container(
      decoration: const BoxDecoration(
        gradient: Brand.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Rider' : 'Salam $name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      online
                          ? 'You are online and can take orders'
                          : 'You are offline',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Switch(
                    value: online,
                    activeTrackColor: Brand.success,
                    inactiveTrackColor: Brand.blueDeep,
                    onChanged: (v) async {
                      HapticFeedback.selectionClick();
                      if (!v &&
                          session.onRoadCount == 0 &&
                          session.notStarted.isNotEmpty) {
                        // Orders not started yet: give them back, or stay.
                        final n = session.notStarted.length;
                        final go = await showDialog<bool>(
                          context: context,
                          builder: (d) => AlertDialog(
                            title: const Text('Go offline?'),
                            content: Text(
                              n == 1
                                  ? 'You have 1 order you have not started. It goes back to the shop so another rider can take it.'
                                  : 'You have $n orders you have not started. They go back to the shop so other riders can take them.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(d, false),
                                child: const Text('Stay online'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(d, true),
                                child: const Text('Give back and go offline'),
                              ),
                            ],
                          ),
                        );
                        if (go != true || !context.mounted) return;
                        if (!await session.releaseNotStarted()) {
                          if (context.mounted) {
                            showMessage(
                              context,
                              'Could not give the orders back. Check your internet.',
                              error: true,
                            );
                          }
                          return;
                        }
                      }
                      final err = await session.setOnline(v);
                      if (err != null && context.mounted) {
                        showMessage(context, err, error: true);
                      }
                    },
                  ),
                  Text(
                    online ? 'ONLINE' : 'OFFLINE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
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

/// Green while sharing location; red if sharing should be on but cannot start.
class _LocationBanner extends StatelessWidget {
  const _LocationBanner({required this.session});
  final RiderSession session;

  @override
  Widget build(BuildContext context) {
    final problem = session.trackingProblem;
    if (problem != null) {
      return StatusStrip(
        icon: Icons.location_off_rounded,
        color: Brand.danger,
        text: 'Location is off',
        detail: problem,
        actions: [
          StatusStrip.action(
            context,
            'Settings',
            session.tracker.openSettings,
            Brand.danger,
          ),
          StatusStrip.action(
            context,
            'Retry',
            session.retryTracking,
            Brand.danger,
          ),
        ],
      );
    }
    final t = session.tracker;
    if (t.isTracking) {
      final err = t.lastError;
      final sent = t.lastShared;
      // Honest status: waiting, working, or failing (with the reason).
      final (color, icon, text, detail) = err != null
          ? (Brand.danger, Icons.location_off_rounded, 'Location problem', err)
          : sent == null
          ? (
              Brand.warning,
              Icons.location_searching_rounded,
              'Finding your position…',
              null,
            )
          : (
              Brand.success,
              Icons.my_location_rounded,
              'Live location is on',
              'Customers can follow you · updated ${timeAgo(sent)}',
            );
      return StatusStrip(
        icon: icon,
        color: color,
        text: text,
        detail: detail,
        actions: [
          if (err != null)
            StatusStrip.action(context, 'Retry', session.retryTracking, color),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

/// Messages from the shop: "you were switched offline", "shop is closed".
class _Notices extends StatelessWidget {
  const _Notices({required this.session});
  final RiderSession session;

  @override
  Widget build(BuildContext context) {
    final closed = !session.settings.acceptingOrders;
    final note = session.notice;
    if (!closed && note == null) return const SizedBox.shrink();
    Widget bar(
      IconData icon,
      Color color,
      String text, {
      VoidCallback? onClose,
    }) => StatusStrip(
      icon: icon,
      color: color,
      text: text,
      actions: [
        if (onClose != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
      ],
    );
    return Column(
      children: [
        if (note != null)
          bar(
            Icons.power_settings_new_rounded,
            Brand.danger,
            note,
            onClose: session.dismissNotice,
          ),
        if (closed)
          bar(
            Icons.storefront_rounded,
            Brand.warning,
            'Alpha LPG is closed for orders. No new jobs will come in.',
          ),
      ],
    );
  }
}

/// Shown once: how to stop the phone closing the app.
class _BatteryTip extends StatelessWidget {
  const _BatteryTip({required this.session});
  final RiderSession session;

  @override
  Widget build(BuildContext context) => StatusStrip(
    icon: Icons.battery_alert_rounded,
    color: Brand.flame,
    text: 'Do this once so you never miss a job.',
    actions: [
      StatusStrip.action(context, 'Show me', () {
        session.dismissBatteryTip();
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BatteryGuideScreen()),
        );
      }, Brand.flame),
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'Close',
        onPressed: session.dismissBatteryTip,
        icon: const Icon(Icons.close_rounded, size: 18),
      ),
    ],
  );
}
