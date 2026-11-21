import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/cart.dart';
import '../theme/brand.dart';
import '../utils/haptics.dart';
import 'gas_cylinder.dart';

String _ago(DateTime d) {
  final days = DateTime.now().difference(d).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  return '$days days ago';
}

/// Your gas, at a glance: a live cylinder, how many days are left, and a
/// one-tap refill when it is running low.
class GasMeterCard extends StatelessWidget {
  const GasMeterCard({super.key, required this.gauge, required this.lastOrder});
  final CylinderGauge gauge;
  final LpgOrder lastOrder;

  @override
  Widget build(BuildContext context) {
    final low = gauge.isLow;
    final accent = low ? Brand.flame : Brand.blueLight;
    final days = gauge.daysLeft;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2A3F), Color(0xFF16466A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: low
            ? Border.all(color: Brand.flame.withValues(alpha: 0.7), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: (low ? Brand.flame : Brand.blueDeep).withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GasCylinder(
                level: gauge.remaining,
                width: 66,
                height: 102,
                outline: Colors.white.withValues(alpha: 0.9),
                glass: Colors.white.withValues(alpha: 0.08),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'YOUR GAS METER',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => showCycleSheet(context, gauge),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.tune_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      gauge.isEmpty
                          ? 'Time to refill'
                          : '$days ${days == 1 ? 'day' : 'days'} left',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${gauge.headline} · filled ${_ago(gauge.lastDelivery)}',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      gauge.basedOnHistory
                          ? 'Based on your last orders · ${gauge.sizeLabel}'
                          : 'Estimated for a ${gauge.sizeLabel} refill · lasts ~${gauge.cycleDays} days',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: low
                        ? Brand.flame
                        : Colors.white.withValues(alpha: 0.16),
                    foregroundColor: low ? Brand.navy : Colors.white,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  onPressed: () {
                    Haptics.medium();
                    context.read<Cart>().reorder(lastOrder);
                    context.push('/cart');
                  },
                  icon: const Icon(Icons.replay_rounded, size: 20),
                  label: Text(low ? 'Refill now' : 'Refill early'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lets the customer say how long a cylinder really lasts at their place.
Future<void> showCycleSheet(BuildContext context, CylinderGauge? gauge) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final state = sheet.watch<AppState>();
      const options = [
        (14, '2 weeks'),
        (21, '3 weeks'),
        (30, '1 month'),
        (42, '6 weeks'),
        (60, '2 months'),
      ];
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How long does a cylinder last?',
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Tell us once and your gas meter and refill reminders become accurate.',
                style: TextStyle(color: sheet.pal.muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Auto'),
                    avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                    selected: state.cycleDaysOverride == null,
                    showCheckmark: false,
                    onSelected: (_) {
                      state.setCycleDays(null);
                      Navigator.pop(sheet);
                    },
                  ),
                  for (final (days, label) in options)
                    ChoiceChip(
                      label: Text(label),
                      selected: state.cycleDaysOverride == days,
                      showCheckmark: false,
                      onSelected: (_) {
                        Haptics.select();
                        state.setCycleDays(days);
                        Navigator.pop(sheet);
                      },
                    ),
                ],
              ),
              if (gauge != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Right now we estimate ${gauge.cycleDays} days per cylinder.',
                  style: TextStyle(color: sheet.pal.muted, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
