import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('home shows the Alpha LPG catalogue with website prices', (
    tester,
  ) async {
    await pumpApp(tester, testBackend());
    expect(find.text('6kg Gas Cylinder'), findsOneWidget);
    expect(find.text('Rs. 1,676'), findsOneWidget);
    expect(find.text('Rs. 3,296', skipOffstage: false), findsOneWidget);
    expect(find.text('Rs. 12,682', skipOffstage: false), findsOneWidget);
    expect(find.text('Need LPG today?'), findsOneWidget);
  });

  testWidgets('guest → cart → sign in → profile → address → order → track', (
    tester,
  ) async {
    final backend = testBackend();
    await pumpApp(tester, backend);

    // Add two 11.8kg cylinders from the product sheet.
    await tapText(tester, '11.8kg Gas Cylinder');
    await tester.tap(find.byTooltip('Increase'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Add · Rs. 6,592');
    expect(find.text('2 cylinders · Rs. 6,592'), findsOneWidget);

    // Cart: free delivery above Rs. 6,000, refill reminder, swipe-to-remove.
    await tapText(tester, 'View cart');
    expect(find.text('You get FREE delivery on this order'), findsOneWidget);
    expect(find.text('FREE', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('keep 2 empty cylinders'), findsOneWidget);
    await tapText(tester, 'Checkout');

    // Checkout requires sign-in.
    expect(find.text('Sign in with your mobile'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '0300 1234567');
    await tapText(tester, 'Send code');
    expect(find.textContaining('0300 1234567'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '000000');
    await tapText(tester, 'Verify & continue');
    expect(find.textContaining('Incorrect code'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tapText(tester, 'Verify & continue');

    // First sign-in → 3-step setup.
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('0300 1234567 verified'), findsOneWidget);
    await tapText(tester, 'Continue');
    expect(find.text('Please enter your name'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Bilal Ahmed',
    );
    await tapText(tester, 'Continue');

    expect(find.text('Step 2 of 3'), findsOneWidget);
    await tapText(tester, 'My business');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Business name'),
      'Lahore Grill',
    );
    await tapText(tester, 'Continue');

    expect(find.text('Step 3 of 3'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'House / shop no., street, block'),
      'Shop 3, MM Alam Road',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Area / society'),
      'Gulb',
    );
    await tester.pumpAndSettle();
    // Typing filters the Lahore area shortcuts; tap the match.
    await tester.tap(find.widgetWithText(ActionChip, 'Gulberg'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Save & finish');

    // Straight back to checkout, cart intact, new address selected.
    expect(find.text('Checkout'), findsOneWidget);
    expect(
      find.textContaining('Shop 3, MM Alam Road, Gulberg'),
      findsOneWidget,
    );
    expect(find.textContaining('Bilal Ahmed'), findsOneWidget);

    // Pay by JazzCash with a transaction ID.
    await tapText(tester, 'JazzCash');
    expect(find.text('Send Rs. 6,592 via JazzCash'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Transaction ID (optional)'),
      'TX12345',
    );
    await tapText(tester, 'Place order');
    expect(find.text('Order placed!'), findsOneWidget);
    expect(find.text('Transaction ID TX12345'), findsOneWidget);
    expect(find.text('Keep 2 empty cylinders ready'), findsOneWidget);

    // The stored order is shown on the tracking screen.
    await tapText(tester, 'Track my order');
    expect(find.text('We have received your order'), findsOneWidget);
    expect(find.text('Rs. 6,592'), findsWidgets);
    expect(find.text('FREE'), findsOneWidget);
    await scrollTo(tester, find.text('AWAITING PAYMENT'));
    expect(find.text('Transaction ID: TX12345'), findsOneWidget);
    await scrollTo(tester, find.text('Cancel order'));
    expect(find.text('Cancel order'), findsOneWidget);
  });

  testWidgets('customer can cancel a placed order with a reason', (
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
    });
    await pumpApp(tester, backend);
    await tapText(tester, 'My orders');
    expect(find.text('Rs. 1,826'), findsOneWidget);
    await tapText(tester, '1× 6kg Gas Cylinder');
    await tapText(tester, 'Cancel order');
    await tapText(tester, 'Need a different size');
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel order'));
    await tester.pumpAndSettle();
    expect(
      find.text('Reason: Need a different size', skipOffstage: false),
      findsOneWidget,
    );
    final cancelled = await tester.runAsync(
      () => backend.orders.watchOrder(id).first,
    );
    expect(cancelled!.status, OrderStatus.cancelled);
  });

  testWidgets('tracking screen follows status changes live', (tester) async {
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
              productId: 'cyl-45-4kg',
              name: '45.4kg Gas Cylinder',
              sizeKg: 45.4,
              type: PurchaseType.refill,
              unitPrice: 12682,
              quantity: 1,
            ),
          ],
          subtotal: 12682,
          deliveryFee: 0,
          total: 12682,
          address: const Address(
            label: 'Restaurant',
            line1: '5',
            area: 'Gulberg',
          ),
        ),
      );
    });
    await pumpApp(tester, backend);
    await tapText(tester, 'My orders');
    await tapText(tester, '1× 45.4kg Gas Cylinder');
    expect(find.text('We have received your order'), findsOneWidget);

    await tester.runAsync(
      () => backend.orders.assignRider(
        id,
        'admin',
        riderId: 'r1',
        name: 'Imran',
        phone: '03001112222',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Imran'), findsOneWidget);
    expect(find.byTooltip('Call rider'), findsOneWidget);
  });
}
