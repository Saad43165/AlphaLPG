import 'package:material_ui/material_ui.dart';

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
    with SingleTickerProviderStateMixin {
  static const _height = 58.0;
  static const _thumb = 50.0;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  bool _busy = false;
  bool _crossedHalf = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy || !widget.enabled) return;
    setState(() => _busy = true);
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
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final color = enabled ? widget.color : context.pal.line;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: enabled ? _confirm : null,
      child: LayoutBuilder(
        builder: (context, box) {
          final travel = box.maxWidth - _thumb - 8;
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
              animation: _c,
              builder: (context, _) {
                final p = _c.value;
                final x = 4 + travel * p;
                return Container(
                  height: _height,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: enabled ? 0.14 : 0.5),
                    borderRadius: BorderRadius.circular(_height / 2),
                    border: Border.all(
                      color: color.withValues(alpha: enabled ? 0.45 : 0.8),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Filled trail behind the thumb.
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: x + _thumb,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(_height / 2),
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: _thumb,
                            right: 12,
                          ),
                          child: Opacity(
                            opacity: (1 - p * 1.6).clamp(0.0, 1.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: enabled
                                          ? context.pal.ink
                                          : context.pal.muted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_double_arrow_right_rounded,
                                  size: 20,
                                  color: color,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: x,
                        top: 4,
                        child: Container(
                          width: _thumb,
                          height: _thumb,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: _busy && p >= 1
                              ? Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: color,
                                  ),
                                )
                              : Icon(
                                  p > 0.9
                                      ? Icons.check_rounded
                                      : Icons.local_fire_department_rounded,
                                  color: color,
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
}
