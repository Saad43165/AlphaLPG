import 'package:alpha_ui/alpha_ui.dart' show AppPalette;
import 'package:alpha_customer/widgets/skeleton.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('skeleton placeholders build and shimmer without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    for (final w in const [
      ProductGridSkeleton(),
      OrderListSkeleton(),
      DetailSkeleton(),
      LinesSkeleton(),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AppPalette.light]),
          home: Scaffold(body: w),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('home shows stoves and accessories under their own filter', (
    tester,
  ) async {
    await pumpApp(tester, testBackend());
    expect(find.text('What do you need?'), findsOneWidget);
    await tapText(tester, 'Stoves & accessories');
    expect(find.text('Germania Single Burner Stove'), findsOneWidget);
    expect(find.text('11.8kg Gas Cylinder'), findsNothing);

    await tapText(tester, 'Germania Single Burner Stove');
    // Accessories have one price: no refill / new cylinder choice.
    expect(find.text('New cylinder'), findsNothing);
    expect(find.textContaining('empty'), findsNothing);
  });
}
