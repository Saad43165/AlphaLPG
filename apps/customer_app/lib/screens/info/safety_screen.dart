import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/brand.dart';
import '../../utils/launch.dart';
import '../../widgets/common.dart';

/// Content follows Alpha LPG's "Use LPG safely. Every single day." poster.
/// Illustrations are vector icons so they stay sharp on every screen.
class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

typedef SafetyTip = (IconData icon, String title, String body);

/// The four essentials from the poster (also used on the home screen).
const safetyEssentials = <SafetyTip>[
  (
    Icons.propane_tank_rounded,
    'Keep it upright',
    'Always keep the cylinder upright on a stable, level surface.',
  ),
  (
    Icons.air_rounded,
    'Keep it ventilated',
    'Never keep LPG in a closed or poorly ventilated space.',
  ),
  (
    Icons.plumbing_rounded,
    'Check connections',
    'Regularly check the regulator, hose and connections for any damage.',
  ),
  (
    Icons.power_settings_new_rounded,
    'Turn it off',
    'Close the cylinder and regulator when LPG is not being used.',
  ),
];

class _SafetyScreenState extends State<SafetyScreen> {
  bool _showDos = true;

  static const _dos = <SafetyTip>[
    (
      Icons.propane_tank_rounded,
      'Keep cylinders upright',
      'On a stable, level surface.',
    ),
    (
      Icons.build_circle_rounded,
      'Keep everything in good condition',
      'Cylinder, regulator and hose. Replace anything damaged.',
    ),
    (
      Icons.local_fire_department_rounded,
      'Keep away from heat',
      'Away from excessive heat and ignition sources.',
    ),
  ];

  static const _donts = <SafetyTip>[
    (
      Icons.door_sliding_rounded,
      "Don't store in enclosed spaces",
      'Not in cabinets, cupboards or basements.',
    ),
    (
      Icons.whatshot_rounded,
      "Don't use a flame to check for leaks",
      'Use soapy water instead. Bubbles mean a leak.',
    ),
    (
      Icons.inventory_2_rounded,
      "Don't keep spares next to it",
      'Not directly next to the cylinder in use.',
    ),
  ];

  static const _emergency = <SafetyTip>[
    (
      Icons.power_settings_new_rounded,
      'Turn off the gas supply',
      'If it is safe to do so, close the cylinder valve and regulator.',
    ),
    (
      Icons.fire_extinguisher_rounded,
      'Extinguish flames',
      'Put out all flames and turn off ignition sources (stoves, candles, etc).',
    ),
    (
      Icons.window_rounded,
      'Ventilate the area',
      'Open doors and windows to let fresh air circulate.',
    ),
    (
      Icons.flash_off_rounded,
      'Avoid sparks',
      'Do not operate electrical switches or anything that could create a spark.',
    ),
    (
      Icons.support_agent_rounded,
      'Seek assistance',
      'Move away from the area and contact Alpha LPG or Rescue 1122.',
    ),
  ];

