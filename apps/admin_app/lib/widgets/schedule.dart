import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// "Today · Afternoon 12pm–4pm", "Tomorrow · …", "Tue 24 Nov · …".
String scheduleLabel(LpgOrder o) {
  final d = o.scheduledFor;
  if (d == null) return '';
  final now = DateTime.now();
  final diff = DateTime(
    d.year,
    d.month,
    d.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
  final day = diff == 0
      ? 'Today'
      : diff == 1
      ? 'Tomorrow'
      : DateFormat('EEE d MMM').format(d);
  final slot = o.slotText.isEmpty ? DateFormat('h a').format(d) : o.slotText;
  return '$day · $slot';
}

/// "in 3 days", "in 5 hours", "window open now".
String scheduleCountdown(LpgOrder o) {
  final d = o.scheduledFor;
  if (d == null) return '';
  final left = d.difference(DateTime.now());
  if (left.isNegative) return 'window is open now';
  if (left.inDays >= 1) {
    return 'in ${left.inDays} day${left.inDays == 1 ? '' : 's'}';
  }
  if (left.inHours >= 1) {
    return 'in ${left.inHours} hour${left.inHours == 1 ? '' : 's'}';
  }
  return 'in ${left.inMinutes} min';
}

/// A scheduled order is different: the customer picked a day and a time
/// window, so nobody should be sent before it. This says so, in one place.
class ScheduleBanner extends StatelessWidget {
  const ScheduleBanner(this.order, {super.key});
  final LpgOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    if (!o.isScheduled) return const SizedBox.shrink();
    final upcoming = o.isUpcoming();
    final color = upcoming ? const Color(0xFF6A3FC1) : context.pal.warn;
    final pal = context.pal;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.pal.card,
        borderRadius: BorderRadius.circular(Brand.radius),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_rounded, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SCHEDULED DELIVERY',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  scheduleLabel(o),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  upcoming
                      ? 'Starts ${scheduleCountdown(o)}. Confirm it now, then give it to a rider on the day. Riders only see it ${LpgOrder.scheduleLead.inHours} hours before.'
                      : 'The delivery window is ${scheduleCountdown(o)}. Send a rider now.',
                  style: TextStyle(
                    color: pal.muted,
                    height: 1.35,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small coloured line for lists.
class ScheduleChip extends StatelessWidget {
  const ScheduleChip(this.order, {super.key});
  final LpgOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    if (!o.isScheduled) return const SizedBox.shrink();
    final color = o.isUpcoming() ? const Color(0xFF6A3FC1) : context.pal.warn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.pal.card,
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Scheduled · ${scheduleLabel(o)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
