import 'package:material_ui/material_ui.dart';

import 'brand.dart';
import 'guide.dart' show Bi;

const _urduFont = 'NotoNaskh';

TextStyle _ts(
  bool urdu, {
  double size = 15,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? height,
}) => TextStyle(
  fontSize: urdu ? size + 1.5 : size,
  fontWeight: weight,
  color: color,
  height: height ?? (urdu ? 1.8 : 1.35),
  fontFamily: urdu ? _urduFont : null,
);

/// One page of the welcome tour: a headline, a few words, and a small
/// working demo the person can tap.
class TourSlide {
  const TourSlide({
    required this.icon,
    required this.title,
    required this.body,
    required this.demo,
  });
  final IconData icon;
  final Bi title;
  final Bi body;

  /// A mini "try it" widget. Receives whether the tour is showing Urdu.
  final Widget Function(BuildContext context, bool urdu) demo;
}

/// A full-screen, swipeable welcome tour in English and Urdu. Each page has
/// something to tap, so people learn the app by doing, not only reading.
class TourPage extends StatefulWidget {
  const TourPage({
    super.key,
    required this.appName,
    required this.slides,
    required this.onDone,
    this.startInUrdu = false,
  });

  final Bi appName;
  final List<TourSlide> slides;
  final VoidCallback onDone;
  final bool startInUrdu;

  @override
  State<TourPage> createState() => _TourPageState();
}

class _TourPageState extends State<TourPage> {
  final _pages = PageController();
  late bool _urdu = widget.startInUrdu;
  int _i = 0;

