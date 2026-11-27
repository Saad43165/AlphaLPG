import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_customer/state/cart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'extras_test.dart' show signedInBackend;
import 'helpers.dart';

void main() {
  testWidgets('one checkout page: rows, pay-first panel, place the order', (
    tester,
  ) async {
    final backend = await signedInBackend(tester);
    await tester.runAsync(() async {
      await backend.catalog.saveSettings(
        AppSettings.fromMap({
          ...SeedData.settings.toMap(),
          'loginMode': 'sms',
          'jazzCashAccount': '0300 1234567 · JUNAID Shop',
        }),
      );
    });
    await pumpApp(tester, backend);
    Provider.of<Cart>(
      tester.element(find.byType(Navigator).first),
      listen: false,
    ).add('cyl-11-8kg', PurchaseType.refill);
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/checkout');
    await tester.pumpAndSettle();

    // Delivery, time and payment are on the same page as the slide.
    expect(find.text('Deliver to Home'), findsOneWidget);
    expect(find.text('As soon as possible'), findsOneWidget);
    expect(find.text('Slide to place order'), findsOneWidget);

    // Online payment shows the shop's account right here, with Copy.
    await openPaymentChoices(tester);
    await tapText(tester, 'JazzCash');
    expect(find.text('0300 1234567 · JUNAID Shop'), findsOneWidget);
    expect(find.text('Copy'), findsNWidgets(2));
    expect(find.text('Add payment screenshot'), findsOneWidget);

    // It can still be placed without proof (pay later from the order).
    await slideToOrder(tester);
    expect(find.text('Order placed!'), findsOneWidget);
  });
}
