import 'models/order.dart';
import 'models/order_status.dart';
import 'models/product.dart';

/// How full a household's gas cylinder probably is, worked out from past
/// orders. Powers the "gas meter" on the home screen and reorder nudges.
class CylinderGauge {
  const CylinderGauge({
    required this.remaining,
    required this.daysLeft,
    required this.cycleDays,
    required this.lastDelivery,
    required this.sizeLabel,
    required this.basedOnHistory,
  });

  /// 0 (empty) to 1 (full).
  final double remaining;
  final int daysLeft;

  /// How many days a refill lasts for this customer.
  final int cycleDays;
  final DateTime lastDelivery;
  final String sizeLabel;

  /// True when the cycle was measured from real order history rather than a
  /// size-based estimate.
  final bool basedOnHistory;

  bool get isLow => remaining <= 0.25;
  bool get isEmpty => remaining <= 0.05;

  String get headline {
    if (isEmpty) return 'Probably empty';
    if (isLow) return 'Running low';
    if (remaining > 0.8) return 'Freshly filled';
    return 'Looking good';
  }

  /// Typical gas use per day: a home burns about 0.4 kg, a kitchen about 3 kg.
  static const homeKgPerDay = 0.4;
  static const businessKgPerDay = 3.2;

  /// Returns null when the customer has no delivered orders yet.
  static CylinderGauge? from(
    List<LpgOrder> orders, {
    DateTime? now,
    int? cycleDaysOverride,
  }) {
    final at = now ?? DateTime.now();
    final delivered = [
      for (final o in orders)
        if (o.status == OrderStatus.delivered) o,
    ]..sort((a, b) => _when(b).compareTo(_when(a)));
    if (delivered.isEmpty) return null;

    final last = delivered.first;
    final lastAt = _when(last);

    // Kilograms delivered in the last order (refills only count as gas).
    final kg = last.items.fold<double>(0, (n, i) => n + i.sizeKg * i.quantity);
    final rate = last.customerType == CustomerSegment.business
        ? businessKgPerDay
        : homeKgPerDay;
    var cycle = (kg / rate).round().clamp(5, 90);
    var history = false;

    // With two or more deliveries, trust the real gap between them.
    if (delivered.length >= 2) {
      final gaps = <int>[];
      for (var i = 0; i < delivered.length - 1 && gaps.length < 4; i++) {
        final d = _when(delivered[i])
            .difference(_when(delivered[i + 1]))
            .inDays;
        if (d >= 3 && d <= 120) gaps.add(d);
      }
      if (gaps.isNotEmpty) {
        cycle = (gaps.reduce((a, b) => a + b) / gaps.length).round();
        history = true;
      }
    }
    if (cycleDaysOverride != null) {
      cycle = cycleDaysOverride.clamp(5, 120);
    }

    final elapsed = at.difference(lastAt).inHours / 24;
    final remaining = (1 - elapsed / cycle).clamp(0.0, 1.0);
    final size = last.items.isEmpty ? '' : _label(last.items.first.sizeKg);

    return CylinderGauge(
      remaining: remaining,
      daysLeft: (cycle - elapsed).ceil().clamp(0, 999),
      cycleDays: cycle,
      lastDelivery: lastAt,
      sizeLabel: size,
      basedOnHistory: history && cycleDaysOverride == null,
    );
  }

  static DateTime _when(LpgOrder o) =>
      o.timeOf(OrderStatus.delivered) ??
      o.updatedAt ??
      o.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  static String _label(double kg) =>
      '${kg == kg.roundToDouble() ? kg.toInt() : kg}kg';
}
