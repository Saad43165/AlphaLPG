import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_customer/screens/splash_screen.dart';
import 'package:alpha_customer/services/location_service.dart';
import 'package:alpha_customer/theme/brand.dart';
import 'package:alpha_customer/widgets/slide_to_confirm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('drawer opens from the home menu and shows the main places', (
    tester,
  ) async {
    await pumpApp(tester, testBackend());
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Alpha LPG'), findsOneWidget);
    for (final t in [
      'Order gas',
      'My orders',
      'Safety guide',
      'Help & FAQs',
      'Settings',
    ]) {
      expect(
        find.descendant(of: find.byType(Drawer), matching: find.text(t)),
        findsOneWidget,
      );
    }
  });

  testWidgets('settings: switching to dark mode changes the whole theme', (
    tester,
  ) async {
    await pumpApp(tester, testBackend());
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.light,
    );
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Settings');
    expect(find.text('Appearance'.toUpperCase()), findsOneWidget);
    await tapText(tester, 'Dark');
    final ctx = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(ctx).brightness, Brightness.dark);
    expect(ctx.pal.isDark, isTrue);
    await tapText(tester, 'Light');
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.light,
    );
  });

  testWidgets(
    'location picker: no GPS permission → clear help, area typed only as a fallback',
    (tester) async {
      final backend = testBackend();
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
      });
      await pumpApp(
        tester,
        backend,
        location: FakeLocationService(
          denied: true,
          place: const ResolvedPlace(line1: 'Canal Road'),
        ),
      );
      debugPrint(
        'PILL ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).take(12).join(' | ')}',
      );
      // Signed in with no saved location: the home pill goes straight to the map.
      await tapText(tester, 'Set delivery location');
      expect(
        find.textContaining('Allow location to find you instantly'),
        findsOneWidget,
      );
      expect(find.text('Canal Road'), findsOneWidget);
      // The geocoder knew the street but not the area, so only then ask for it.
      expect(find.widgetWithText(TextField, 'Area / society'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm location'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Area / society'),
        'Model Town',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm location'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Flat, floor or landmark (optional)'),
        'Near the park',
      );
      await tapText(tester, 'Confirm location');
      // Saved and selected: the pill now shows it.
      expect(find.text('Home · Model Town'), findsOneWidget);
      final saved = await tester.runAsync(
        () => backend.profiles.watchAddresses(backend.auth.uid!).first,
      );
      expect(saved!.single.landmark, 'Near the park');
      expect(saved.single.hasLocation, isTrue);
    },
  );

  testWidgets(
    'slide to confirm only fires after a full slide, and resets on failure',
    (tester) async {
      var calls = 0;
      var ok = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: Brand.theme(Brightness.light),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: SlideToConfirm(
                  label: 'Slide to order',
                  onConfirmed: () async {
                    calls++;
                    return ok;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(calls, 0, reason: 'a short drag must not order');
      await tester.drag(find.byType(SlideToConfirm), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(calls, 1);
      // It failed (ok = false), so the thumb slid back and can be used again.
      ok = true;
      await tester.drag(find.byType(SlideToConfirm), const Offset(400, 0));
      // On success the thumb stays at the end with a spinner while the next
      // screen loads, so it never "settles".
      await tester.pump(const Duration(milliseconds: 600));
      expect(calls, 2);
    },
  );

  testWidgets('splash reveals the app and then finishes', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: Brand.theme(Brightness.light),
        home: SplashScreen(onFinished: () => finished = true),
      ),
    );
    expect(find.text('Safe gas. Delivered.'), findsOneWidget);
    for (var i = 0; i < 40 && !finished; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finished, isTrue);
  });
}
