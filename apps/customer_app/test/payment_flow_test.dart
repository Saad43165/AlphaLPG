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
      await tapText(tester, '1× 6kg Gas Cylinder');

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
      expect(find.text('Alpha LPG sent you payment details'), findsOneWidget);
      expect(find.text('03001234567'), findsOneWidget);

      // The "I have paid" sheet needs a transaction ID and an amount.
      await tapText(tester, 'I have paid: send details');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Send to Alpha LPG'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Transaction ID (required)'),
        'EP123456',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Send to Alpha LPG'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      final o = await tester.runAsync(
        () => backend.orders.watchOrder(id).first,
      );
      expect(o!.paymentReference, 'EP123456');
      expect(o.paidAmount, 1826);
      expect(o.receiptAt, isNotNull);
      final chat = await tester.runAsync(
        () => backend.orders.watchMessages(id).first,
      );
      expect(chat!.single.text, contains('EP123456'));
    },
  );

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
