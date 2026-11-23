import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_customer/l10n/lang.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  for (final urdu in [false, true]) {
    testWidgets('long accessory names fit everywhere (urdu: $urdu)', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      Lang.set(urdu);
      addTearDown(() => Lang.set(false));
      final backend = testBackend();
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
        await backend.orders.place(
          LpgOrder(
            customerId: backend.auth.uid!,
            customerName: 'Sara',
            customerPhone: '+923001234567',
            items: [
              for (final n in const [
                'Indus 2-Burner Glass Top Stove',
                'Eurogas LPG Regulator 22mm',
                'Germania Single Burner Stove',
              ])
                OrderItem(
                  productId: 'x',
                  name: n,
                  sizeKg: 0,
                  type: PurchaseType.refill,
                  unitPrice: 1000,
                  quantity: 17,
                ),
            ],
            subtotal: 51000,
            deliveryFee: 0,
            total: 51000,
            address: const Address(label: 'Home', line1: '1', area: 'DHA'),
            paymentMethod: PaymentMethod.easyPaisa,
          ),
        );
      });
      await pumpApp(tester, backend);
      await tapText(tester, urdu ? 'میرے آرڈر' : 'My orders');
      expect(tester.takeException(), isNull, reason: 'orders list');
      await tester.tap(find.textContaining('AL-').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'order detail');
    });
  }
}
