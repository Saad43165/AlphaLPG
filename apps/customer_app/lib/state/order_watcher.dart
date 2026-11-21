import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';

import '../services/backend.dart';
import 'app_state.dart';

/// Watches the customer's orders and raises phone notifications for what
/// happens: confirmed, rider assigned, on the way, arrived, delivered,
/// payment confirmed, and every message from the rider or the shop.
///
/// While an order is active it also runs a quiet foreground service so
/// Android keeps the app connected in the background.
class OrderWatcher {
  OrderWatcher(this._backend, this._state) {
    _state.addListener(_onState);
    _onState();
  }

  final Backend _backend;
  final AppState _state;

  String? _uid;
  StreamSubscription<List<LpgOrder>>? _orders;
  final _messageSubs = <String, StreamSubscription<List<OrderMessage>>>{};
  final _last = <String, _Seen>{};
  final _messagesSeen = <String, int>{};
  bool _first = true;

  void _onState() {
    final uid = _state.uid;
    if (uid == _uid) return;
    _stop();
    _uid = uid;
    if (uid != null) _start(uid);
  }

  void _start(String uid) {
    _first = true;
    Alerts.init();
    Alerts.askPermission();
    _orders = _backend.orders
        .watchCustomerOrders(uid)
        .listen(_onOrders, onError: (_) {});
  }

  void _onOrders(List<LpgOrder> list) {
    for (final o in list) {
      final now = _Seen(o.status, o.arrivedAt != null, o.paymentStatus);
      final before = _last[o.id];
      if (!_first && before != null) _announce(o, before, now);
      _last[o.id] = now;
    }

    final active = [
      for (final o in list)
        if (o.status.isActive) o,
    ];
    // Unread counts, previews and "Seen" for the chats of active orders.
    _state.chat.follow([for (final o in active) o.id]);
    // One chat subscription per active order.
    for (final o in active) {
      _messageSubs.putIfAbsent(
        o.id,
        () => _backend.orders.watchMessages(o.id).listen((msgs) {
          final seen = _messagesSeen[o.id];
          _messagesSeen[o.id] = msgs.length;
          if (seen == null || msgs.length <= seen) return;
          for (final m in msgs.skip(seen)) {
            if (m.role == MessageRole.customer) continue;
            Alerts.show(
              id: _id(o.id, 2),
              title: m.role == MessageRole.rider
                  ? '${m.name.isEmpty ? 'Your rider' : m.name} (rider)'
                  : 'Alpha LPG',
              body: m.text,
              payload: '/orders/${o.id}/chat',
            );
          }
        }, onError: (_) {}),
      );
    }
    final activeIds = {for (final o in active) o.id};
    for (final id in _messageSubs.keys.toList()) {
      if (!activeIds.contains(id)) _messageSubs.remove(id)?.cancel();
    }

    if (active.isNotEmpty) {
      KeepAlive.start(
        title: 'Alpha LPG order in progress',
        text: 'We will tell you when something changes.',
      );
    } else {
      KeepAlive.stop();
    }
    _first = false;
  }

  void _announce(LpgOrder o, _Seen before, _Seen now) {
    String? title, body;
    if (now.status != before.status) {
      final rider = o.riderName ?? 'Your rider';
      switch (now.status) {
        case OrderStatus.confirmed:
          title = 'Order confirmed';
          body = 'Alpha LPG confirmed order ${o.displayNumber}.';
        case OrderStatus.assigned:
          title = 'Rider assigned';
          body = '$rider will deliver order ${o.displayNumber}.';
        case OrderStatus.outForDelivery:
          title = 'Your gas is on the way';
          body = '$rider is on the way. Follow the rider on the map.';
        case OrderStatus.delivered:
          title = 'Delivered';
          body = 'Order ${o.displayNumber} was delivered. Tap to rate it.';
        case OrderStatus.cancelled:
          title = 'Order cancelled';
          body = o.cancelReason.isNotEmpty
              ? o.cancelReason
              : 'Order ${o.displayNumber} was cancelled.';
        case OrderStatus.placed:
          break;
      }
    } else if (now.arrived && !before.arrived) {
      title = 'Your rider has arrived';
      body = 'Please keep your empty cylinders ready.';
    } else if (now.payment == PaymentStatus.paid &&
        before.payment != PaymentStatus.paid) {
      title = 'Payment confirmed';
      body = 'Thank you! Order ${o.displayNumber} is paid.';
    }
    if (title != null && body != null) {
      Alerts.show(
        id: _id(o.id, 1),
        title: title,
        body: body,
        payload: '/orders/${o.id}',
      );
    }
  }

  static int _id(String orderId, int kind) =>
      (orderId.hashCode & 0x3fffffff) * 4 + kind;

  void _stop() {
    _orders?.cancel();
    _orders = null;
    for (final s in _messageSubs.values) {
      s.cancel();
    }
    _messageSubs.clear();
    _last.clear();
    _messagesSeen.clear();
    _state.chat.follow(const []);
    KeepAlive.stop();
  }

  void dispose() {
    _state.removeListener(_onState);
    _stop();
  }
}

class _Seen {
  const _Seen(this.status, this.arrived, this.payment);
  final OrderStatus status;
  final bool arrived;
  final PaymentStatus payment;
}
