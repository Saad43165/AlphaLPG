import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_customer/state/cart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

void main() {
  testWidgets('bulk order starts from the cart and reaches the shop', (
    tester,
  ) async {
    final backend = testBackend();
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
    });
    await pumpApp(tester, backend);
    final ctx = tester.element(find.byType(Navigator).first);
    Provider.of<Cart>(ctx, listen: false)
      ..add('cyl-11-8kg', PurchaseType.refill, 12)
      ..add('cyl-45-4kg', PurchaseType.refill, 3);
    GoRouter.of(ctx).go('/bulk-quote');
    await tester.pumpAndSettle();

    // The cart quantities are already filled in.
    expect(find.text('Send request · 15 cylinders'), findsOneWidget);
    expect(find.textContaining('Total: 15 cylinders'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Area in Lahore'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.ancestor(
        of: find.text('Area in Lahore'),
        matching: find.byType(TextFormField),
      ),
      'Gulberg',
    );
    await tester.ensureVisible(find.text('Every week'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every week'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send request · 15 cylinders'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Request sent'), findsOneWidget);
    final all = await tester.runAsync(() => backend.quotes.watchAll().first);
    expect(all!, hasLength(1));
    expect(all.single.preferredSize, '15 cylinders');
    expect(all.single.notes, contains('12× 11.8kg Gas Cylinder'));
    expect(all.single.notes, contains('Every week'));
    expect(all.single.monthlyKg, greaterThan(0));

    // The shop answers inside the app: the customer sees it, with the status.
    await tester.runAsync(
      () => backend.quotes.sendReply(
        all.single.id,
        'Rate: Rs 9,800 per cylinder',
      ),
    );
    GoRouter.of(ctx).go('/');
    await tester.pumpAndSettle();
    GoRouter.of(ctx).go('/bulk-quote');
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Rs 9,800'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Alpha LPG replied'), findsWidgets);
    expect(find.textContaining('Rs 9,800'), findsOneWidget);
  });
}
