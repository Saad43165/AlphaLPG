import 'package:material_ui/material_ui.dart' hide Text;

import '../l10n/lang.dart';
import '../l10n/text.dart';

import 'package:material_ui/material_ui.dart' as mu show Text;

import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/brand.dart';
import '../widgets/common.dart';
import '../utils/haptics.dart';

/// Three-slide welcome shown on first launch.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

typedef _Slide = (String image, IconData icon, String title, String body);

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  static const _slides = <_Slide>[
    (
      'assets/brand/photo_depot.jpg',
      Icons.local_fire_department_rounded,
      'LPG for every kitchen in Lahore',
      'From 6kg home cylinders to 45.4kg commercial supply, straight from the Alpha LPG depot.',
    ),
    (
      'assets/brand/photo_truck.jpg',
      Icons.local_shipping_rounded,
      'Delivered to your door',
      'Order in a few taps and track your rider live. Same-day delivery across Lahore.',
    ),
    (
      'assets/brand/photo_check.jpg',
      Icons.verified_user_rounded,
      'Checked before it leaves',
      'Every cylinder is safety-checked by our team. Pay cash on delivery or by JazzCash, Easypaisa or bank.',
    ),
    (
      'assets/brand/photo_depot.jpg',
      Icons.soup_kitchen_rounded,
      'Stoves and regulators too',
      'Add a stove or regulator to your gas order. One delivery, one bill.',
    ),
  ];

  bool get _last => _index == _slides.length - 1;

  void _finish() {
    Haptics.light();
    context.read<AppState>().completeOnboarding();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final s in _slides) {
      precacheImage(AssetImage(s.$1), context);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: Brand.darkStatusBar,
      child: Scaffold(
        backgroundColor: context.pal.card,
        body: SafeArea(
          child: Constrained(
            maxWidth: 520,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                  child: Row(
                    children: [
                      const BrandLogo(height: 38),
                      const Spacer(),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: () =>
                            context.read<AppState>().setUrdu(!Lang.isUrdu),
                        child: mu.Text(
                          Lang.isUrdu ? 'English' : 'اردو',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedOpacity(
                        opacity: _last ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: TextButton(
                          onPressed: _last ? null : _finish,
                          child: const Text('Skip'),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => _SlideView(_slides[i]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Row(
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _index ? 26 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? Brand.blueDark
                                : context.pal.line,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(150, 54),
                        ),
                        onPressed: _last
                            ? _finish
                            : () => _pages.nextPage(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                              ),
                        iconAlignment: IconAlignment.end,
                        icon: Icon(
                          _last
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                        label: Text(_last ? 'Get started' : 'Next'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView(this.slide);
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final (image, icon, title, body) = slide;
    return LayoutBuilder(
      builder: (context, c) {
        // Keep the photo close to its native size so it stays sharp.
        final imageHeight = (c.maxHeight * 0.56).clamp(220.0, 420.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: imageHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Brand.navy.withValues(alpha: 0.18),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  image,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.pal.tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Brand.blueDark),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  color: context.pal.muted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
