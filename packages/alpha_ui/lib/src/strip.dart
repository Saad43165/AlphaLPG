import 'package:material_ui/material_ui.dart';

import 'brand.dart';

/// A slim, solid status bar: an icon, one or two lines of text and optional
/// buttons. Used for "sharing location", "shop is closed", "needs attention"…
/// White text on a solid colour (navy on light colours), never see-through.
class StatusStrip extends StatelessWidget {
  const StatusStrip({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    this.detail,
    this.actions = const [],
    this.onTap,
    this.margin = const EdgeInsets.fromLTRB(12, 6, 12, 0),
    this.chevron = false,
  });

  final IconData icon;
  final String text;
  final String? detail;
  final Color color;
  final List<Widget> actions;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final fill = Tone.fill(color);
    final fg = Tone.on(fill);
    return Padding(
      padding: margin,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                  child: Icon(icon, size: 16, color: fill),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          height: 1.25,
                        ),
                      ),
                      if (detail != null)
                        Text(
                          detail!,
                          style: TextStyle(
                            color: fg,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                    ],
                  ),
                ),
                for (final a in actions)
                  DefaultTextStyle.merge(
                    style: TextStyle(color: fg),
                    child: IconTheme(
                      data: IconThemeData(color: fg),
                      child: a,
                    ),
                  ),
                if (chevron) Icon(Icons.chevron_right_rounded, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A white-on-colour text button for the [actions] list.
  static Widget action(
    BuildContext context,
    String label,
    VoidCallback onPressed,
    Color color,
  ) {
    final fg = Tone.on(Tone.fill(color));
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: fg,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
