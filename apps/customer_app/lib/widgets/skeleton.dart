import 'package:material_ui/material_ui.dart' hide Text;

import '../theme/brand.dart';

/// Gives every [SkeletonBox] below it one shared, softly moving shine, so a
/// whole placeholder screen shimmers in step (like Careem / Uber loading).
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "Remove animations" in the phone settings: show still placeholders.
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.pal.isDark;
    final base = dark ? const Color(0xFF2A2D33) : const Color(0xFFE6EAEF);
    final shine = dark ? const Color(0xFF3B3F47) : const Color(0xFFF5F7FA);
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          child: widget.child,
          builder: (context, child) => ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (r) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, shine, base],
              stops: const [0.25, 0.5, 0.75],
              transform: _Slide(_c.value),
            ).createShader(r),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Slide extends GradientTransform {
  const _Slide(this.t);
  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}

/// A grey rounded block. Put it inside a [Shimmer].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFE6EAEF),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

BoxDecoration _cardBox(BuildContext context) => BoxDecoration(
  color: context.pal.card,
  borderRadius: BorderRadius.circular(Brand.radius),
  boxShadow: context.pal.shadow,
);

/// Placeholder for the home screen product grid.
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({super.key, this.columns = 2, this.count = 4});
  final int columns;
  final int count;

  @override
  Widget build(BuildContext context) => Shimmer(
    child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: count,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        mainAxisExtent: 282,
      ),
      itemBuilder: (_, _) => Container(
        padding: const EdgeInsets.all(8),
        decoration: _cardBox(context),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SkeletonBox(height: double.infinity, radius: 14)),
            SizedBox(height: 14),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: SkeletonBox(height: 14),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: SkeletonBox(width: 80, height: 14),
            ),
            SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.only(left: 6, bottom: 4),
              child: Row(
                children: [
                  SkeletonBox(width: 70, height: 22),
                  Spacer(),
                  SkeletonBox(width: 40, height: 40, radius: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Placeholder for a list of order cards.
class OrderListSkeleton extends StatelessWidget {
  const OrderListSkeleton({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) => Shimmer(
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardBox(context),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(width: 110, height: 16),
                Spacer(),
                SkeletonBox(width: 70, height: 22, radius: 11),
              ],
            ),
            SizedBox(height: 14),
            SkeletonBox(height: 12),
            SizedBox(height: 8),
            SkeletonBox(width: 160, height: 12),
            SizedBox(height: 14),
            SkeletonBox(width: 90, height: 16),
          ],
        ),
      ),
    ),
  );
}

/// Placeholder for one order's page (status card + items + bill).
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Shimmer(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardBox(context),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 180, height: 20),
              SizedBox(height: 12),
              SkeletonBox(height: 12),
              SizedBox(height: 18),
              SkeletonBox(height: 8, radius: 4),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < 2; i++) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardBox(context),
            child: const Row(
              children: [
                SkeletonBox(width: 56, height: 56, radius: 12),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(height: 14),
                      SizedBox(height: 8),
                      SkeletonBox(width: 90, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardBox(context),
          child: const Column(
            children: [
              SkeletonBox(height: 12),
              SizedBox(height: 10),
              SkeletonBox(height: 12),
              SizedBox(height: 10),
              SkeletonBox(height: 16),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A few plain lines, for small sections that are still loading.
class LinesSkeleton extends StatelessWidget {
  const LinesSkeleton({super.key, this.lines = 3});
  final int lines;

  @override
  Widget build(BuildContext context) => Shimmer(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines; i++) ...[
            SkeletonBox(height: 14, width: i == lines - 1 ? 160 : null),
            const SizedBox(height: 12),
          ],
        ],
      ),
    ),
  );
}
