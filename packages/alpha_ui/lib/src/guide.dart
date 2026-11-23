import 'package:material_ui/material_ui.dart';

import 'brand.dart';

/// Text in both languages. Urdu is written right to left.
class Bi {
  const Bi(this.en, this.ur);
  final String en;
  final String ur;
}

/// One part of a guide: a heading, a few numbered steps and an optional tip.
class GuideSection {
  const GuideSection({
    required this.icon,
    required this.title,
    required this.steps,
    this.intro,
    this.tip,
  });
  final IconData icon;
  final Bi title;
  final Bi? intro;
  final List<Bi> steps;

  /// A highlighted "good to know" line under the steps.
  final Bi? tip;
}

/// A calm, professional "how this app works" page in English and Urdu. The
/// reader switches language at the top; each app only supplies the words.
class GuidePage extends StatefulWidget {
  const GuidePage({
    super.key,
    required this.appName,
    required this.headline,
    required this.intro,
    required this.sections,
    this.contactPhone = '',
    this.startInUrdu = false,
    this.onTour,
  });

  final Bi appName;
  final Bi headline;
  final Bi intro;
  final List<GuideSection> sections;

  /// Shown at the bottom as "Need help? Call the shop".
  final String contactPhone;
  final bool startInUrdu;

  /// Shows a "Watch the quick tour" button that replays the welcome tour.
  final VoidCallback? onTour;

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  late bool _urdu = widget.startInUrdu;
  int _open = 0;

  static const _urduFont = 'NotoNaskh';

  TextStyle _style(
    BuildContext context, {
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
  }) => TextStyle(
    fontSize: _urdu ? size + 1.5 : size,
    fontWeight: weight,
    color: color ?? context.pal.ink,
    height: height ?? (_urdu ? 1.9 : 1.45),
    fontFamily: _urdu ? _urduFont : null,
  );

  String _t(Bi b) => _urdu ? b.ur : b.en;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Directionality(
      textDirection: _urdu ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _t(widget.appName),
            style: TextStyle(
              fontFamily: _urdu ? _urduFont : null,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                // Language choice.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('English')),
                      ButtonSegment(
                        value: true,
                        label: Text(
                          'اردو',
                          style: TextStyle(
                            fontFamily: _urduFont,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    selected: {_urdu},
                    onSelectionChanged: (v) => setState(() => _urdu = v.first),
                  ),
                ),
                if (widget.onTour != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: widget.onTour,
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: Text(
                      _urdu ? 'مختصر ٹور دیکھیں' : 'Watch the quick tour',
                      style: TextStyle(fontFamily: _urdu ? _urduFont : null),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                // Welcome card.
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: Brand.headerGradient,
                    borderRadius: BorderRadius.circular(Brand.radius),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(widget.headline),
                        style: _style(
                          context,
                          size: 22,
                          weight: FontWeight.w800,
                          color: Colors.white,
                          height: _urdu ? 1.7 : 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(widget.intro),
                        style: _style(
                          context,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < widget.sections.length; i++)
                  _card(context, i, widget.sections[i]),
                if (widget.contactPhone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: pal.card,
                      borderRadius: BorderRadius.circular(Brand.radius),
                      border: Border.all(color: pal.line),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.support_agent_rounded,
                          color: Brand.blueDark,
                          size: 30,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _urdu ? 'مدد چاہیے؟' : 'Need help?',
                                style: _style(
                                  context,
                                  size: 16,
                                  weight: FontWeight.w800,
                                ),
                              ),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  _urdu
                                      ? 'الفا ایل پی جی کو کال کریں: ${widget.contactPhone}'
                                      : 'Call Alpha LPG: ${widget.contactPhone}',
                                  style: _style(context, color: pal.muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, int index, GuideSection s) {
    final pal = context.pal;
    final open = _open == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(Brand.radius),
        border: Border.all(color: open ? Brand.blueDark : pal.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _open = open ? -1 : index),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Brand.blue.withValues(alpha: 0.14),
                      child: Icon(s.icon, color: Brand.blueDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _t(s.title),
                        style: _style(
                          context,
                          size: 16,
                          weight: FontWeight.w800,
                          height: _urdu ? 1.6 : 1.25,
                        ),
                      ),
                    ),
                    Icon(
                      open
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: pal.muted,
                    ),
                  ],
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s.intro != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _t(s.intro!),
                          style: _style(context, color: pal.muted),
                        ),
                      ),
                    for (var n = 0; n < s.steps.length; n++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              margin: const EdgeInsets.only(top: 2),
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Brand.blueDark,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${n + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _t(s.steps[n]),
                                style: _style(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (s.tip != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Brand.flame.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lightbulb_rounded,
                              color: Color(0xFF9A6B00),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _t(s.tip!),
                                style: _style(
                                  context,
                                  size: 14,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
