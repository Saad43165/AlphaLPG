import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('shows a bar after two failed checks, hides when back', (
    t,
  ) async {
    var online = false;
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: OfflineBanner(
            probe: () async => online,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.textContaining('No internet'), findsNothing);
    await t.pump(const Duration(seconds: 6));
    expect(find.textContaining('No internet'), findsOneWidget);
    online = true;
    await t.pump(const Duration(seconds: 6));
    expect(find.textContaining('No internet'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
}
