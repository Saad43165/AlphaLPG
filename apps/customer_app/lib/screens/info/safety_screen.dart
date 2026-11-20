import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/brand.dart';
import '../../utils/launch.dart';
import '../../widgets/common.dart';

/// Content follows Alpha LPG's "Use LPG safely. Every single day." poster.
class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

typedef _Tip = (String image, String title, String body);
typedef _Step = (IconData icon, String title, String body);

class _SafetyScreenState extends State<SafetyScreen> {
  bool _showDos = true;

  static const _essentials = <_Tip>[
    (
      'essential_upright',
      'Keep it upright',
      'Always keep the cylinder upright on a stable, level surface.',
    ),
    (
      'essential_ventilated',
      'Keep it ventilated',
      'Never keep LPG in a closed or poorly ventilated space.',
    ),
    (
      'essential_connections',
      'Check connections',
      'Regularly check the regulator, hose and connections for any signs of damage.',
    ),
    (
      'essential_turn_off',
      'Turn it off',
      'Close the cylinder and regulator when LPG is not being used.',
    ),
  ];

  static const _dos = <_Tip>[
    ('do_upright', 'Keep cylinders upright', 'On a stable, level surface.'),
    (
      'do_condition',
      'Keep everything in good condition',
      'Cylinder, regulator and hose. Replace anything damaged.',
    ),
    (
      'do_heat',
      'Keep away from heat',
      'Away from excessive heat and ignition sources.',
    ),
  ];

  static const _donts = <_Tip>[
    (
      'dont_enclosed',
      "Don't store in enclosed spaces",
      'Not in cabinets, cupboards or basements.',
    ),
    (
      'dont_flame',
      "Don't use a flame to check for leaks",
      'Use soapy water instead. Bubbles mean a leak.',
    ),
    (
      'dont_spares',
      "Don't keep spares next to it",
      'Do not keep spare cylinders directly next to the cylinder in use.',
    ),
  ];

  static const _emergency = <_Step>[
    (
      Icons.power_settings_new_rounded,
      'Turn off the gas supply',
      'If it is safe to do so, close the cylinder valve and regulator.',
    ),
    (
      Icons.local_fire_department_rounded,
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

  static const _rightWrong = <(String, bool, String)>[
    ('right_ventilated', true, 'Upright, ventilated and on a stable surface'),
    ('wrong_cabinet', false, 'Kept inside an enclosed cabinet'),
    ('right_regulator', true, 'Proper regulator and secure connection'),
    ('wrong_hose', false, 'Damaged or cracked hose'),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().settings;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 250,
            backgroundColor: Brand.surface,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/safety/kitchen_hero.jpg',
                    fit: BoxFit.cover,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00F4F7FA),
                          Color(0xCCF4F7FA),
                          Brand.surface,
                        ],
                        stops: [0.25, 0.7, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Use LPG safely.',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                            letterSpacing: -0.8,
                            color: Brand.navy,
                          ),
                        ),
                        Text(
                          'Every single day.',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            letterSpacing: -0.8,
                            color: Brand.muted.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Constrained(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Simple precautions make LPG safer to store, handle and use at home.',
                      style: text.bodyLarge?.copyWith(color: Brand.muted),
                    ),
                    const SizedBox(height: 18),
                    _EmergencyCard(steps: _emergency, phone: s.phone),
                    const _Kicker(
                      'THE ESSENTIALS',
                      '4 things to always remember',
                    ),
                    GridView.count(
                      crossAxisCount: MediaQuery.sizeOf(context).width > 640
                          ? 4
                          : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.74,
                      children: [
                        for (final (i, t) in _essentials.indexed)
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
                      onSelectionChanged: (v) =>
                          setState(() => _showDos = v.first),
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
                              child: _HabitCard(tip: t, good: _showDos),
                            ),
                        ],
                      ),
                    ),
                    const _Kicker(
                      'RIGHT VS WRONG',
                      'A safer home starts with better habits',
                    ),
                    SizedBox(
                      height: 214,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: _rightWrong.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (_, i) =>
                            _RightWrongCard(item: _rightWrong[i]),
                      ),
                    ),
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/safety/poster'),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('View the full safety poster'),
                    ),
                    const SizedBox(height: 22),
                    _OrderSafelyCard(whatsapp: s.whatsapp),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: Brand.muted,
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
  final List<_Step> steps;
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
        const Text(
          'Stay calm and follow these steps:',
          style: TextStyle(color: Brand.muted),
        ),
        const SizedBox(height: 12),
        for (final (i, (icon, title, body)) in steps.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                        style: const TextStyle(
                          color: Brand.muted,
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
  final _Tip tip;

  @override
  Widget build(BuildContext context) {
    final (image, title, body) = tip;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Brand.radius),
        boxShadow: Brand.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/safety/$image.jpg', fit: BoxFit.cover),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Brand.blueDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      number.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      body,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(
                        color: Brand.muted,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.tip, required this.good});
  final _Tip tip;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final (image, title, body) = tip;
    final color = good ? Brand.blueDark : Brand.cylinderRed;
    return Container(
      height: 112,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Brand.radius),
        boxShadow: Brand.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    good ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: color,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
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
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Expanded(
                          child: Text(
                            body,
                            overflow: TextOverflow.fade,
                            style: const TextStyle(
                              color: Brand.muted,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 112,
            height: double.infinity,
            child: Image.asset('assets/safety/$image.jpg', fit: BoxFit.cover),
          ),
        ],
      ),
    );
  }
}

class _RightWrongCard extends StatelessWidget {
  const _RightWrongCard({required this.item});
  final (String, bool, String) item;

  @override
  Widget build(BuildContext context) {
    final (image, right, caption) = item;
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 120,
              width: 170,
              child: Image.asset('assets/safety/$image.jpg', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: right ? 'Right: ' : 'Wrong: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: right ? Brand.success : Brand.cylinderRed,
                  ),
                ),
                TextSpan(text: caption),
              ],
            ),
            style: const TextStyle(fontSize: 13, height: 1.3),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
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
      child: Center(child: Image.asset('assets/safety/poster.jpg')),
    ),
  );
}
