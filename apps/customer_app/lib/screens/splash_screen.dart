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
    // The scene is always the bright sky, so its text is always dark blue,
    // whatever theme the phone uses.
    const ink = Brand.navy;
    const muted = Color(0xFF5C7088);
    final size = MediaQuery.sizeOf(context);
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
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.high,
            ),
            // The picture fades to white at the bottom; make sure it always
            // reaches pure white, on any screen shape, so the cylinder sits
            // on the sky itself instead of on a separate panel.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: size.height * 0.62,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
                    stops: [0.0, 0.62],
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _run,
              builder: (context, _) {
                final t = _run.value;
                final appear = Curves.easeOutCubic.transform(
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
                return Positioned.fill(
                  child: SafeArea(
                    child: Opacity(
                      opacity: appear,
                      child: Transform.translate(
                        offset: Offset(0, 34 * (1 - appear)),
                        child: Column(
                          children: [
                            // Below the logo that is part of the picture.
                            SizedBox(height: size.height * 0.40),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // A soft blue glow behind the cylinder.
                                Container(
                                  width: 170,
                                  height: 170,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        Brand.blue.withValues(alpha: 0.22),
                                        Brand.blue.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                                // Drawn with the light theme: the scene is bright.
                                Theme(
                                  data: Brand.theme(Brightness.light),
                                  child: GasCylinder(
                                    level: level,
                                    width: 76,
                                    height: 118,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Safe gas. Delivered.',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.7,
                                color: ink,
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
                                  style: const TextStyle(
                                    color: muted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _Chevrons(progress: t),
                            const Spacer(),
                            const Text(
                              'Developed by',
                              style: TextStyle(
                                color: muted,
                                fontSize: 12,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Saad Ikram',
                              style: TextStyle(
                                color: ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                        ),
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
                const Color(0xFFD3E2EE),
                Brand.blue,
                (1 - ((head - i - 0.5).abs() / 1.6)).clamp(0.0, 1.0),
              ),
            ),
          ),
      ],
    );
  }
}
