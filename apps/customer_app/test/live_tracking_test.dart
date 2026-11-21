import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Customer opens the tracking screen of an order that is out for delivery.
Future<dynamic> openTracking(
  WidgetTester tester, {
  OrderStatus status = OrderStatus.outForDelivery,
  RiderLocation? rider,
}) async {
  final backend = testBackend();
  late String id;
  await tester.runAsync(() async {
    await backend.auth.sendCode('+923001234567');
    await backend.auth.verifyCode('123456');
    await backend.profiles.saveProfile(
      CustomerProfile(
        uid: backend.auth.uid!,
        name: 'Sara',
        phone: '+923001234567',
      ),
      isNew: true,
    );
    id = await backend.orders.place(
      LpgOrder(
        customerId: backend.auth.uid!,
        customerName: 'Sara',
        customerPhone: '+923001234567',
        items: const [
          OrderItem(
            productId: 'cyl-11-8kg',
            name: '11.8kg Gas Cylinder',
            sizeKg: 11.8,
            type: PurchaseType.refill,
            unitPrice: 3296,
            quantity: 1,
          ),
        ],
        subtotal: 3296,
        deliveryFee: 150,
        total: 3446,
        address: const Address(
          label: 'Home',
          line1: 'Main Boulevard',
          area: 'Gulberg III',
          lat: 31.5107,
          lng: 74.3445,
        ),
      ),
    );
    if (status != OrderStatus.placed) {
      await backend.orders.acceptOrder(
        id,
        riderId: 'r1',
        name: 'Imran Khan',
        phone: '+923005550001',
      );
    }
    if (status == OrderStatus.outForDelivery)
      await backend.orders.startDelivery(id, 'r1');
    if (rider != null) await backend.orders.publishRiderLocation(id, rider);
  });
  await pumpApp(tester, backend);
  await tapText(tester, 'My orders');
  await tapText(tester, '1× 11.8kg Gas Cylinder');
  return backend;
}

void main() {
  testWidgets(
    'real rider position gives a distance-based estimate, labelled as one',
    (tester) async {
      // About 1.1 km north of the delivery pin, doing 30 km/h.
      await openTracking(
        tester,
        rider: const RiderLocation(lat: 31.5207, lng: 74.3445, speedKmh: 30),
      );
      expect(find.text('About 3 min away'), findsOneWidget);
      expect(find.textContaining('estimate'), findsOneWidget);
      expect(find.textContaining('km straight-line'), findsOneWidget);
      expect(find.text('Imran Khan'), findsOneWidget);
    },
  );

  testWidgets('rider at the door → almost there', (tester) async {
    await openTracking(
      tester,
      rider: const RiderLocation(lat: 31.5108, lng: 74.3445, speedKmh: 5),
    );
    expect(find.text('Your rider is almost there'), findsOneWidget);
  });

  testWidgets(
    'no location yet → honest waiting message, no made-up arrival time',
    (tester) async {
      await openTracking(tester);
      expect(find.textContaining('Waiting for their location'), findsOneWidget);
      expect(find.textContaining('min away'), findsNothing);
      expect(find.textContaining('Arriving by'), findsNothing);
    },
  );

  testWidgets('before dispatch there is no invented arrival time either', (
    tester,
  ) async {
    await openTracking(tester, status: OrderStatus.placed);
    expect(find.textContaining('Arriving by'), findsNothing);
    expect(find.textContaining('Waiting for their location'), findsNothing);
  });
}
