import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:provider/provider.dart';

import '../screens/chat_screen.dart';
import '../state/session.dart';
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
    this.stop,
  });
  final LpgOrder order;

  /// Where this order falls in the suggested round (only with 2+ orders).
  final RouteStop? stop;
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
                    if (stop != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Brand.blueDark,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          stop!.number == 1
                              ? 'Next stop'
                              : 'Stop ${stop!.number}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          o.displayNumber,
                          maxLines: 1,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    if (o.status == OrderStatus.assigned ||
                        o.status == OrderStatus.outForDelivery)
                      _ChatButton(order: o),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StatusChip(o.status),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        timeAgo(o.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: pal.muted, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  o.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
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
                            maxLines: 2,
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
                      maxLines: 3,
                    ),
                    if (o.scheduledFor != null)
                      Pill(
                        Icons.event_rounded,
                        'Scheduled ${DateFormat('d MMM').format(o.scheduledFor!)}',
                        color: Brand.flame,
                      ),
                    if (due > 0)
                      Pill(
                        Icons.payments_rounded,
                        'Take ${formatRupees(due)} cash',
                        color: const Color(0xFF9A6B00),
                      )
                    else if (o.paymentStatus == PaymentStatus.paid)
                      Pill(
                        Icons.check_circle_rounded,
                        o.paymentMethod.isPrepaid
                            ? 'Paid online: no cash'
                            : 'Paid',
                        color: Brand.success,
                      )
                    else
                      Pill(
                        Icons.hourglass_top_rounded,
                        'Wait: ${o.paymentMethod.label} not confirmed',
                        color: Brand.danger,
                      ),
                    if (o.emptiesToCollect > 0)
                      Pill(
                        Icons.autorenew_rounded,
                        'Take back ${o.emptiesToCollect} empty',
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

/// Chat with the customer, with a red count of unread messages.
class _ChatButton extends StatelessWidget {
  const _ChatButton({required this.order});
  final LpgOrder order;

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<RiderSession>().chat.unread(order.id);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        backgroundColor: Brand.cylinderRed,
        child: IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          tooltip: 'Message customer',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => JobChatScreen(order: order),
            ),
          ),
          icon: const Icon(Icons.forum_rounded, size: 20),
        ),
      ),
    );
  }
}
