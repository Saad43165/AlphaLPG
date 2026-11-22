import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_customer/state/cart.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

/// Walks the main screens at a large font size in dark mode and fails on any
/// overflow, so cut-off text is caught before it reaches a phone.
void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets(
        'customer screens: ${dark ? 'dark' : 'light'}, text x$scale',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          addTearDown(tester.platformDispatcher.clearAllTestValues);

          final backend = testBackend();
          late String id;
          await tester.runAsync(() async {
            await backend.auth.sendCode('+923001234567');
            await backend.auth.verifyCode('123456');
            await backend.profiles.saveAddress(
              backend.auth.uid!,
              const Address(
                label: 'Home',
                line1: 'House 12, Street 4, Block C, Gulberg III',
                area: 'Gulberg',
                lat: 31.51,
                lng: 74.34,
              ),
            );
            await backend.profiles.saveProfile(
              CustomerProfile(
                uid: backend.auth.uid!,
                name: 'Saad Ikram',
                phone: '+923001234567',
              ),
              isNew: true,
            );
            id = await backend.orders.place(
              LpgOrder(
                customerId: backend.auth.uid!,
                customerName: 'Saad Ikram',
                customerPhone: '+923001234567',
                items: const [
                  OrderItem(
                    productId: 'cyl-10kg',
                    name: '10kg Composite Cylinder',
                    sizeKg: 10,
                    type: PurchaseType.refill,
                    unitPrice: 2793,
                    quantity: 2,
                  ),
                  OrderItem(
                    productId: 'cyl-11-8kg',
                    name: '11.8kg Gas Cylinder',
                    sizeKg: 11.8,
                    type: PurchaseType.refill,
                    unitPrice: 3296,
                    quantity: 1,
                  ),
                ],
                subtotal: 8882,
                deliveryFee: 0,
                total: 8882,
                address: const Address(
                  label: 'Home',
                  line1: 'House 12, Street 4, Block C, Gulberg III',
                  area: 'Gulberg',
                ),
                paymentMethod: PaymentMethod.jazzCash,
              ),
            );
            await backend.orders.sendPaymentRequest(
              id,
              const PaymentRequest(
                method: PaymentMethod.jazzCash,
                account: '03001234567',
                accountTitle: 'Alpha LPG Gas Services',
                note: 'Please send the exact amount',
                amount: 8882,
              ),
            );
          });
          await pumpApp(tester, backend);
          expect(tester.takeException(), isNull, reason: 'home');

          Provider.of<Cart>(
              tester.element(find.byType(Navigator).first),
              listen: false,
            )
            ..add('cyl-6kg', PurchaseType.refill, 3)
            ..add('cyl-10kg', PurchaseType.newCylinder, 2);
          await tester.pumpAndSettle();
          final router = GoRouter.of(
            tester.element(find.byType(Navigator).first),
          );
          for (final route in [
            '/orders',
            '/order-placed/$id',
            '/orders/$id',
            '/orders/$id/payment',
            '/orders/$id/chat',
            '/account',
            '/cart',
            '/rewards',
            '/support',
          ]) {
            router.go(route);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: route);
          }
        },
      );
    }
  }
}
