import 'package:alpha_customer/l10n/lang.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' show Navigator;

import 'helpers.dart';

void main() {
  testWidgets('switching to Urdu and back leaves no Urdu behind', (
    tester,
  ) async {
    addTearDown(() => Lang.set(false));
    final backend = testBackend();
    await pumpApp(tester, backend);
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    router.go('/settings');
    await tester.pumpAndSettle();
    expect(find.text('APPEARANCE'), findsOneWidget);

    await tester.tap(find.text('اردو'));
    await tester.pumpAndSettle();
    expect(find.text('ظاہری شکل'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsNothing);

    // A screen that was already built before the switch changes too.
    router.go('/cart');
    await tester.pumpAndSettle();
    expect(find.text('آپ کا کارٹ خالی ہے'), findsWidgets);

    router.go('/settings');
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('ظاہری شکل'), findsNothing);
    router.go('/cart');
    await tester.pumpAndSettle();
    expect(find.text('Your cart is empty'), findsWidgets);
    expect(find.text('آپ کا کارٹ خالی ہے'), findsNothing);
  });
}
