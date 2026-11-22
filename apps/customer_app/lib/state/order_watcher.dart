import 'dart:async';

import 'package:alpha_core/alpha_core.dart';

import '../l10n/lang.dart';

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
      final now = _Seen(
        o.status,
        o.arrivedAt != null,
        o.paymentStatus,
        o.paymentRequest != null,
        o.paymentIssue,
        o.riderName,
      );
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
                  ? tr('{} (rider)').replaceFirst(
                      '{}',
                      m.name.isEmpty ? tr('Your rider') : m.name,
                    )
                  : tr('Alpha LPG'),
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
    String? payload;
    if (before.rider != null && now.rider == null && o.status.isActive) {
      title = 'We are finding you a new rider';
      body =
          'Your rider was changed for order ${o.displayNumber}. We will tell you who is coming.';
    } else if (before.rider != null &&
        now.rider != null &&
        before.rider != now.rider &&
        o.status.isActive) {
      title = 'Your rider changed';
      body = '${now.rider} will deliver order ${o.displayNumber}.';
    } else if (now.status != before.status) {
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
          final byShop =
              o.history.isNotEmpty && o.history.last.by != o.customerId;
          title = byShop ? 'Alpha LPG cancelled your order' : 'Order cancelled';
          body =
              'Order ${o.displayNumber} was cancelled'
              '${o.cancelReason.isNotEmpty ? ': ${o.cancelReason}' : '.'}'
              '${byShop && o.paymentStatus == PaymentStatus.paid ? ' Alpha LPG will contact you about your refund.' : ''}';
        case OrderStatus.placed:
          break;
      }
    } else if (now.requested && !before.requested) {
      payload = '/orders/${o.id}/payment';
      title = 'Payment details from Alpha LPG';
      body = 'Tap to see where to send ${formatRupees(o.total)}.';
    } else if (now.issue.isNotEmpty && now.issue != before.issue) {
      payload = '/orders/${o.id}/payment';
      title = 'Payment needs attention';
      body = now.issue;
    } else if (now.arrived && !before.arrived) {
      title = 'Your rider has arrived';
      body = 'Please keep your empty cylinders ready.';
    } else if (now.payment == PaymentStatus.paid &&
        before.payment != PaymentStatus.paid) {
      title = 'Payment confirmed';
      body = 'Thank you! Order ${o.displayNumber} is paid.';
    }
    if (title != null && body != null) {
      title = tr(title);
      body = tr(body);
      Alerts.show(
        id: _id(o.id, 1),
        title: title,
        body: body,
        payload: payload ?? '/orders/${o.id}',
      );
      // Also inside the app, in case phone notifications are off.
      _state.inAppNotice?.call(title, body, payload ?? '/orders/${o.id}');
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
  const _Seen(
    this.status,
    this.arrived,
    this.payment,
    this.requested,
    this.issue,
    this.rider,
  );
  final OrderStatus status;
  final bool arrived;
  final PaymentStatus payment;
  final bool requested;
  final String issue;
  final String? rider;
}
