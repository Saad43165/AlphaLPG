import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_customer/services/backend.dart';
import 'package:alpha_customer/state/cart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

Future<Backend> signedInBackend(
  WidgetTester tester, {
  bool extrasOn = true,
}) async {
  final backend = testBackend();
  await tester.runAsync(() async {
    if (extrasOn) {
      await backend.catalog.saveSettings(
        AppSettings.fromMap({
          ...SeedData.settings.toMap(),
          'loginMode': 'sms',
          'pointsSince': 1,
          'planEnabled': true,
        }),
      );
    }
    await backend.auth.sendCode('+923001234567');
    await backend.auth.verifyCode('123456');
    await backend.profiles.saveAddress(
      backend.auth.uid!,
      const Address(
        label: 'Home',
        line1: 'House 12, Gulberg III',
        area: 'Gulberg',
        lat: 31.51,
        lng: 74.34,
      ),
    );
    await backend.profiles.saveProfile(
      CustomerProfile(
        uid: backend.auth.uid!,
        name: 'Bilal',
        phone: '+923001234567',
      ),
      isNew: true,
    );
  });
  return backend;
}

LpgOrder _sample(String uid) => LpgOrder(
  customerId: uid,
  customerName: 'Bilal',
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
  address: const Address(label: 'Home', line1: 'House 12', area: 'Gulberg'),
);

