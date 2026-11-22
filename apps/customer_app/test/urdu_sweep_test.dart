import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_customer/state/cart.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:alpha_customer/l10n/lang.dart';

import 'helpers.dart';

/// Walks the main screens at a large font size in dark mode and fails on any
/// overflow, so cut-off text is caught before it reaches a phone.
void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets(
        'URDU customer screens: ${dark ? 'dark' : 'light'}, text x$scale',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          addTearDown(tester.platformDispatcher.clearAllTestValues);

          final details = <String>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (d) {
            details.add(d.toString());
            prevOnError?.call(d);
          };
          addTearDown(() => FlutterError.onError = prevOnError);
          Lang.set(true);
          addTearDown(() => Lang.set(false));
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
          final problems = <String>[];
          for (final route in [
            '/orders',
            '/order-placed/$id',
            '/orders/$id',
            '/orders/$id/payment',
            '/orders/$id/chat',
            '/account',
            '/cart',
            '/rewards',
            '/guide',
            '/support',
            '/checkout',
            '/settings',
            '/about',
            '/help',
            '/privacy',
            '/terms',
            '/safety',
            '/bulk-quote',
            '/account/addresses',
            '/account/edit',
          ]) {
            router.go(route);
            await tester.pumpAndSettle();
            final ex = tester.takeException();
            if (ex != null) {
              final d = (ex is FlutterError ? ex.toStringDeep() : '$ex')
                  .split('\n')
                  .where(
                    (l) =>
                        l.contains('relevant') ||
                        l.contains('.dart') ||
                        l.contains('overflowed'),
                  )
                  .take(6)
                  .join(' | ');
              problems.add('$route: $d');
              final lines = details.isEmpty
                  ? <String>[]
                  : details.last
                        .split('\n')
                        .where(
                          (l) =>
                              l.contains('relevant') ||
                              l.contains('creator') ||
                              l.contains('file:///home'),
                        )
                        .take(5)
                        .toList();
              problems.add('   -> ${lines.join(' | ')}');
              details.clear();
            }
          }
          // A finished order has its own receipt-style page.
          await tester.runAsync(
            () =>
                backend.orders.updateStatus(id, OrderStatus.delivered, 'admin'),
          );
          for (final route in ['/orders/$id', '/orders', '/order-placed/$id']) {
            router.go(route);
            await tester.pumpAndSettle();
            final ex = tester.takeException();
            if (ex != null) {
              problems.add(
                'delivered $route: ${details.where((d) => d.contains('relevant')).map((d) => d.split('\n').where((l) => l.contains('overflowed') || l.contains('file:///home')).take(3).join(' | ')).join(' ## ')}',
              );
              details.clear();
            }
          }
          // ignore: avoid_print
          print('PROBLEMS: ${problems.join('\n')}');
          expect(problems, isEmpty);
          if (!dark && scale == 1.0) {
            // ignore: avoid_print
            print(
              'UNTRANSLATED: ${(Lang.missed.toList()..sort()).join(' || ')}',
            );
          }
        },
      );
    }
  }
}
