import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_customer/app.dart';
import 'package:alpha_customer/services/location_service.dart';
import 'package:alpha_customer/widgets/slide_to_confirm.dart';
import 'package:alpha_customer/services/backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// In-memory backend without the demo dispatcher (no background timers).
/// A demo backend using the SMS-code sign-in (most flows are tested with it).
Backend testBackend({bool quickLogin = false}) {
  final b = Backend.memory();
  if (!quickLogin) {
    b.catalog.saveSettings(
      AppSettings.fromMap({...SeedData.settings.toMap(), 'loginMode': 'sms'}),
    );
  }
  return b;
}

Future<void> pumpApp(
  WidgetTester tester,
  Backend backend, {
  bool showOnboarding = false,
  LocationService? location,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  // No looping animations in tests (also what "remove animations" does).
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(
    AlphaApp(
      backend: backend,
      showOnboarding: showOnboarding,
      location: location ?? FakeLocationService(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  var f = find.text(text);
  if (f.evaluate().isEmpty) f = find.text(text, skipOffstage: false);
  f = f.last;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Scrolls the visible vertical list until [finder] is built and on screen.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .hitTestable()
        .first,
  );
  await tester.pumpAndSettle();
}

/// Opens the "Pay with" choices on the checkout screen.
Future<void> openPaymentChoices(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('pay-row')));
  await tester.tap(find.byKey(const Key('pay-row')));
  await tester.pumpAndSettle();
}

/// Opens "Have a code or points?" on the checkout screen.
Future<void> openDiscounts(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('discounts-tile')));
  await tester.tap(find.byKey(const Key('discounts-tile')));
  await tester.pumpAndSettle();
}

/// Drags the "slide to order" control all the way across.
Future<void> slideToOrder(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(SlideToConfirm));
  await tester.drag(find.byType(SlideToConfirm), const Offset(700, 0));
  await tester.pumpAndSettle();
}
