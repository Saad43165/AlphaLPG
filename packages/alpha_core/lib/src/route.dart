import 'geo.dart';
import 'models/order.dart';
import 'models/order_status.dart';

/// One stop on a rider's round, in the order that saves the most riding.
class RouteStop {
  const RouteStop(this.order, this.number, this.km);
  final LpgOrder order;

  /// 1 = next.
  final int number;

  /// Straight-line distance from the previous point (the rider, or the
  /// previous stop). Null when a position is missing.
  final double? km;
}

/// Cylinders a rider is carrying right now (orders given to them and not yet
/// delivered).
int cylindersCarried(Iterable<LpgOrder> jobs) =>
    jobs.where((o) => o.status.isActive).fold(0, (n, o) => n + o.cylinderCount);

/// Which customer to visit first. Orders already on the road come before the
/// ones not started; inside each group the nearest comes next (starting from
/// the rider's position). Orders without a map position go last, in the order
/// they were given. This is a suggestion: the rider decides.
List<RouteStop> suggestedRoute(
  List<LpgOrder> jobs, {
  double? lat,
  double? lng,
}) {
  final out = <RouteStop>[];
  var here = lat != null && lng != null ? (lat: lat, lng: lng) : null;
  final groups = [
    jobs.where((o) => o.status == OrderStatus.outForDelivery).toList(),
    jobs.where((o) => o.status != OrderStatus.outForDelivery).toList(),
  ];
  for (final g in groups) {
    final withPos = g.where((o) => o.address.hasLocation).toList();
    final without = g.where((o) => !o.address.hasLocation).toList();
    while (withPos.isNotEmpty) {
      var best = 0;
      double? bestKm;
      if (here != null) {
        for (var i = 0; i < withPos.length; i++) {
          final a = withPos[i].address;
          final km = distanceKm(here.lat, here.lng, a.lat!, a.lng!);
          if (bestKm == null || km < bestKm) {
            bestKm = km;
            best = i;
          }
        }
      }
      final o = withPos.removeAt(best);
      out.add(RouteStop(o, out.length + 1, bestKm));
      here = (lat: o.address.lat!, lng: o.address.lng!);
    }
    for (final o in without) {
      out.add(RouteStop(o, out.length + 1, null));
    }
  }
  return out;
}
