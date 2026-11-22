import 'package:material_ui/material_ui.dart';

import '../theme/brand.dart';
import '../utils/haptics.dart';

/// A side menu where the whole screen slides to the right and shrinks, as if
/// it stepped back, while the menu sits behind it. Tap the screen, swipe it
/// back, or press Back to close.
class PushDrawerHost extends StatefulWidget {
  const PushDrawerHost({super.key, required this.drawer, required this.child});

  /// The menu panel (drawn behind the screen).
  final Widget drawer;

  /// The app screen that slides away.
  final Widget child;

  @override
  State<PushDrawerHost> createState() => PushDrawerState();
}

/// `PushDrawerState.of(context).open()` from anywhere under the host.
class PushDrawerState extends State<PushDrawerHost>
    with SingleTickerProviderStateMixin {
  static PushDrawerState of(BuildContext context) =>
      context.findAncestorStateOfType<PushDrawerState>()!;

  static PushDrawerState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<PushDrawerState>();

  // The value is the finger's progress (0 closed, 1 open); the easing is in
  // the animation itself, so dragging and releasing feel the same.
  late final AnimationController _c = AnimationController(vsync: this);

  bool _edge = false;

  bool get isOpen => _c.value > 0.5 || _c.status == AnimationStatus.forward;

  void open() {
    if (_c.value < 0.05) Haptics.light();
    _c.animateTo(
      1,
      duration: Duration(milliseconds: (320 * (1 - _c.value)).round() + 80),
      curve: Curves.easeOutCubic,
    );
  }

  void close() => _c.animateTo(
    0,
    duration: Duration(milliseconds: (260 * _c.value).round() + 60),
    curve: Curves.easeOutCubic,
  );

  /// Finish a drag: carry on in the direction the finger was going.
  void _settle(double velocity, double w) {
    final v = velocity / w; // screens per second, toward open is positive
    if (v.abs() > 0.8) {
      v > 0 ? open() : close();
    } else {
      _c.value >= 0.5 ? open() : close();
    }
  }

  void toggle() => isOpen ? close() : open();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _width(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * 0.76).clamp(260.0, 330.0);

  @override
  Widget build(BuildContext context) {
    final w = _width(context);
    final pal = context.pal;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, content) {
        final t = _c.value;
        // In Urdu the menu button is on the right, so the menu opens from there.
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final dir = rtl ? -1.0 : 1.0;
        return PopScope(
          // The Back button closes the menu first.
          canPop: _c.value == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) close();
          },
          child: Container(
            // Behind everything: the menu's own backdrop.
            // Follows the theme: light menu in light mode, dark in dark mode.
            color: pal.isDark
                ? const Color(0xFF060F18)
                : const Color(0xFFF2F6FB),
            child: Stack(
              children: [
                // The menu, easing in from slightly left and small.
                Positioned.fill(
                  child: Visibility(
                    visible: _c.value > 0,
                    maintainState: true,
                    child: Opacity(
                      opacity: (0.3 + 0.7 * t).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(-24 * (1 - t) * dir, 0),
                        child: Align(
                          alignment: rtl
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: SizedBox(
                            width: w,
                            // Follows the app theme (light menu in light mode).
                            child: widget.drawer,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // The screen, pushed right and shrunk.
                Transform(
                  alignment: rtl ? Alignment.centerRight : Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..translateByDouble(dir * w * t, 0, 0, 1)
                    ..scaleByDouble(1 - 0.12 * t, 1 - 0.12 * t, 1, 1),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (d) {
                      if (_c.value > 0) {
                        _c.value = (_c.value + dir * d.delta.dx / w).clamp(
                          0.0,
                          1.0,
                        );
                      }
                    },
                    onHorizontalDragEnd: (d) {
                      if (_c.value == 0) return;
                      _settle(dir * (d.primaryVelocity ?? 0), w);
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30 * t),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35 * t),
                            blurRadius: 28,
                            offset: const Offset(-6, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30 * t),
                        child: Stack(
                          children: [
                            content!,
                            // While open, taps on the screen only close the menu.
                            if (_c.value > 0)
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: close,
                                  child: Semantics(
                                    label: 'Close menu',
                                    button: true,
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Swipe in from the edge to open the menu.
                if (_c.value == 0 || _edge)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: rtl ? null : 0,
                    right: rtl ? 0 : null,
                    width: 22,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragStart: (_) => _edge = true,
                      onHorizontalDragUpdate: (d) {
                        _c.value = (_c.value + dir * d.delta.dx / w).clamp(
                          0.0,
                          1.0,
                        );
                      },
                      onHorizontalDragEnd: (d) {
                        _edge = false;
                        _settle(dir * (d.primaryVelocity ?? 0), w);
                      },
                      onHorizontalDragCancel: () => _edge = false,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
