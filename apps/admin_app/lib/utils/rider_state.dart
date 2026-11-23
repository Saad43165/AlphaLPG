import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart' show Brand;
import 'package:material_ui/material_ui.dart';

import '../state/session.dart' show AdminSession;

/// One honest word for where a rider is: a rider delivering an order is never
/// shown as "Offline", even if the shift switch is off or the signal is weak.
class RiderState {
  const RiderState(this.label, this.color, this.rank);
  final String label;
  final Color color;

  /// For sorting: free riders first, then busy, then the rest.
  final int rank;
}

RiderState riderStateOf(
  RiderProfile r,
  List<LpgOrder> jobs,
  Color muted, {
  DateTime? now,
}) {
  const green = Color(0xFF1E8E4E);
  const orange = Color(0xFFE8710A);
  final live = r.isLive(now);
  final onRoad = jobs.where((o) => o.status == OrderStatus.outForDelivery);
  if (onRoad.isNotEmpty) {
    return RiderState(
      onRoad.length == 1 ? 'On the road' : '${onRoad.length} on the road',
      orange,
      1,
    );
  }
  if (live) {
    return jobs.isEmpty
        ? const RiderState('Free', green, 0)
        : RiderState(
            '${jobs.length} job${jobs.length == 1 ? '' : 's'}',
            orange,
            1,
          );
  }
  if (jobs.isNotEmpty) {
    return RiderState(
      '${jobs.length} job${jobs.length == 1 ? '' : 's'} · no signal',
      Brand.warning,
      2,
    );
  }
  if (r.online) return RiderState('No signal', Brand.warning, 3);
  return RiderState('Offline', muted, 4);
}

/// Handy: the state of [r] using the session's orders.
RiderState riderStateIn(AdminSession s, RiderProfile r, Color muted) =>
    riderStateOf(r, s.jobsOf(r.uid), muted);
