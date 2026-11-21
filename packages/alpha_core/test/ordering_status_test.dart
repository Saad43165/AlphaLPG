import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final noon = DateTime(2026, 11, 21, 12);
  final late = DateTime(2026, 11, 21, 23, 30);

  test('open by default', () {
    final s = OrderingStatus.of(const AppSettings(), now: noon, liveRiders: 3);
    expect(s.canOrder, isTrue);
  });

  test('the owner can pause orders, with their own message', () {
    final s = OrderingStatus.of(
      const AppSettings(acceptingOrders: false, closedMessage: 'Back tomorrow'),
      now: noon,
    );
    expect(s.state, OrderingState.paused);
    expect(s.message, 'Back tomorrow');
    expect(s.canOrder, isFalse);
  });

  test('opening hours: closed outside the window, with the opening time', () {
    const s = AppSettings(autoHours: true, opensAt: 540, closesAt: 1260);
    expect(OrderingStatus.of(s, now: noon).canOrder, isTrue);
    final closed = OrderingStatus.of(s, now: late);
    expect(closed.state, OrderingState.closedHours);
    expect(closed.message, contains('9 am'));
    expect(
      OrderingStatus.of(s, now: DateTime(2026, 11, 21, 8, 59)).canOrder,
      isFalse,
    );
    expect(
      OrderingStatus.of(s, now: DateTime(2026, 11, 21, 21, 0)).canOrder,
      isFalse,
    );
  });

  test('a window past midnight works', () {
    const s = AppSettings(autoHours: true, opensAt: 1200, closesAt: 120);
    expect(OrderingStatus.of(s, now: late).canOrder, isTrue);
    expect(
      OrderingStatus.of(s, now: DateTime(2026, 11, 22, 1)).canOrder,
      isTrue,
    );
    expect(OrderingStatus.of(s, now: noon).canOrder, isFalse);
  });

  test('no live riders pauses orders only when the owner asked for it', () {
    expect(
      OrderingStatus.of(const AppSettings(), now: noon, liveRiders: 0).canOrder,
      isTrue,
    );
    final s = OrderingStatus.of(
      const AppSettings(pauseWhenNoRiders: true),
      now: noon,
      liveRiders: 0,
    );
    expect(s.state, OrderingState.noRiders);
    // Unknown rider count never blocks.
    expect(
      OrderingStatus.of(
        const AppSettings(pauseWhenNoRiders: true),
        now: noon,
      ).canOrder,
      isTrue,
    );
  });

  test('clock text', () {
    expect(OrderingStatus.clock(540), '9 am');
    expect(OrderingStatus.clock(1260), '9 pm');
    expect(OrderingStatus.clock(0), '12 am');
    expect(OrderingStatus.clock(750), '12:30 pm');
  });

  test('the cart problem text comes from the status', () {
    final price = PriceBreakdown.of(const [], const AppSettings());
    final s = OrderingStatus.of(
      const AppSettings(acceptingOrders: false),
      now: noon,
    );
    expect(price.problem(const AppSettings(), status: s), s.message);
  });
}
