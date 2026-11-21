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

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    reverseDuration: const Duration(milliseconds: 280),
  );

  bool get isOpen => _c.value > 0.5 || _c.status == AnimationStatus.forward;

  void open() {
    Haptics.light();
    _c.fling(velocity: 2.2);
  }

  void close() => _c.fling(velocity: -2.2);

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
        final t = Curves.easeOutCubic.transform(_c.value);
        return PopScope(
          // The Back button closes the menu first.
          canPop: _c.value == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) close();
          },
          child: Container(
            // Behind everything: the menu's own backdrop.
            color: pal.isDark ? const Color(0xFF060F18) : Brand.navy,
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
                        offset: Offset(-24 * (1 - t), 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: w,
                            // The menu is always dark, whatever the app theme.
                            child: Theme(
                              data: Brand.theme(Brightness.dark),
                              child: widget.drawer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // The screen, pushed right and shrunk.
                Transform(
                  alignment: Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..translateByDouble(w * t, 0, 0, 1)
                    ..scaleByDouble(1 - 0.12 * t, 1 - 0.12 * t, 1, 1),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (d) {
                      if (_c.value > 0) {
                        _c.value = (_c.value + d.delta.dx / w).clamp(0.0, 1.0);
                      }
                    },
                    onHorizontalDragEnd: (d) {
                      if (_c.value == 0) return;
                      final v = d.primaryVelocity ?? 0;
                      if (v < -300 || (v.abs() <= 300 && _c.value < 0.5)) {
                        close();
                      } else {
                        open();
                      }
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
              ],
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
