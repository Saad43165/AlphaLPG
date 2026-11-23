import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:alpha_customer/screens/info/safety_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('first launch shows the welcome slides, then home', (
    tester,
  ) async {
    await pumpApp(tester, testBackend(), showOnboarding: true);
    expect(find.text('LPG for every kitchen in Lahore'), findsOneWidget);
    await tapText(tester, 'Next');
    expect(find.text('Delivered to your door'), findsOneWidget);
    await tapText(tester, 'Next');
    expect(find.text('Checked before it leaves'), findsOneWidget);
    await tapText(tester, 'Get started');
    expect(find.text('Need LPG today?'), findsOneWidget);
  });

  testWidgets('safety guide follows the Alpha LPG poster', (tester) async {
    await pumpApp(tester, testBackend());
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Safety guide');
    expect(find.text('Use LPG safely.'), findsOneWidget);
    expect(find.text('Smell gas? Know what to do.'), findsOneWidget);
    expect(find.text('1. Turn off the gas supply'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text("Don't"),
      300,
      scrollable: find
          .descendant(
            of: find.byType(SafetyScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tapText(tester, "Don't");
    expect(
      find.text("Don't use a flame to check for leaks", skipOffstage: false),
      findsOneWidget,
    );
    await tapText(tester, 'View the full safety poster');
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('help and about pages open from the account tab', (tester) async {
    await pumpApp(tester, testBackend());
    await tapText(tester, 'Account');
    await tapText(tester, 'Help & FAQs');
    await tapText(tester, 'How much is delivery?');
    expect(
      find.textContaining('free on orders over Rs. 6,000'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapText(tester, 'About Alpha LPG');
    expect(
      find.text('Reliable LPG for homes and businesses across Lahore.'),
      findsOneWidget,
    );
  });

  testWidgets('customer can rate a delivered order', (tester) async {
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
          address: const Address(label: 'Home', line1: '1', area: 'DHA'),
        ),
      );
      await backend.orders.updateStatus(id, OrderStatus.delivered, 'r1');
    });
    await pumpApp(tester, backend);
    // Home offers a one-tap "Order again" for the delivered order.
    expect(find.text('Order again'), findsOneWidget);

    await tapText(tester, 'My orders');
    await tester.tap(find.textContaining('AL-').first);
    await tester.pumpAndSettle();
    expect(find.text('How was your delivery?'), findsOneWidget);
    await tester.tap(find.byTooltip('5 stars'));
    await tester.pumpAndSettle();
    expect(find.text('Excellent!'), findsOneWidget);
    await tapText(tester, 'Submit rating');
    expect(
      find.text('Thanks for rating this delivery', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('How was your delivery?', skipOffstage: false),
      findsNothing,
    );
  });
}
