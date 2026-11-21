import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/brand.dart';

/// Colour of the gas for a given level: blue, then amber, then red.
Color gasColor(double level) {
  if (level > 0.4) return Brand.blue;
  if (level > 0.18) return Brand.flame;
  return Brand.cylinderRed;
}

/// An Alpha LPG style cylinder whose gas rises and ripples.
class GasCylinder extends StatefulWidget {
  const GasCylinder({
    super.key,
    required this.level,
    this.width = 84,
    this.height = 132,
    this.color,
    this.outline,
    this.glass,
    this.showFlame = true,
  });

  /// 0 (empty) to 1 (full).
  final double level;
  final double width;
  final double height;
  final Color? color;
  final Color? outline;
  final Color? glass;
  final bool showFlame;

  @override
  State<GasCylinder> createState() => _GasCylinderState();
}

class _GasCylinderState extends State<GasCylinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect "remove animations" and keep widget tests settle-able.
    if (MediaQuery.disableAnimationsOf(context)) {
      _wave.stop();
    } else if (!_wave.isAnimating) {
      _wave.repeat();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.level.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, level, _) => AnimatedBuilder(
          animation: _wave,
          builder: (context, _) => CustomPaint(
            painter: _CylinderPainter(
              level: level,
              phase: _wave.value * 2 * math.pi,
              liquid: widget.color ?? gasColor(level),
              outline:
                  widget.outline ??
                  (pal.isDark ? const Color(0xFF6FA8D4) : Brand.navy),
              glass:
                  widget.glass ??
                  (pal.isDark
                      ? const Color(0xFF1B3550)
                      : const Color(0xFFEAF5FC)),
            ),
            child: widget.showFlame
                ? Align(
                    alignment: const Alignment(0, 0.18),
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      size: widget.width * 0.34,
                      color: level > 0.5
                          ? Colors.white.withValues(alpha: 0.95)
                          : (pal.isDark
                                ? const Color(0xFFB7CBDD)
                                : Brand.navy.withValues(alpha: 0.7)),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _CylinderPainter extends CustomPainter {
  _CylinderPainter({
    required this.level,
    required this.phase,
    required this.liquid,
    required this.outline,
    required this.glass,
  });

  final double level;
  final double phase;
  final Color liquid;
  final Color outline;
  final Color glass;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final stroke = (w * 0.04).clamp(2.0, 4.0);

    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.10, h * 0.22, w * 0.80, h * 0.70),
      topLeft: Radius.circular(w * 0.36),
      topRight: Radius.circular(w * 0.36),
      bottomLeft: Radius.circular(w * 0.16),
      bottomRight: Radius.circular(w * 0.16),
    );

    final line = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round;

    // Carry handle behind the body.
    final handle = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.27, h * 0.045, w * 0.46, h * 0.22),
      Radius.circular(w * 0.1),
    );
    canvas.drawRRect(handle, line);
    // Valve.
    final valve = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.42, h * 0.17, w * 0.16, h * 0.07),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(valve, Paint()..color = outline);

    // Foot ring.
    final foot = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.915, w * 0.64, h * 0.075),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(foot, Paint()..color = outline);

    // Glass.
    canvas.drawRRect(body, Paint()..color = glass);

    // Gas.
    canvas.save();
    canvas.clipRRect(body);
    final top = body.bottom - body.height * level;
    for (var layer = 0; layer < 2; layer++) {
      final amp = (level <= 0.01 || level >= 0.99)
          ? 0.0
          : h * (layer == 0 ? 0.018 : 0.012);
      final path = Path()..moveTo(body.left, body.bottom);
      path.lineTo(body.left, top);
      for (double x = 0; x <= body.width; x += 2) {
        final y =
            top +
            math.sin(
                  phase * (layer == 0 ? 1 : -1) +
                      x / body.width * 2 * math.pi * 1.4 +
                      layer * 1.7,
                ) *
                amp;
        path.lineTo(body.left + x, y);
      }
      path.lineTo(body.right, body.bottom);
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = liquid.withValues(alpha: layer == 0 ? 0.95 : 0.45),
      );
    }
    // Bubbles.
    final bubble = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (var i = 0; i < 3; i++) {
      final t = (phase / (2 * math.pi) + i / 3) % 1;
      final by = body.bottom - body.height * level * t;
      if (level > 0.08) {
        canvas.drawCircle(
          Offset(body.left + body.width * (0.28 + i * 0.22), by),
          w * (0.018 + 0.006 * i),
          bubble,
        );
      }
    }
    canvas.restore();

    // Highlight on the left edge.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.2, h * 0.4)
        ..quadraticBezierTo(w * 0.17, h * 0.6, w * 0.2, h * 0.82),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawRRect(body, line);
  }

  @override
  bool shouldRepaint(_CylinderPainter o) =>
      o.level != level ||
      o.phase != phase ||
      o.liquid != liquid ||
      o.outline != outline;
}
