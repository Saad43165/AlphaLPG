import 'package:alpha_customer/app.dart';
import 'package:alpha_customer/services/backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// In-memory backend without the demo dispatcher (no background timers).
Backend testBackend() => Backend.memory();

Future<void> pumpApp(WidgetTester tester, Backend backend) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AlphaApp(backend: backend));
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
