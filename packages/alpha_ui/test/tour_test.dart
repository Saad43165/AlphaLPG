import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final slides = [
    TourSlide(
      icon: Icons.power_settings_new_rounded,
      title: const Bi('Go online', 'آن لائن'),
      body: const Bi('Tap it', 'دبائیں'),
      demo: (c, u) => TourToggleDemo(
        urdu: u,
        offTitle: const Bi('Offline', 'آف'),
        onTitle: const Bi('Online', 'آن'),
        offHint: const Bi('off hint', 'a'),
        onHint: const Bi('on hint', 'b'),
      ),
    ),
    TourSlide(
      icon: Icons.local_shipping_rounded,
      title: const Bi('Deliver', 'ڈیلیور'),
      body: const Bi('Steps', 'قدم'),
      demo: (c, u) => TourStepsDemo(
        urdu: u,
        steps: const [
          TourStep(Icons.map_rounded, Bi('Step one', 'ایک'), Bi('Go', 'چلو')),
          TourStep(Icons.check, Bi('Step two', 'دو'), Bi('Finish', 'ختم')),
        ],
      ),
    ),
    TourSlide(
      icon: Icons.tips_and_updates_rounded,
      title: const Bi('Tips', 'ٹپس'),
      body: const Bi('Tiles', 'ٹائل'),
      demo: (c, u) => TourTilesDemo(
        urdu: u,
        tiles: const [
          TourTile(Icons.call, Bi('Call', 'کال'), Bi('Call text', 'کال متن')),
          TourTile(Icons.map, Bi('Map', 'نقشہ'), Bi('Map text', 'نقشہ متن')),
        ],
      ),
    ),
  ];

  testWidgets('tour: try the demos, switch language, finish', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: Brand.theme(Brightness.light),
        home: TourPage(
          appName: const Bi('App', 'ایپ'),
          slides: slides,
          onDone: () => done++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Toggle demo.
    expect(find.text('Offline'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.power_settings_new_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Online'), findsOneWidget);

    // Urdu.
    await tester.tap(find.text('اردو'));
    await tester.pumpAndSettle();
    expect(find.text('آن'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step one'), findsOneWidget);
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(find.text('Step two'), findsOneWidget);
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(find.text('Done! That is all it takes.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Step one'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Call text'), findsOneWidget);
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.text('Map text'), findsOneWidget);

    expect(find.text('Skip'), findsNothing); // last page
    await tester.tap(find.text('Get started'));
    expect(done, 1);
  });

  testWidgets('tour: Skip works and big text does not overflow', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
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
        home: TourPage(
          appName: const Bi('App', 'ایپ'),
          slides: slides,
          onDone: () => done++,
          startInUrdu: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('چھوڑیں'));
    expect(done, 1);
  });
}
