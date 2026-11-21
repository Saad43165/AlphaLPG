import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/order_message.dart';
import 'repositories/order_repository.dart';

/// Keeps track of the chats a person cares about (their orders / jobs): the
/// latest message and how many are unread. Used by all three apps, so a
/// customer, a rider and the shop each get the same behaviour as in
/// ride-hailing apps: badge, preview, and "Seen".
class ChatInbox extends ChangeNotifier {
  ChatInbox(this._orders, this.me);

  final OrderRepository _orders;

  /// Which side this phone is on.
  final MessageRole me;

  final _messages = <String, List<OrderMessage>>{};
  final _reads = <String, Map<MessageRole, DateTime>>{};
  final _subs = <String, List<StreamSubscription<dynamic>>>{};
  final _pinned = <String, int>{};
  Set<String> _wanted = {};

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
          notifyListeners();
        }, onError: (_) {}),
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
    }
  }

  List<OrderMessage> messages(String orderId) =>
      _messages[orderId] ?? const [];

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
    super.dispose();
  }
}
