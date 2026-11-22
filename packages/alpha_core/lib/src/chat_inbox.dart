import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/order_message.dart';
import 'repositories/order_repository.dart';

/// Keeps track of the chats a person cares about (their orders / jobs): the
/// latest message and how many are unread. Used by all three apps, so a
/// customer, a rider and the shop each get the same behaviour as in
/// ride-hailing apps: badge, preview, and "Seen".
class ChatInbox extends ChangeNotifier {
  ChatInbox(
    this._orders,
    this.me, {
    this.retryStep = const Duration(seconds: 2),
  });

  /// Wait before the first quiet retry (it grows with each try).
  final Duration retryStep;

  final OrderRepository _orders;

  /// Which side this phone is on.
  final MessageRole me;

  final _messages = <String, List<OrderMessage>>{};
  final _reads = <String, Map<MessageRole, DateTime>>{};
  final _subs = <String, List<StreamSubscription<dynamic>>>{};
  final _pinned = <String, int>{};
  final _errors = <String, Object>{};
  final _tries = <String, int>{};
  final _timers = <String, Timer>{};
  Set<String> _wanted = {};

  /// A chat that fails right after an order is placed is usually just the
  /// order not being saved on the server yet (the rules look it up), and a
  /// failed listener never recovers by itself. So quietly try again a few
  /// times before showing an error.
  void _failed(String id, Object e) {
    final n = (_tries[id] ?? 0) + 1;
    _tries[id] = n;
    if (n <= 3) {
      for (final s
          in _subs.remove(id) ?? const <StreamSubscription<dynamic>>[]) {
        s.cancel();
      }
      _timers[id]?.cancel();
      _timers[id] = Timer(retryStep * n, () {
        _timers.remove(id);
        _apply();
      });
      return;
    }
    _errors[id] = e;
    notifyListeners();
  }

  /// Start / stop following chats so that exactly [orderIds] are followed.
  void follow(Iterable<String> orderIds) {
    _wanted = orderIds.toSet();
    _apply();
  }

  /// Keeps one chat followed while its screen is open (even if the order is
  /// no longer "active"). Call [unpin] when the screen closes.
  void pin(String orderId) {
    _pinned[orderId] = (_pinned[orderId] ?? 0) + 1;
    _apply();
  }

  void unpin(String orderId) {
    final n = (_pinned[orderId] ?? 1) - 1;
    if (n <= 0) {
      _pinned.remove(orderId);
    } else {
      _pinned[orderId] = n;
    }
    _apply();
  }

  void _apply() {
    final want = {..._wanted, ..._pinned.keys};
    for (final id in want) {
      if (_subs.containsKey(id)) continue;
      _subs[id] = [
        _orders.watchMessages(id).listen((m) {
          _messages[id] = m;
          _tries.remove(id);
          _errors.remove(id);
          notifyListeners();
        }, onError: (Object e) => _failed(id, e)),
        _orders.watchChatReads(id).listen((r) {
          _reads[id] = r;
          notifyListeners();
        }, onError: (_) {}),
      ];
    }
    for (final id in _subs.keys.toList()) {
      if (want.contains(id)) continue;
      for (final s in _subs.remove(id)!) {
        s.cancel();
      }
      _messages.remove(id);
      _reads.remove(id);
      _tries.remove(id);
      _timers.remove(id)?.cancel();
    }
  }

  /// Why the chat could not be loaded (null when fine). Typically the
  /// database rules do not allow chat yet.
  Object? error(String orderId) => _errors[orderId];

  /// Try loading this chat again.
  void retry(String orderId) {
    for (final s
        in _subs.remove(orderId) ?? const <StreamSubscription<dynamic>>[]) {
      s.cancel();
    }
    _errors.remove(orderId);
    _tries.remove(orderId);
    _timers.remove(orderId)?.cancel();
    _apply();
    notifyListeners();
  }

  /// Plain words for a chat error, for the screens.
  static String explain(Object e) => '$e'.contains('permission-denied')
      ? 'Chat is not switched on yet. Alpha LPG needs to publish the latest database rules.'
      : 'Could not load messages. Check your internet connection.';

  List<OrderMessage> messages(String orderId) => _messages[orderId] ?? const [];

  OrderMessage? last(String orderId) {
    final m = messages(orderId);
    return m.isEmpty ? null : m.last;
  }

  /// Messages from the other side that this person has not opened yet.
  int unread(String orderId) {
    final readAt = _reads[orderId]?[me];
    return messages(orderId)
        .where(
          (m) =>
              m.role != me &&
              (readAt == null ||
                  (m.createdAt != null && m.createdAt!.isAfter(readAt))),
        )
        .length;
  }

  int get totalUnread => _messages.keys.fold(0, (n, id) => n + unread(id));

  /// Opens the chat: everything so far counts as read.
  Future<void> markRead(String orderId) async {
    try {
      await _orders.markChatRead(orderId, me);
    } catch (_) {}
  }

  /// Has the other side (e.g. the rider) opened the chat since [t]?
  /// For the "Seen" tick under my last message.
  bool seenByOthers(String orderId, DateTime t) {
    final r = _reads[orderId];
    if (r == null) return false;
    return r.entries.any((e) => e.key != me && !e.value.isBefore(t));
  }

  @override
  void dispose() {
    for (final list in _subs.values) {
      for (final s in list) {
        s.cancel();
      }
    }
    _subs.clear();
    for (final t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }
}
