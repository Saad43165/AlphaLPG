import 'package:material_ui/material_ui.dart' hide Text;

import '../l10n/text.dart';

import '../theme/brand.dart';
import '../utils/haptics.dart';

/// "Slide to order": a deliberate gesture instead of a tap, so nobody places
/// a gas order by accident. Drag anywhere along the track; release past the
/// end to confirm. [onConfirmed] returns whether it worked: on false the
/// thumb slides back so the customer can fix something and try again.
class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.enabled = true,
    this.color = Brand.blueDark,
  });

  final String label;
  final Future<bool> Function() onConfirmed;
  final bool enabled;
  final Color color;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm>
    with TickerProviderStateMixin {
  static const _height = 64.0;
  static const _thumb = 54.0;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  /// Drives the travelling chevrons (off when animations are disabled).
  late final AnimationController _hint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _busy = false;
  bool _crossedHalf = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate =
        !MediaQuery.disableAnimationsOf(context) && widget.enabled && !_busy;
    if (animate && !_hint.isAnimating) {
      _hint.repeat();
    } else if (!animate && _hint.isAnimating) {
      _hint.stop();
    }
  }

  @override
  void didUpdateWidget(SlideToConfirm old) {
    super.didUpdateWidget(old);
    didChangeDependencies();
  }

  @override
  void dispose() {
    _c.dispose();
    _hint.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy || !widget.enabled) return;
    setState(() => _busy = true);
    _hint.stop();
    await _c.animateTo(1, curve: Curves.easeOut);
    Haptics.heavy();
    var ok = false;
    try {
      ok = await widget.onConfirmed();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (!ok) {
      await _c.animateTo(
        0,
        curve: Curves.easeOutCubic,
        duration: const Duration(milliseconds: 380),
      );
      if (mounted) {
        setState(() => _busy = false);
        didChangeDependencies();
      }
    }
  }

  @override
  // The slider always drags left to right, in both languages.
  Widget build(BuildContext context) =>
      Directionality(textDirection: TextDirection.ltr, child: _slider(context));

  Widget _slider(BuildContext context) {
    final enabled = widget.enabled;
    final pal = context.pal;
    final base = enabled ? widget.color : pal.line;
    final deep = enabled
        ? Color.lerp(widget.color, Brand.navy, 0.45)!
        : pal.line;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: enabled ? _confirm : null,
      child: LayoutBuilder(
        builder: (context, box) {
          final travel = box.maxWidth - _thumb - 10;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: !enabled || _busy
                ? null
                : (d) {
                    _c.value = (_c.value + d.delta.dx / travel).clamp(0.0, 1.0);
                    if (!_crossedHalf && _c.value > 0.5) {
                      _crossedHalf = true;
                      Haptics.select();
                    }
                  },
            onHorizontalDragEnd: !enabled || _busy
                ? null
                : (_) {
                    _crossedHalf = false;
                    if (_c.value > 0.82) {
                      _confirm();
                    } else {
                      _c.animateTo(
                        0,
                        curve: Curves.easeOutBack,
                        duration: const Duration(milliseconds: 300),
                      );
                    }
                  },
            child: AnimatedBuilder(
              animation: Listenable.merge([_c, _hint]),
              builder: (context, _) {
                final p = _c.value;
                final x = 5 + travel * p;
                final done = _busy && p >= 1;
                return Container(
                  height: _height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [deep, base]),
                    borderRadius: BorderRadius.circular(_height / 2),
                    boxShadow: enabled
                        ? [
                            BoxShadow(
                              color: base.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      // Light trail behind the thumb.
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: x + _thumb,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(_height / 2),
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: _thumb + 10,
                            right: 12,
                          ),
                          child: Opacity(
                            opacity: (1 - p * 1.8).clamp(0.0, 1.0),
                            // Shrinks the label a little rather than cutting it.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!enabled) ...[
                                    Icon(
                                      Icons.lock_outline_rounded,
                                      size: 18,
                                      color: pal.muted,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    widget.label,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      letterSpacing: 0.2,
                                      color: enabled ? Colors.white : pal.muted,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Three chevrons light up in turn.
                                  if (enabled)
                                    for (var i = 0; i < 3; i++)
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 20,
                                        color:
                                            (enabled ? Colors.white : pal.muted)
                                                .withValues(
                                                  alpha: enabled
                                                      ? 0.3 +
                                                            0.7 *
                                                                _wave(
                                                                  _hint.value,
                                                                  i,
                                                                )
                                                      : 0.5,
                                                ),
                                      ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: x,
                        top: 5,
                        child: Container(
                          width: _thumb,
                          height: _thumb,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: done
                              ? Padding(
                                  padding: const EdgeInsets.all(15),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: base,
                                  ),
                                )
                              : Icon(
                                  p > 0.9
                                      ? Icons.check_rounded
                                      : Icons.local_fire_department_rounded,
                                  size: 28,
                                  color: enabled
                                      ? Brand.cylinderRed
                                      : pal.muted,
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// 0..1 brightness of chevron [i] as the hint animation runs (a moving glow).
  static double _wave(double t, int i) {
    final d = ((t * 3) - i) % 3;
    final v = d < 0 ? d + 3 : d;
    return v < 1 ? 1 - v : 0;
  }
}