  static const _leakTest = <SafetyTip>[
    (
      Icons.water_drop_rounded,
      'Mix soapy water',
      'A little dish soap in a cup of water.',
    ),
    (
      Icons.brush_rounded,
      'Apply to joints',
      'Brush it on the valve, regulator and hose ends.',
    ),
    (
      Icons.bubble_chart_rounded,
      'Watch for bubbles',
      'Bubbles mean a leak: turn off the gas and call us.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().settings;
    final wide = MediaQuery.sizeOf(context).width > 640;
    return Scaffold(
      appBar: AppBar(title: const Text('Safety guide')),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            const _Hero(),
            const SizedBox(height: 18),
            _EmergencyCard(steps: _emergency, phone: s.phone),
            const _Kicker('THE ESSENTIALS', '4 things to always remember'),
            GridView.count(
              crossAxisCount: wide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
              children: [
                for (final (i, t) in safetyEssentials.indexed)
                  _EssentialCard(number: i + 1, tip: t),
              ],
            ),
            const _Kicker('SAFE HABITS', "Do's and don'ts"),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.check_circle_rounded),
                  label: Text('Do'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.cancel_rounded),
                  label: Text("Don't"),
                ),
              ],
              selected: {_showDos},
              onSelectionChanged: (v) => setState(() => _showDos = v.first),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Column(
                key: ValueKey(_showDos),
                children: [
                  for (final t in _showDos ? _dos : _donts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HabitRow(tip: t, good: _showDos),
                    ),
                ],
              ),
            ),
            const _Kicker('CHECK FOR LEAKS', 'The safe soap-water test'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.pal.card,
                borderRadius: BorderRadius.circular(Brand.radius),
                boxShadow: context.pal.shadow,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, (icon, title, body)) in _leakTest.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        children: [
                          _IconBubble(icon, color: Brand.blueDark, size: 52),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            body,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.pal.muted,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => context.push('/safety/poster'),
              icon: const Icon(Icons.zoom_in_rounded),
              label: const Text('View the full safety poster'),
            ),
            const SizedBox(height: 22),
            _OrderSafelyCard(whatsapp: s.whatsapp),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 190),
    decoration: BoxDecoration(
      gradient: Brand.headerGradient,
      borderRadius: BorderRadius.circular(24),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned(
          right: -6,
          bottom: -14,
          child: Image.asset('assets/products/11_8kg.png', height: 190),
        ),
        const Positioned(
          right: 92,
          top: 18,
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Icon(Icons.check_rounded, color: Brand.success),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 150, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Use LPG safely.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -0.6,
                ),
              ),
              Text(
                'Every single day.',
                style: TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.6,
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Simple precautions make LPG safer to store, handle and use at home.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _IconBubble extends StatelessWidget {
  const _IconBubble(this.icon, {required this.color, this.size = 46});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(size * 0.32),
    ),
    child: Icon(icon, color: color, size: size * 0.52),
  );
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.kicker, this.title);
  final String kicker;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 28, 2, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kicker,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: context.pal.muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    ),
  );
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.steps, required this.phone});
  final List<SafetyTip> steps;
  final String phone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEEEB),
      borderRadius: BorderRadius.circular(Brand.radius),
      border: Border.all(color: const Color(0xFFFAD0C9)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'IN AN EMERGENCY',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: Brand.cylinderRed,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Smell gas? Know what to do.',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Stay calm and follow these steps:',
          style: TextStyle(color: context.pal.muted),
        ),
        const SizedBox(height: 12),
        for (final (i, (icon, title, body)) in steps.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.pal.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: i == 4 ? Brand.blueDark : Brand.cylinderRed,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i + 1}. $title',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        body,
                        style: TextStyle(
                          color: context.pal.muted,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Brand.cylinderRed,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Launch.call('1122'),
                icon: const Icon(Icons.emergency_rounded),
                label: const Text('Rescue 1122'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Launch.call(phone),
                icon: const Icon(Icons.call_rounded),
                label: const Text('Alpha LPG'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _EssentialCard extends StatelessWidget {
  const _EssentialCard({required this.number, required this.tip});
  final int number;
  final SafetyTip tip;

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = tip;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.pal.card,
        borderRadius: BorderRadius.circular(Brand.radius),
        boxShadow: context.pal.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(icon, color: Brand.blueDark),
              const Spacer(),
              Text(
                number.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Brand.blueLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              body,
              overflow: TextOverflow.fade,
              style: TextStyle(
                color: context.pal.muted,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({required this.tip, required this.good});
  final SafetyTip tip;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = tip;
    final color = good ? Brand.success : Brand.cylinderRed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.pal.card,
        borderRadius: BorderRadius.circular(Brand.radius),
        boxShadow: context.pal.shadow,
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _IconBubble(
                icon,
                color: good ? Brand.blueDark : Brand.cylinderRed,
                size: 52,
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.pal.card,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    good ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: color,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  good ? 'DO' : "DON'T",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(color: context.pal.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSafelyCard extends StatelessWidget {
  const _OrderSafelyCard({required this.whatsapp});
  final String whatsapp;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Brand.navy,
      borderRadius: BorderRadius.circular(Brand.radius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandLogo(height: 40, white: true),
        const SizedBox(height: 12),
        const Text(
          'Safety starts with the right cylinder.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Need LPG delivered in Lahore? Order directly from Alpha LPG.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Brand.flame,
                  foregroundColor: Brand.navy,
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: () => context.go('/'),
                child: const Text('Order in the app'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              tooltip: 'Order on WhatsApp',
              style: IconButton.styleFrom(
                backgroundColor: Brand.whatsapp,
                minimumSize: const Size(46, 46),
              ),
              onPressed: () => Launch.whatsapp(
                whatsapp,
                'Assalam-o-Alaikum, I would like to order LPG.',
              ),
              icon: const Icon(Icons.chat_rounded, color: Colors.white),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Full-screen, zoomable safety poster.
class SafetyPosterScreen extends StatelessWidget {
  const SafetyPosterScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      systemOverlayStyle: Brand.lightStatusBar,
      title: const Text('Safety poster', style: TextStyle(color: Colors.white)),
    ),
    body: InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image.asset(
          'assets/safety/poster.jpg',
          filterQuality: FilterQuality.high,
        ),
      ),
    ),
  );
}
