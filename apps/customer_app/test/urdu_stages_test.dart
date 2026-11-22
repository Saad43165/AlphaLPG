import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:alpha_customer/l10n/lang.dart';

import 'helpers.dart';

/// Walks the main screens at a large font size in dark mode and fails on any
/// overflow, so cut-off text is caught before it reaches a phone.
void main() {
  testWidgets('Urdu: every order stage', (tester) async {
    Lang.set(true);
    Lang.missed.clear();
    addTearDown(() => Lang.set(false));
    final backend = testBackend();
    late String id;
    await tester.runAsync(() async {
      await backend.auth.sendCode('+923001234567');
      await backend.auth.verifyCode('123456');
      await backend.profiles.saveProfile(
        CustomerProfile(
          uid: backend.auth.uid!,
          name: 'Bilal',
          phone: '+923001234567',
        ),
        isNew: true,
      );
      id = await backend.orders.place(
        LpgOrder(
          customerId: backend.auth.uid!,
          customerName: 'Bilal',
          customerPhone: '+923001234567',
          items: const [
            OrderItem(
              productId: 'cyl-11-8kg',
              name: '11.8kg Gas Cylinder',
              sizeKg: 11.8,
              type: PurchaseType.refill,
              unitPrice: 3296,
              quantity: 2,
            ),
          ],
          subtotal: 6592,
          deliveryFee: 150,
          total: 6742,
          address: const Address(
            label: 'Home',
            line1: 'House 12, Gulberg III',
            area: 'Gulberg',
          ),
          paymentMethod: PaymentMethod.cashOnDelivery,
        ),
      );
    });
    await pumpApp(tester, backend);
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    Future<void> visit() async {
      for (final r in ['/orders/$id', '/order-placed/$id', '/orders']) {
        router.go(r);
        await tester.pumpAndSettle();
        tester.takeException();
      }
    }

    await visit();
    await tester.runAsync(() async {
      await backend.orders.updateStatus(id, OrderStatus.confirmed, 'admin');
      await backend.orders.assignRider(
        id,
        'admin',
        riderId: 'r1',
        name: 'Imran Khan',
        phone: '+923009998877',
      );
    });
    await visit();
    await tester.runAsync(
      () => backend.orders.updateStatus(id, OrderStatus.outForDelivery, 'r1'),
    );
    await visit();
    await tester.runAsync(
      () => backend.orders.updateStatus(id, OrderStatus.delivered, 'r1'),
    );
    await visit();
    // ignore: avoid_print
    print('UNTRANSLATED: ${(Lang.missed.toList()..sort()).join(' || ')}');
  });
}
