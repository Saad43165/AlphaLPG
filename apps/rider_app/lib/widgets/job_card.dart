import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../utils/launch.dart';
import '../utils/order_x.dart';
import 'common.dart';

/// One delivery job in a list.
class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.order,
    required this.onTap,
    this.action,
  });
  final LpgOrder order;
  final VoidCallback onTap;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final pal = context.pal;
    final due = o.amountDue;
    return Container(
      decoration: panel(context),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(Brand.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        o.displayNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      timeAgo(o.createdAt),
                      style: TextStyle(color: pal.muted, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(o.status),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 20,
                      color: Brand.blueDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.areaLine,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            o.address.line1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: pal.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Pill(
                      Icons.propane_tank_rounded,
                      o.itemsLine,
                      color: Brand.blueDark,
                    ),
                    if (due > 0)
                      Pill(
                        Icons.payments_rounded,
                        'Collect ${formatRupees(due)}',
                        color: const Color(0xFF9A6B00),
                      )
                    else if (o.paymentStatus == PaymentStatus.paid)
                      const Pill(
                        Icons.check_circle_rounded,
                        'Paid',
                        color: Brand.success,
                      )
                    else
                      Pill(
                        Icons.hourglass_top_rounded,
                        '${o.paymentMethod.label}: awaiting',
                        color: pal.muted,
                      ),
                  ],
                ),
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
