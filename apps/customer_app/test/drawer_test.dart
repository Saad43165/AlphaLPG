import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Offset;

import 'helpers.dart';

void main() {
  testWidgets('the menu opens from the button and from the edge, and closes', (
    tester,
  ) async {
    await pumpApp(tester, testBackend());
    final title = find.text('Need LPG today?');
    final home = tester.getTopLeft(title).dx;

    // The screen slides to the right while the menu is open.
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(title).dx, greaterThan(home + 150));

    // Tapping the screen closes it.
    await tester.tapAt(const Offset(395, 600));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(title).dx, closeTo(home, 1));

    // A swipe in from the left edge opens it too.
    await tester.dragFrom(const Offset(4, 600), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(title).dx, greaterThan(home + 150));

    // Swiping it back closes it.
    await tester.dragFrom(const Offset(390, 600), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(title).dx, closeTo(home, 1));
  });
}
