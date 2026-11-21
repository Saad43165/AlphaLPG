import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/launch.dart';
import '../widgets/common.dart';
import 'account_screen.dart';
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
          padding: const EdgeInsets.fromLTRB(18, 8, 14, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandLogo(height: 30, white: true),
                    const SizedBox(height: 10),
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
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Switch(
                    value: online,
                    activeTrackColor: Brand.success,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      session.setOnline(v);
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
      return Container(
        width: double.infinity,
        color: const Color(0xFFFFEEEB),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.location_off_rounded, color: Brand.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                problem,
                style: const TextStyle(
                  color: Color(0xFF7A1F1F),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: session.tracker.openSettings,
              child: const Text('Settings'),
            ),
            TextButton(
              onPressed: session.retryTracking,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final t = session.tracker;
    if (t.isTracking) {
      final err = t.lastError;
      final sent = t.lastShared;
      // Honest status: waiting, working, or failing (with the reason).
      final (color, icon, text) = err != null
          ? (Brand.danger, Icons.location_off_rounded, err)
          : sent == null
          ? (
              const Color(0xFF8A6D00),
              Icons.location_searching_rounded,
              'Finding your position…',
            )
          : (
              Brand.success,
              Icons.my_location_rounded,
              'Sharing live location · updated ${timeAgo(sent)}',
            );
      return Container(
        width: double.infinity,
        color: color.withValues(alpha: 0.14),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            if (err != null)
              TextButton(
                onPressed: session.retryTracking,
                child: const Text('Retry'),
              ),
          ],
        ),
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
    }) => Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.14),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          if (onClose != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: Icon(Icons.close_rounded, color: color, size: 18),
            ),
        ],
      ),
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
            const Color(0xFF8A6D00),
            'Alpha LPG is closed for orders. No new jobs will come in.',
          ),
      ],
    );
  }
}
