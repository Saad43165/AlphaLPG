import 'app_settings.dart';

enum OrderingState { open, paused, closedHours, noRiders }

/// Whether the shop is taking orders right now, and what to tell customers.
/// Worked out from the owner's settings and the number of live riders.
class OrderingStatus {
  const OrderingStatus(this.state, this.headline, this.message);

  final OrderingState state;
  final String headline;
  final String message;

  bool get canOrder => state == OrderingState.open;

  static String clock(int minutes) {
    final h24 = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    final h = h24 % 12 == 0 ? 12 : h24 % 12;
    final mm = m == 0 ? '' : ':${m.toString().padLeft(2, '0')}';
    return '$h$mm ${h24 >= 12 ? 'pm' : 'am'}';
  }

  /// True when [now] falls inside the opening window (handles windows that
  /// run past midnight).
  static bool withinHours(AppSettings s, DateTime now) {
    final t = now.hour * 60 + now.minute;
    return s.opensAt <= s.closesAt
        ? t >= s.opensAt && t < s.closesAt
        : t >= s.opensAt || t < s.closesAt;
  }

  /// [liveRiders] null means "not known (yet)": riders are then not used to
  /// block orders.
  static OrderingStatus of(
    AppSettings s, {
    DateTime? now,
    int? liveRiders,
  }) {
    final t = now ?? DateTime.now();
    if (!s.acceptingOrders) {
      return OrderingStatus(
        OrderingState.paused,
        'Not taking orders right now',
        s.closedMessage.isNotEmpty
            ? s.closedMessage
            : 'Alpha LPG has paused online orders. Please call or WhatsApp us.',
      );
    }
    if (s.autoHours && !withinHours(s, t)) {
      return OrderingStatus(
        OrderingState.closedHours,
        'We are closed',
        'Online orders open at ${clock(s.opensAt)}. You can still browse and prepare your cart.',
      );
    }
    if (s.pauseWhenNoRiders && liveRiders != null && liveRiders == 0) {
      return const OrderingStatus(
        OrderingState.noRiders,
        'Our riders are offline',
        'No rider is on shift right now, so we cannot deliver yet. Please try again shortly or call us.',
      );
    }
    return OrderingStatus(
      OrderingState.open,
      'Open for orders',
      s.autoHours ? 'Delivering until ${clock(s.closesAt)}' : 'Delivering today',
    );
  }
}
