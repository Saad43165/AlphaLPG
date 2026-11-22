import 'package:alpha_admin/utils/rider_state.dart';
import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Colors;

LpgOrder _o(OrderStatus s) => LpgOrder(
  customerId: 'c',
  customerName: 'C',
  customerPhone: '+923001234567',
  items: const [],
  subtotal: 0,
  deliveryFee: 0,
  total: 0,
  address: const Address(label: 'Home', line1: 'x', area: 'y'),
  status: s,
);

void main() {
  final now = DateTime(2026, 11, 22, 12);
  RiderProfile rider({
    bool online = true,
    int minutesAgo = 1,
    bool active = true,
  }) => RiderProfile(
    uid: 'r1',
    name: 'Imran',
    phone: '0300',
    active: active,
    online: online,
    lastSeen: now.subtract(Duration(minutes: minutesAgo)),
  );

  test('free, busy and offline', () {
    expect(
      riderStateOf(rider(), const [], Colors.grey, now: now).label,
      'Free',
    );
    expect(
      riderStateOf(
        rider(),
        [_o(OrderStatus.assigned)],
        Colors.grey,
        now: now,
      ).label,
      '1 job',
    );
    expect(
      riderStateOf(rider(online: false), const [], Colors.grey, now: now).label,
      'Offline',
    );
    expect(
      riderStateOf(
        rider(minutesAgo: 10),
        const [],
        Colors.grey,
        now: now,
      ).label,
      'No signal',
    );
  });

  test('a rider delivering an order is never shown as offline', () {
    final onRoad = [_o(OrderStatus.outForDelivery)];
    // Shift switch off and no signal for ten minutes: still "On the road".
    expect(
      riderStateOf(
        rider(online: false, minutesAgo: 10),
        onRoad,
        Colors.grey,
        now: now,
      ).label,
      'On the road',
    );
    // Assigned but the phone is silent: flagged, not "Offline".
    expect(
      riderStateOf(
        rider(minutesAgo: 10),
        [_o(OrderStatus.assigned)],
        Colors.grey,
        now: now,
      ).label,
      '1 job · no signal',
    );
  });
}
