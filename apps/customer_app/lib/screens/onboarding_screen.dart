import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/brand.dart';
import '../widgets/common.dart';

/// Three-slide welcome shown on first launch.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  static const _slides = [
    (
      'assets/brand/hero_truck.jpg',
      'LPG at your door',
      'Order 6kg to 45.4kg cylinders in a few taps. Delivered across Lahore, usually the same day.',
    ),
    (
      'assets/brand/hero_stock.jpg',
      'Safe cylinders, every time',
      'Safety-checked Alpha LPG cylinders, plus simple tips to keep your home and family safe.',
    ),
    (
      'assets/brand/hero_warehouse.jpg',
      'Track every delivery',
      'Follow your order live, from confirmation to your doorstep. Pay cash on delivery.',
    ),
  ];

  bool get _last => _index == _slides.length - 1;

  void _finish() => context.read<AppState>().completeOnboarding();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: Brand.lightStatusBar,
      child: Scaffold(
        backgroundColor: Brand.navy,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => Image.asset(
                _slides[i].$1,
                fit: BoxFit.cover,
                height: double.infinity,
                width: double.infinity,
              ),
            ),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x880F2A3F),
                      Color(0x000F2A3F),
                      Color(0xF20F2A3F),
                      Brand.navy,
                    ],
                    stops: [0, 0.3, 0.62, 1],
                  ),
                ),
                child: SizedBox.expand(),
              ),
            ),
            SafeArea(
              child: Constrained(
                maxWidth: 520,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const BrandLogo(height: 40, white: true),
                          const Spacer(),
                          if (!_last)
                            TextButton(
                              onPressed: _finish,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Skip'),
                            ),
                        ],
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Column(
                          key: ValueKey(_index),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _slides[_index].$2,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _slides[_index].$3,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 16,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          for (var i = 0; i < _slides.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.only(right: 6),
                              width: i == _index ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _index
                                    ? Brand.flame
                                    : Colors.white.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          const Spacer(),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Brand.flame,
                              foregroundColor: Brand.navy,
                              minimumSize: const Size(150, 54),
                            ),
                            onPressed: _last
                                ? _finish
                                : () => _pages.nextPage(
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOutCubic,
                                  ),
                            child: Text(_last ? 'Get started' : 'Next'),
                          ),
                        ],
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