  bool get _last => _i == widget.slides.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_last) {
      widget.onDone();
    } else {
      _pages.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(Bi b) => _urdu ? b.ur : b.en;
    return Directionality(
      textDirection: _urdu ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: Brand.headerGradient),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                      child: Row(
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: _LangPill(
                                  urdu: _urdu,
                                  onChanged: (v) => setState(() => _urdu = v),
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (!_last)
                            TextButton(
                              onPressed: widget.onDone,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                _urdu ? 'چھوڑیں' : 'Skip',
                                style: _ts(
                                  _urdu,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: widget.slides.length,
                        onPageChanged: (v) => setState(() => _i = v),
                        itemBuilder: (context, n) {
                          final s = widget.slides[n];
                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                            child: Column(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    s.icon,
                                    color: Brand.flame,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  t(s.title),
                                  textAlign: TextAlign.center,
                                  style: _ts(
                                    _urdu,
                                    size: 24,
                                    weight: FontWeight.w800,
                                    color: Colors.white,
                                    height: _urdu ? 1.7 : 1.15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  t(s.body),
                                  textAlign: TextAlign.center,
                                  style: _ts(
                                    _urdu,
                                    color: Colors.white.withValues(alpha: 0.92),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: context.pal.card,
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x33000000),
                                        blurRadius: 24,
                                        offset: Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: s.demo(context, _urdu),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                      child: Row(
                        children: [
                          for (var n = 0; n < widget.slides.length; n++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsetsDirectional.only(end: 6),
                              width: n == _i ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: n == _i
                                    ? Brand.flame
                                    : Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          const Spacer(),
                          Flexible(
                            child: FilledButton(
                              onPressed: _next,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Brand.navy,
                                minimumSize: const Size(110, 50),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _last
                                      ? (_urdu ? 'شروع کریں' : 'Get started')
                                      : (_urdu ? 'آگے' : 'Next'),
                                  style: _ts(
                                    _urdu,
                                    size: 16,
                                    weight: FontWeight.w800,
                                    color: Brand.navy,
                                  ),
                                ),
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
          ),
        ),
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  const _LangPill({required this.urdu, required this.onChanged});
  final bool urdu;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (v, label) in [(false, 'English'), (true, 'اردو')])
          GestureDetector(
            onTap: () => onChanged(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: urdu == v ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: v ? _urduFont : null,
                  fontSize: v ? 16 : 13.5,
                  fontWeight: FontWeight.w700,
                  color: urdu == v ? Brand.navy : Colors.white,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Demos

/// A big power button to tap: off → on, with a message.
class TourToggleDemo extends StatefulWidget {
  const TourToggleDemo({
    super.key,
    required this.urdu,
    required this.offTitle,
    required this.onTitle,
    required this.offHint,
    required this.onHint,
  });
  final bool urdu;
  final Bi offTitle, onTitle, offHint, onHint;

  @override
  State<TourToggleDemo> createState() => _TourToggleDemoState();
}

class _TourToggleDemoState extends State<TourToggleDemo>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _on = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || _on) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.urdu;
    final pal = context.pal;
    final color = _on ? Brand.success : pal.muted;
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() => _on = !_on);
            if (_on) {
              _pulse.stop();
            } else if (!MediaQuery.disableAnimationsOf(context)) {
              _pulse.repeat(reverse: true);
            }
          },
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Container(
              width: 128 + (_on ? 0 : _pulse.value * 12),
              height: 128 + (_on ? 0 : _pulse.value * 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
              child: child,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: _on
                    ? [
                        BoxShadow(
                          color: Brand.success.withValues(alpha: 0.45),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: const Icon(
                Icons.power_settings_new_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Column(
            key: ValueKey(_on),
            children: [
              Text(
                _on
                    ? (u ? widget.onTitle.ur : widget.onTitle.en)
                    : (u ? widget.offTitle.ur : widget.offTitle.en),
                textAlign: TextAlign.center,
                style: _ts(
                  u,
                  size: 19,
                  weight: FontWeight.w800,
                  color: _on ? Brand.success : pal.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _on
                    ? (u ? widget.onHint.ur : widget.onHint.en)
                    : (u ? widget.offHint.ur : widget.offHint.en),
                textAlign: TextAlign.center,
                style: _ts(u, size: 14, color: pal.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TourStep {
  const TourStep(this.icon, this.label, this.action);
  final IconData icon;

  /// What is happening on screen at this step.
  final Bi label;

  /// The button the person taps to move on.
  final Bi action;
}

/// A mini phone card that moves through real steps when its button is tapped.
class TourStepsDemo extends StatefulWidget {
  const TourStepsDemo({super.key, required this.urdu, required this.steps});
  final bool urdu;
  final List<TourStep> steps;

  @override
  State<TourStepsDemo> createState() => _TourStepsDemoState();
}

class _TourStepsDemoState extends State<TourStepsDemo> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final u = widget.urdu;
    final pal = context.pal;
    final done = _i >= widget.steps.length;
    final step = done ? null : widget.steps[_i];
    String t(Bi b) => u ? b.ur : b.en;
    return Column(
      children: [
        Row(
          children: [
            for (var n = 0; n < widget.steps.length; n++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: n < _i || done
                        ? Brand.success
                        : (n == _i ? Brand.blueDark : pal.line),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.0).animate(a),
              child: c,
            ),
          ),
          child: Column(
            key: ValueKey(_i),
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (done ? Brand.success : Brand.blueDark).withValues(
                    alpha: 0.12,
                  ),
                ),
                child: Icon(
                  done ? Icons.check_circle_rounded : step!.icon,
                  size: 40,
                  color: done ? Brand.success : Brand.blueDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                done
                    ? (u
                          ? 'ہو گیا! بس اتنا ہی کرنا ہے۔'
                          : 'Done! That is all it takes.')
                    : t(step!.label),
                textAlign: TextAlign.center,
                style: _ts(
                  u,
                  size: 17,
                  weight: FontWeight.w800,
                  color: pal.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: done ? pal.tint : Brand.blueDark,
              foregroundColor: done ? Brand.blueDark : Colors.white,
              minimumSize: const Size(0, 50),
            ),
            onPressed: () => setState(() => _i = done ? 0 : _i + 1),
            child: Text(
              done ? (u ? 'دوبارہ آزمائیں' : 'Try again') : t(step!.action),
              style: _ts(
                u,
                size: 16,
                weight: FontWeight.w800,
                color: done ? Brand.blueDark : Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          u ? 'بٹن دبا کر آزمائیں' : 'Tap the button to try it',
          style: _ts(u, size: 12.5, color: pal.muted),
        ),
      ],
    );
  }
}

class TourTile {
  const TourTile(this.icon, this.label, this.text);
  final IconData icon;
  final Bi label;

  /// Shown when the tile is tapped.
  final Bi text;
}

/// A set of tappable tiles; tapping one explains it underneath.
class TourTilesDemo extends StatefulWidget {
  const TourTilesDemo({super.key, required this.urdu, required this.tiles});
  final bool urdu;
  final List<TourTile> tiles;

  @override
  State<TourTilesDemo> createState() => _TourTilesDemoState();
}

class _TourTilesDemoState extends State<TourTilesDemo> {
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    final u = widget.urdu;
    final pal = context.pal;
    String t(Bi b) => u ? b.ur : b.en;
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (n, tile) in widget.tiles.indexed)
              GestureDetector(
                onTap: () => setState(() => _sel = n),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 92,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: n == _sel ? Brand.blueDark : pal.tint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        tile.icon,
                        size: 26,
                        color: n == _sel ? Colors.white : Brand.blueDark,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t(tile.label),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _ts(
                          u,
                          size: 12,
                          weight: FontWeight.w700,
                          color: n == _sel ? Colors.white : pal.ink,
                          height: u ? 1.5 : 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Container(
            key: ValueKey(_sel),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pal.tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              t(widget.tiles[_sel].text),
              style: _ts(u, size: 14.5, color: pal.ink),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          u ? 'ہر آئیکن دبا کر دیکھیں' : 'Tap each one to see what it does',
          style: _ts(u, size: 12.5, color: pal.muted),
        ),
      ],
    );
  }
}
