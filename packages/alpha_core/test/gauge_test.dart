import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_test/flutter_test.dart';

LpgOrder delivered(
  DateTime at, {
  double kg = 11.8,
  int qty = 1,
  CustomerSegment type = CustomerSegment.home,
}) => LpgOrder(
  id: 'o${at.millisecondsSinceEpoch}',
  customerId: 'u',
  customerName: 'A',
  customerPhone: '+923000000000',
  customerType: type,
  items: [
    OrderItem(
      productId: 'p',
      name: 'Cyl',
      sizeKg: kg,
      type: PurchaseType.refill,
      unitPrice: 1,
      quantity: qty,
    ),
  ],
  subtotal: 1,
  deliveryFee: 0,
  total: 1,
  address: const Address(label: 'Home', line1: 'x', area: 'y'),
  status: OrderStatus.delivered,
  history: [StatusEvent(status: OrderStatus.delivered, at: at)],
  createdAt: at,
);

void main() {
  final now = DateTime(2026, 11, 20, 12);

  test('no delivered orders → no gauge', () {
    expect(CylinderGauge.from(const [], now: now), isNull);
  });

  test('a home 11.8kg cylinder is estimated to last about a month', () {
    final g = CylinderGauge.from([
      delivered(now.subtract(const Duration(days: 15))),
    ], now: now)!;
    expect(g.cycleDays, 30);
    expect(g.remaining, closeTo(0.5, 0.02));
    expect(g.daysLeft, 15);
    expect(g.basedOnHistory, isFalse);
    expect(g.sizeLabel, '11.8kg');
    expect(g.isLow, isFalse);
  });

  test('a restaurant burns through a 45.4kg cylinder in about two weeks', () {
    final g = CylinderGauge.from([
      delivered(
        now.subtract(const Duration(days: 12)),
        kg: 45.4,
        type: CustomerSegment.business,
      ),
    ], now: now)!;
    expect(g.cycleDays, 14);
    expect(g.isLow, isTrue);
  });

  test('real order history overrides the size-based estimate', () {
    final g = CylinderGauge.from([
      delivered(now.subtract(const Duration(days: 5))),
      delivered(now.subtract(const Duration(days: 25))),
      delivered(now.subtract(const Duration(days: 45))),
    ], now: now)!;
    expect(g.cycleDays, 20);
    expect(g.basedOnHistory, isTrue);
    expect(g.remaining, closeTo(0.75, 0.02));
  });

  test('customer setting wins, and the meter never goes below empty', () {
    final g = CylinderGauge.from(
      [delivered(now.subtract(const Duration(days: 80)))],
      now: now,
      cycleDaysOverride: 21,
    )!;
    expect(g.cycleDays, 21);
    expect(g.remaining, 0);
    expect(g.daysLeft, 0);
    expect(g.isEmpty, isTrue);
    expect(g.headline, 'Probably empty');
  });
}
