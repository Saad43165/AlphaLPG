import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_test/flutter_test.dart';

LpgOrder o(
  String id,
  double lat,
  double lng, {
  OrderStatus status = OrderStatus.assigned,
  int qty = 1,
}) => LpgOrder(
  id: id,
  customerId: 'c',
  customerName: id,
  customerPhone: '+923001234567',
  items: [
    OrderItem(
      productId: 'p',
      name: 'p',
      sizeKg: 11.8,
      type: PurchaseType.refill,
      unitPrice: 1,
      quantity: qty,
    ),
  ],
  subtotal: 1,
  deliveryFee: 0,
  total: 1,
  address: Address(label: 'H', line1: 'x', area: 'y', lat: lat, lng: lng),
  status: status,
);

void main() {
  test('the nearest customer comes first, then the next nearest', () {
    // The rider is at the depot; B is closest, then A, then C.
    final route = suggestedRoute(
      [o('A', 31.54, 74.34), o('C', 31.60, 74.40), o('B', 31.52, 74.34)],
      lat: 31.51,
      lng: 74.34,
    );
    expect([for (final s in route) s.order.id], ['B', 'A', 'C']);
    expect([for (final s in route) s.number], [1, 2, 3]);
    expect(route.first.km, closeTo(1.1, 0.1));
  });

  test('an order already on the road is always visited before the rest', () {
    final route = suggestedRoute(
      [
        o('near', 31.511, 74.34),
        o('far', 31.70, 74.50, status: OrderStatus.outForDelivery),
      ],
      lat: 31.51,
      lng: 74.34,
    );
    expect(route.first.order.id, 'far');
  });

  test('orders without a position go last; no rider position still works', () {
    final noPin = LpgOrder(
      id: 'N',
      customerId: 'c',
      customerName: 'N',
      customerPhone: '+923001234567',
      items: const [],
      subtotal: 0,
      deliveryFee: 0,
      total: 0,
      address: const Address(label: 'H', line1: 'x', area: 'y'),
      status: OrderStatus.assigned,
    );
    final route = suggestedRoute([noPin, o('A', 31.5, 74.3)]);
    expect([for (final s in route) s.order.id], ['A', 'N']);
    expect(route.last.km, isNull);
  });

  test('cylinders carried and the capacity limit', () {
    final jobs = [
      o('A', 31.5, 74.3, qty: 3),
      o('B', 31.5, 74.3, qty: 2, status: OrderStatus.delivered),
      o('C', 31.5, 74.3, qty: 4, status: OrderStatus.outForDelivery),
    ];
    expect(cylindersCarried(jobs), 7, reason: 'delivered ones are not carried');
    const bike = RiderProfile(uid: 'r', name: 'R', phone: '0', capacity: 8);
    expect(bike.overCapacity(7, 1), isFalse);
    expect(bike.overCapacity(7, 2), isTrue);
    const unlimited = RiderProfile(uid: 'r', name: 'R', phone: '0');
    expect(unlimited.overCapacity(50, 50), isFalse);
  });
}
