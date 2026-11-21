import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget wrap(Widget w) =>
      MaterialApp(theme: Brand.theme(Brightness.light), home: w);

  testWidgets('old build is blocked, new build and no minimum pass', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const UpdateGate(minBuild: 5, currentBuild: 4, child: Text('app'))),
    );
    expect(find.text('Please update the app'), findsOneWidget);
    expect(find.text('app'), findsNothing);
    await tester.pumpWidget(
      wrap(const UpdateGate(minBuild: 5, currentBuild: 5, child: Text('app'))),
    );
    expect(find.text('app'), findsOneWidget);
    await tester.pumpWidget(
      wrap(const UpdateGate(minBuild: 0, currentBuild: 1, child: Text('app'))),
    );
    expect(find.text('app'), findsOneWidget);
  });

  test(
    'error reporter sends each different error once, a few per run',
    () async {
      ErrorReporter.reset();
      final sent = <String>[];
      final old = FlutterError.onError;
      ErrorReporter.install((m, s, v) async => sent.add(m));
      for (final m in ['a', 'a', 'b', 'c', 'd', 'e', 'f', 'g']) {
        FlutterError.onError!(FlutterErrorDetails(exception: Exception(m)));
      }
      await Future<void>.delayed(Duration.zero);
      expect(sent.length, 5);
      expect(sent.toSet().length, 5);
      FlutterError.onError = old;
      ErrorReporter.reset();
    },
  );
}
