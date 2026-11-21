import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

/// Guest adds a cylinder, opens the cart and taps Checkout → login screen.
Future<void> guestToLogin(WidgetTester tester) async {
  final add = find.byTooltip('Add 11.8kg Gas Cylinder');
  await tester.ensureVisible(add);
  await tester.pumpAndSettle();
  await tester.tap(add);
  await tester.pumpAndSettle();
  await tapText(tester, 'View cart');
  await tapText(tester, 'Checkout');
  expect(find.text('Sign in with your mobile'), findsOneWidget);
}

Future<void> signIn(WidgetTester tester, String phone) async {
  await tester.enterText(find.byType(TextField), phone);
  await tapText(tester, 'Send code');
  await tester.enterText(find.byType(TextField), '123456');
  await tapText(tester, 'Verify & continue');
}

void expectOnHome() => expect(
  find.textContaining(
    RegExp('need LPG today', caseSensitive: false),
    skipOffstage: false,
  ),
  findsOneWidget,
);

void main() {
  testWidgets(
    'guest closes the login screen → back on the cart, with a way back',
    (tester) async {
      await pumpApp(tester, testBackend());
      await guestToLogin(tester);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your cart'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expectOnHome();
      expect(
        find.text('1 cylinder · Rs. 3,296'),
        findsOneWidget,
        reason: 'cart is kept',
      );
    },
  );

  testWidgets(
    'returning customer signs in → checkout, and Back leads cart → home',
    (tester) async {
      final backend = testBackend();
      await tester.runAsync(
        () => backend.profiles.saveProfile(
          const CustomerProfile(
            uid: 'demo-234567',
            name: 'Sara Khan',
            phone: '+923001234567',
          ),
          isNew: true,
        ),
      );
      await pumpApp(tester, backend);
      await guestToLogin(tester);
      await signIn(tester, '0300 1234567');
      expect(find.text('Checkout'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your cart'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expectOnHome();
    },
  );

  testWidgets(
    'new customer finishes setup → checkout, and Back is never a dead end',
    (tester) async {
      await pumpApp(tester, testBackend());
      await guestToLogin(tester);
      await signIn(tester, '0311 7654321');
      expect(find.text('Step 1 of 3'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'Ali Raza',
      );
      await tapText(tester, 'Continue');
      await tapText(tester, 'Continue');
      await tapText(tester, 'Use my current location');
      await tapText(tester, 'Confirm location');
      await tapText(tester, 'Save & finish');
      expect(find.text('Checkout'), findsOneWidget);
      // This used to be the only screen in the stack: no back arrow, app stuck.
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your cart'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expectOnHome();
    },
  );

  testWidgets('a newcomer can cancel setup instead of being trapped', (
    tester,
  ) async {
    await pumpApp(tester, testBackend());
    await guestToLogin(tester);
    await signIn(tester, '0322 1112223');
    expect(find.text('Step 1 of 3'), findsOneWidget);
    await tapText(tester, 'Cancel');
    expect(find.text('Step 1 of 3'), findsNothing);
    expectOnHome();
  });
}
