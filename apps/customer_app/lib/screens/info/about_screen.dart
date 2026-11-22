import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/brand.dart';
import '../../widgets/common.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _offers = [
    (
      Icons.home_rounded,
      'Home refills',
      '6kg, 10kg composite and 11.8kg cylinders for everyday cooking.',
    ),
    (
      Icons.restaurant_rounded,
      'Commercial supply',
      '45.4kg cylinders on a schedule for restaurants, hotels and bakeries.',
    ),
    (
      Icons.factory_rounded,
      'Bulk & industrial LPG',
      'Volume supply and monthly billing for factories and large kitchens.',
    ),
    (
      Icons.health_and_safety_rounded,
      'Safety first',
      'Safe cylinders, trained riders and clear safety guidance.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            pinned: true,
            leading: ScreenBack(),
            title: Text('About us'),
          ),
          SliverToBoxAdapter(
            child: Constrained(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Container(
                  height: 240,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: context.pal.shadow,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/brand/photo_depot.jpg',
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x000F2A3F), Color(0xE60F2A3F)],
                            stops: [0.35, 1],
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 18,
                        right: 18,
                        bottom: 16,
                        child: Text(
                          'Reliable LPG for homes and businesses across Lahore.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Constrained(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Safe cylinders, straightforward ordering, and convenient delivery when you need it.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.45,
                        color: context.pal.muted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      children: [
                        _Stat('4', 'cylinder\nsizes'),
                        SizedBox(width: 10),
                        _Stat('Same', 'day\ndelivery'),
                        SizedBox(width: 10),
                        _Stat('7', 'days a\nweek'),
                      ],
                    ),
                    const SectionTitle('What we offer'),
                    for (final (icon, title, body) in _offers)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.pal.card,
                            borderRadius: BorderRadius.circular(Brand.radius),
                            boxShadow: context.pal.shadow,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: context.pal.tint,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: Brand.blueDark),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      body,
                                      style: TextStyle(
                                        color: context.pal.muted,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Brand.radius),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.asset(
                          'assets/brand/photo_truck.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Order LPG now'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Brand.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Brand.flame,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ],
      ),
    ),
  );
}