void main() {
  testWidgets(
    'a coupon and reward points lower the price and are saved on the order',
    (tester) async {
      final backend = await signedInBackend(tester);
      final uid = backend.auth.uid!;
      await tester.runAsync(() async {
        await backend.promo.saveCoupon(
          const Coupon(code: 'WELCOME200', value: 200),
        );
        final id = await backend.orders.place(_sample(uid));
        await backend.orders.updateStatus(id, OrderStatus.delivered, 'admin');
        final o = (await backend.orders.watchOrder(id).first)!;
        await backend.promo.awardDelivery(o, points: 500);
      });
      await pumpApp(tester, backend);
      Provider.of<Cart>(
        tester.element(find.byType(Navigator).first),
        listen: false,
      ).add('cyl-11-8kg', PurchaseType.refill);
      GoRouter.of(tester.element(find.byType(Navigator).first)).go('/checkout');
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Apply'));
      // A wrong code says why.
      await tester.enterText(
        find.widgetWithText(TextField, "Coupon or friend's invite code"),
        'nope',
      );
      await tester.tap(find.text('Apply'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('That code is not valid.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, "Coupon or friend's invite code"),
        'welcome200',
      );
      await tester.tap(find.text('Apply'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('WELCOME200 · Rs. 200 off'), findsOneWidget);

      // Points: 30% of Rs. 3,296 = 988, minus nothing: all 500 can be used.
      await scrollTo(tester, find.textContaining('Use 500 points'));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(Navigator).first)).go('/checkout');
      await tester.pumpAndSettle();
      await slideToOrder(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();

      final list = (await tester.runAsync(
        () => backend.orders.watchCustomerOrders(uid).first,
      ))!;
      final placed = list.firstWhere((o) => o.status == OrderStatus.placed);
      expect(placed.couponCode, 'WELCOME200');
      expect(placed.couponDiscount, 200);
      expect(
        placed.total,
        placed.subtotal + placed.deliveryFee - placed.discount,
      );
      expect(placed.total, lessThan(3446));
      expect(
        await tester.runAsync(
          () => backend.promo.alreadyUsed('WELCOME200', uid),
        ),
        isTrue,
      );
    },
  );

  testWidgets('rewards screen shows points, the invite code and history', (
    tester,
  ) async {
    final backend = await signedInBackend(tester);
    final uid = backend.auth.uid!;
    await tester.runAsync(() async {
      final id = await backend.orders.place(_sample(uid));
      await backend.orders.updateStatus(id, OrderStatus.delivered, 'admin');
      final o = (await backend.orders.watchOrder(id).first)!;
      await backend.promo.awardDelivery(o, points: 70);
    });
    await pumpApp(tester, backend);
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/rewards');
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pumpAndSettle();
    expect(find.text('70'), findsOneWidget);
    expect(find.text(referralCodeFor(uid)), findsOneWidget);
    expect(find.text('+70'), findsOneWidget);
  });

  testWidgets(
    'a refill plan that is due shows on the home screen and fills the cart',
    (tester) async {
      final backend = await signedInBackend(tester);
      final uid = backend.auth.uid!;
      await tester.runAsync(() async {
        final id = await backend.orders.place(_sample(uid));
        await backend.orders.updateStatus(id, OrderStatus.delivered, 'admin');
        await backend.promo.savePlan(
          uid,
          RefillPlan(
            lines: const [
              {'productId': 'cyl-11-8kg', 'type': 'refill', 'quantity': 2},
            ],
            nextDue: DateTime.now().subtract(const Duration(days: 1)),
          ),
        );
      });
      await pumpApp(tester, backend);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Time for your refill'), findsOneWidget);
      await tester.tap(find.text('Time for your refill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Order now (it is due)'));
      await tester.pumpAndSettle();
      final cart = Provider.of<Cart>(
        tester.element(find.byType(Navigator).first),
        listen: false,
      );
      expect(cart.quantityOf('cyl-11-8kg'), 2);
    },
  );

  testWidgets('help center lists earlier requests with their refund outcome', (
    tester,
  ) async {
    final backend = await signedInBackend(tester);
    final uid = backend.auth.uid!;
    await tester.runAsync(() async {
      final id = await backend.orders.place(_sample(uid));
      await backend.orders.addReport(
        OrderReport(
          orderId: id,
          orderNumber: 'AL-1',
          customerId: uid,
          reason: 'Refund request',
          details: 'Cylinder was empty',
        ),
      );
      final r = (await backend.orders.watchReports().first).single;
      await backend.orders.resolveReport(
        r.id,
        reply: 'Sorry, refunded.',
        refund: 'refunded',
      );
    });
    await pumpApp(tester, backend);
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/support');
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Report a problem with an order'), findsOneWidget);
    await scrollTo(tester, find.text('Refunded'));
    expect(find.text('Refunded'), findsOneWidget);
    expect(find.textContaining('Sorry, refunded.'), findsOneWidget);
  });

  testWidgets(
    'the home screen shows the shop rating once there are enough reviews',
    (tester) async {
      final backend = testBackend();
      await tester.runAsync(
        () => backend.promo.publishStats(
          const PublicStats(
            ratingAverage: 4.8,
            ratingCount: 30,
            deliveredCount: 320,
          ),
        ),
      );
      await pumpApp(tester, backend);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pumpAndSettle();
      expect(find.text('4.8 · 320+ deliveries'), findsOneWidget);
    },
  );

  testWidgets('with the extras switched off there are no points and no plan', (
    tester,
  ) async {
    final backend = await signedInBackend(tester, extrasOn: false);
    final uid = backend.auth.uid!;
    await tester.runAsync(() async {
      await backend.promo.savePlan(
        uid,
        RefillPlan(
          lines: const [
            {'productId': 'cyl-11-8kg', 'type': 'refill', 'quantity': 1},
          ],
          nextDue: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
    });
    await pumpApp(tester, backend);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Time for your refill'), findsNothing);
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/account');
    await tester.pumpAndSettle();
    expect(find.text('Invite friends'), findsOneWidget);
    expect(find.text('Refill plan'), findsNothing);
    expect(find.text('Rewards and invite friends'), findsNothing);
    expect(find.text('Help center'), findsOneWidget);
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/rewards');
    await tester.pumpAndSettle();
    expect(find.text('Your points'), findsNothing);
    expect(find.text(referralCodeFor(uid)), findsOneWidget);
  });
}
