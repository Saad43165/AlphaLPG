import 'package:material_ui/material_ui.dart';

import '../theme/brand.dart';
import '../widgets/gas_cylinder.dart';

/// Shown on launch above the app.
///
/// Starts as the same full-bleed sky image as the native splash (so there is
/// no jump), then a rounded panel rises from the bottom with a gas cylinder
/// that fills up while the app gets ready.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  late final AnimationController _out = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  bool _started = false;

  static const _messages = [
    'Checking cylinders…',
    'Finding riders near you…',
    'Almost there…',
    'Ready!',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _run.duration = const Duration(milliseconds: 500);
    }
    _run.forward().whenComplete(() async {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      await _out.forward();
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _run.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final size = MediaQuery.sizeOf(context);
    final panelH = (size.height * 0.46).clamp(340.0, 460.0);
    return FadeTransition(
      opacity: ReverseAnimation(_out),
      child: Material(
        // Sky blue, so even a one-frame image decode never flashes white.
        color: const Color(0xFF3AA6EE),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/brand/splash_bg.jpg',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            AnimatedBuilder(
              animation: _run,
              builder: (context, _) {
                final t = _run.value;
                final slide = Curves.easeOutCubic.transform(
                  ((t - 0.06) / 0.24).clamp(0.0, 1.0),
                );
                final level = Curves.easeInOut.transform(
                  ((t - 0.22) / 0.66).clamp(0.0, 1.0),
                );
                final msg =
                    _messages[(t * (_messages.length - 0.01)).floor().clamp(
                      0,
                      _messages.length - 1,
                    )];
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: -panelH * (1 - slide),
                  height: panelH,
                  child: Container(
                    decoration: BoxDecoration(
                      color: pal.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(38),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 34,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: pal.line,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const Spacer(flex: 2),
                          GasCylinder(level: level, width: 76, height: 118),
                          const SizedBox(height: 16),
                          Text(
                            'Safe gas. Delivered.',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                              color: pal.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 22,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: Text(
                                msg,
                                key: ValueKey(msg),
                                style: TextStyle(
                                  color: pal.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _Chevrons(progress: t),
                          const Spacer(flex: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _Pill(
                                Icons.verified_user_rounded,
                                'Safety-checked',
                                pal,
                              ),
                              const SizedBox(width: 8),
                              _Pill(Icons.bolt_rounded, 'Same-day', pal),
                              const SizedBox(width: 8),
                              _Pill(Icons.payments_rounded, 'Easy pay', pal),
                            ],
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Four chevrons lighting up in sequence, echoing the logo's ">>>>".
class _Chevrons extends StatelessWidget {
  const _Chevrons({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final head = (progress * 9) % 5; // sweeps 0..5 repeatedly
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 30,
              color: Color.lerp(
                pal.line,
                Brand.blue,
                (1 - ((head - i - 0.5).abs() / 1.6)).clamp(0.0, 1.0),
              ),
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.label, this.pal);
  final IconData icon;
  final String label;
  final AppPalette pal;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: pal.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: pal.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Brand.blue),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: pal.ink,
          ),
        ),
      ],
    ),
  );
}
