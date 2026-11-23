import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 36, this.white = false});
  final double height;
  final bool white;

  @override
  Widget build(BuildContext context) => Image.asset(
    white ? 'assets/brand/logo_white.png' : 'assets/brand/logo.png',
    height: height,
    semanticLabel: 'Alpha LPG',
  );
}

/// Centred column that stays readable on tablets.
class Constrained extends StatelessWidget {
  const Constrained({super.key, required this.child, this.maxWidth = 640});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

void showMessage(BuildContext context, String message, {bool error = false}) =>
    showAppMessage(context, message, error: error);

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message = '',
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: context.pal.tint,
            child: Icon(icon, size: 40, color: Brand.blueDark),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.pal.muted, height: 1.4),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

BoxDecoration panel(BuildContext context, {Color? color}) => BoxDecoration(
  color: color ?? context.pal.card,
  borderRadius: BorderRadius.circular(Brand.radius),
  boxShadow: context.pal.shadow,
  border: context.pal.isDark ? Border.all(color: context.pal.line) : null,
);

class Heading extends StatelessWidget {
  const Heading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
    ),
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final OrderStatus status;

  static (String, Color) look(OrderStatus s) => switch (s) {
    OrderStatus.placed => ('New', Brand.warning),
    OrderStatus.confirmed => ('Confirmed', Brand.blueDark),
    OrderStatus.assigned => ('Ready to go', Brand.blueDark),
    OrderStatus.outForDelivery => ('On the way', const Color(0xFF6A3FC1)),
    OrderStatus.delivered => ('Delivered', Brand.success),
    OrderStatus.cancelled => ('Cancelled', Brand.danger),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = look(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.pal.card,
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.icon, this.label, {super.key, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  Color _fg(BuildContext context) => Tone.on(Tone.fill(color));

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Tone.fill(color),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: _fg(context)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _fg(context),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}
