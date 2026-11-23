import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  testWidgets(
    'online order: banner first, shop details shown, customer sends ID + amount',
    (tester) async {
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
            paymentMethod: PaymentMethod.easyPaisa,
          ),
        );
      });
      await pumpApp(tester, backend);
      await tapText(tester, 'My orders');
      await tester.tap(find.textContaining('AL-').first);
      await tester.pumpAndSettle();

      // Before the shop sends anything: told what happens next.
      expect(
        find.textContaining('Alpha LPG will send the Easypaisa account'),
        findsOneWidget,
      );

      await tester.runAsync(
        () => backend.orders.sendPaymentRequest(
          id,
          const PaymentRequest(
            method: PaymentMethod.easyPaisa,
            account: '03001234567',
            accountTitle: 'Alpha LPG',
            amount: 1826,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      // The order page only points to the payment screen.
      expect(find.textContaining('Payment details are ready'), findsOneWidget);
      expect(find.text('Alpha LPG sent you payment details'), findsNothing);
      await tapText(tester, 'Pay now');
      expect(find.text('Payment'), findsWidgets);
      expect(find.text('Alpha LPG sent you payment details'), findsOneWidget);
      expect(find.text('03001234567'), findsOneWidget);

      // The "I have paid" sheet will not send without the screenshot.
      await tapText(tester, 'I have paid: send details');
      expect(
        find.text('1. Screenshot of the payment (required)'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Transaction ID (required)'),
        'EP123456',
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(
        FilledButton,
        'Add the payment screenshot',
      );
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      // What the sheet sends once complete reaches the shop.
      await tester.runAsync(
        () => backend.orders.submitPayment(
          id,
          uid: 'u',
          reference: 'EP123456',
          amount: 1826,
          data: 'x' * 200,
        ),
      );
      final o = await tester.runAsync(
        () => backend.orders.watchOrder(id).first,
      );
      expect(o!.paymentReference, 'EP123456');
      expect(o.paidAmount, 1826);
      expect(o.receiptAt, isNotNull);
      final receipts = await tester.runAsync(
        () => backend.orders.watchReceipts(id).first,
      );
      expect(receipts!, hasLength(1));
    },
  );

  testWidgets('a problem report goes straight to the shop, not the chat', (
    tester,
  ) async {
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
      await backend.orders.updateStatus(id, OrderStatus.confirmed, 'boss');
    });
    await pumpApp(tester, backend);
    await tapText(tester, 'My orders');
    await tester.tap(find.textContaining('AL-').first);
    await tester.pumpAndSettle();
    await tapText(tester, 'Something wrong with this order?');
    await tapText(tester, 'Cylinder leaking or damaged');
    await tapText(tester, 'Send to Alpha LPG');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final reports = await tester.runAsync(
      () => backend.orders.watchReports().first,
    );
    expect(reports!.single.reason, 'Cylinder leaking or damaged');
    expect(reports.single.orderId, id);
    final chat = await tester.runAsync(
      () => backend.orders.watchMessages(id).first,
    );
    expect(chat, isEmpty);
  });

  test('area fee and low stock helpers', () {
    final s = AppSettings.fromMap({
      'deliveryFee': 150,
      'areaFees': {'DHA': 250},
    });
    expect(s.feeForArea(' dha '), 250);
    expect(s.feeForArea('Gulberg'), 150);
    expect(
      PriceBreakdown.of(const [], s, area: 'DHA').deliveryFee,
      0, // empty cart is free
    );
    const p = Product(id: 'a', name: 'x', sizeKg: 6, refillPrice: 1, stock: 3);
    expect(p.lowStock, 3);
    expect(
      const Product(
        id: 'a',
        name: 'x',
        sizeKg: 6,
        refillPrice: 1,
        stock: 50,
      ).lowStock,
      isNull,
    );
    expect(
      const Product(id: 'a', name: 'x', sizeKg: 6, refillPrice: 1).lowStock,
      isNull,
    );
  });
}
