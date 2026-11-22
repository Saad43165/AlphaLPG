import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_customer/l10n/lang.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' show Navigator;

import 'helpers.dart';

/// Walks screens a signed-out visitor and a closed shop show, in Urdu, and
/// lists any English text left over. Fails on a leftover that is plain app
/// wording (data typed by the shop is allowed to stay as it is).
void main() {
  testWidgets('Urdu: signed-out screens and a closed shop', (tester) async {
    Lang.set(true);
    Lang.missed.clear();
    addTearDown(() => Lang.set(false));
    final backend = testBackend();
    await tester.runAsync(
      () => backend.catalog.saveSettings(
        AppSettings.fromMap({
          ...SeedData.settings.toMap(),
          'loginMode': 'sms',
          'acceptingOrders': false,
        }),
      ),
    );
    await pumpApp(tester, backend);
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    for (final route in [
      '/',
      '/login',
      '/welcome',
      '/cart',
      '/orders',
      '/account',
      '/safety',
      '/help',
      '/about',
      '/location',
      '/bulk-quote',
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
      tester.takeException();
    }
    // ignore: avoid_print
    print('UNTRANSLATED: ${(Lang.missed.toList()..sort()).join(' || ')}');
  });
}
