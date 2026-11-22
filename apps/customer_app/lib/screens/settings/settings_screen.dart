import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../config/env.dart';
import '../../services/location_service.dart';
import '../../state/app_state.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pal = context.pal;
    return Scaffold(
      appBar: AppBar(
        leading: const ScreenBack(),
        title: const Text('Settings'),
      ),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            const _Heading('Appearance'),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: state.themeMode,
              builder: (context, mode, _) => Row(
                children: [
                  for (final m in const [
                    ThemeMode.light,
                    ThemeMode.dark,
                    ThemeMode.system,
                  ]) ...[
                    Expanded(
                      child: _ThemeTile(
                        mode: m,
                        selected: mode == m,
                        onTap: () => state.setThemeMode(m),
                      ),
                    ),
                    if (m != ThemeMode.system) const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
            const _Heading('Preferences'),
            _Card(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.vibration_rounded),
                  title: const Text('Vibration feedback'),
                  subtitle: const Text(
                    'A light buzz when you tap, add or confirm',
                  ),
                  value: state.haptics,
                  onChanged: state.setHaptics,
                ),
              ],
            ),
            const _Heading('Delivery'),
            _Card(
              children: [
                ListTile(
                  leading: const Icon(Icons.place_rounded),
                  title: const Text('Saved locations'),
                  subtitle: Text(
                    state.addresses.isEmpty
                        ? 'None yet'
                        : '${state.addresses.length} saved',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(
                    state.signedIn
                        ? '/account/addresses'
                        : '/login?from=/settings',
                  ),
                ),
                if (state.signedIn) ...[
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.person_rounded),
                    title: const Text('Edit profile'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/account/edit'),
                  ),
                ],
              ],
            ),
            const _Heading('About'),
            _Card(
              children: [
                ListTile(
                  leading: const Icon(Icons.health_and_safety_rounded),
                  title: const Text('Safety guide'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/safety'),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.info_rounded),
                  title: const Text('About Alpha LPG'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/about'),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.verified_rounded),
                  title: const Text('Version'),
                  trailing: Text(
                    kAppVersion,
                    style: TextStyle(
                      color: pal.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                context.read<LocationService>().attribution,
                style: TextStyle(color: pal.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w700,
        color: context.pal.muted,
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.pal.card,
      borderRadius: BorderRadius.circular(Brand.radius),
      boxShadow: context.pal.shadow,
      border: context.pal.isDark ? Border.all(color: context.pal.line) : null,
    ),
    clipBehavior: Clip.antiAlias,
    // Lets list-tile ripples paint on top of the card colour.
    child: Material(
      type: MaterialType.transparency,
      child: Column(children: children),
    ),
  );
}

/// A tiny phone mock-up in the theme's own colours.
class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final (label, icon) = switch (mode) {
      ThemeMode.light => ('Light', Icons.light_mode_rounded),
      ThemeMode.dark => ('Dark', Icons.dark_mode_rounded),
      ThemeMode.system => ('Auto', Icons.brightness_auto_rounded),
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Brand.blueDark : pal.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 78,
              child: Row(
                children: [
                  if (mode != ThemeMode.dark)
                    Expanded(
                      child: _Mini(
                        AppPalette.light,
                        round: mode == ThemeMode.system
                            ? const BorderRadius.horizontal(
                                left: Radius.circular(10),
                              )
                            : BorderRadius.circular(10),
                      ),
                    ),
                  if (mode != ThemeMode.light)
                    Expanded(
                      child: _Mini(
                        AppPalette.night,
                        round: mode == ThemeMode.system
                            ? const BorderRadius.horizontal(
                                right: Radius.circular(10),
                              )
                            : BorderRadius.circular(10),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Brand.blueDark : pal.muted,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Brand.blueDark : pal.ink,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.pal, {required this.round});
  final AppPalette pal;
  final BorderRadius round;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: pal.surface,
      borderRadius: round,
      border: Border.all(color: pal.line),
    ),
    padding: const EdgeInsets.all(7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 6,
          width: 26,
          decoration: BoxDecoration(
            color: Brand.blueDark,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: pal.line),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Container(height: 5, color: pal.line),
      ],
    ),
  );
}
