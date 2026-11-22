import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  Future<(dynamic, String)> setup(WidgetTester tester) async {
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
              productId: 'cyl-6kg',
              name: '6kg Gas Cylinder',
              sizeKg: 6,
              type: PurchaseType.refill,
              unitPrice: 1676,
              quantity: 1,
            ),
          ],
          subtotal: 1676,
          deliveryFee: 150,
          total: 1826,
          address: const Address(label: 'Home', line1: '1', area: 'DHA'),
        ),
      );
    });
    await pumpApp(tester, backend);
    GoRouter.of(tester.element(find.byType(Navigator).first))
        .go('/order-placed/$id');
    await tester.pumpAndSettle();
    return (backend, id);
  }

  testWidgets('placed: shows the order, and the customer can cancel it', (
    tester,
  ) async {
    final (backend, id) = await setup(tester);
    expect(find.text('Order placed!'), findsOneWidget);
    expect(find.text('Keep Rs. 1,826 cash ready'), findsOneWidget);
    await scrollTo(tester, find.text('Cancel this order'));
    expect(find.text('Track my order'), findsOneWidget);
    await tapText(tester, 'Cancel this order');
    await tapText(tester, 'Need a different size');
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel order'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Order cancelled'), findsWidgets);
    expect(find.text('Order again'), findsOneWidget);
    expect(find.text('Cancel this order'), findsNothing);
    final o = await tester.runAsync(() => backend.orders.watchOrder(id).first);
    expect(o!.status, OrderStatus.cancelled);
  });

  testWidgets('confirmed by the shop: cancel is replaced by a call option', (
    tester,
  ) async {
    final (backend, id) = await setup(tester);
    await tester.runAsync(() async {
      await backend.orders.updateStatus(id, OrderStatus.confirmed, 'boss');
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    expect(find.text('Order confirmed'), findsOneWidget);
    await scrollTo(tester, find.text('Need to change or cancel? Call us'));
    expect(find.text('Cancel this order'), findsNothing);
    expect(find.text('Need to change or cancel? Call us'), findsOneWidget);
  });

  testWidgets('cancelled by the shop: clear message and a way to order again', (
    tester,
  ) async {
    final (backend, id) = await setup(tester);
    await tester.runAsync(() async {
      await backend.orders.updateStatus(
        id,
        OrderStatus.cancelled,
        'boss',
        note: 'Out of stock',
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    expect(find.text('Order cancelled'), findsOneWidget);
    expect(find.text('Order again'), findsOneWidget);
    expect(find.text('Track my order'), findsNothing);
  });
}
