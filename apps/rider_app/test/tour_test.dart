import 'package:alpha_ui/alpha_ui.dart';
import 'package:alpha_rider/screens/tour_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final urdu in [false, true]) {
    testWidgets('first-run tour fits at big text (urdu: $urdu)', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: Brand.theme(Brightness.light),
          builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: w!,
          ),
          home: RiderTour(onDone: () => done++),
        ),
      );
      await tester.pumpAndSettle();
      if (urdu) {
        await tester.tap(find.text('اردو'));
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 4; i++) {
        expect(tester.takeException(), isNull);
        final power = find.byIcon(Icons.power_settings_new_rounded);
        if (power.evaluate().isNotEmpty) {
          await tester.tap(power.last);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(urdu ? 'آگے' : 'Next'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(urdu ? 'شروع کریں' : 'Get started'));
      expect(done, 1);
    });
  }
}
