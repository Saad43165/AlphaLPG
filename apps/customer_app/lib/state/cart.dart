import 'dart:convert';

import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class CartLine {
  const CartLine(this.productId, this.type, this.quantity);
  final String productId;
  final PurchaseType type;
  final int quantity;

  String get key => '$productId|${type.name}';
}

/// The shopping cart. Stores only product ids and quantities; prices are
/// always taken from the live catalogue so they are never stale.
class Cart extends ChangeNotifier {
  Cart({this.prefs}) {
    _load();
  }

  static const _storageKey = 'cart.v1';
  final SharedPreferences? prefs;
  final Map<String, CartLine> _lines = {};

  List<CartLine> get lines => _lines.values.toList();
  bool get isEmpty => _lines.isEmpty;
  int get count => _lines.values.fold(0, (n, l) => n + l.quantity);

  int quantityOf(String productId, [PurchaseType? type]) => _lines.values
      .where(
        (l) => l.productId == productId && (type == null || l.type == type),
      )
      .fold(0, (n, l) => n + l.quantity);

  void add(String productId, PurchaseType type, [int qty = 1]) {
    final key = CartLine(productId, type, 0).key;
    final current = _lines[key]?.quantity ?? 0;
    setQuantity(productId, type, current + qty);
  }

  void setQuantity(String productId, PurchaseType type, int qty) {
    final line = CartLine(productId, type, qty.clamp(0, 99));
    if (line.quantity == 0) {
      _lines.remove(line.key);
    } else {
      _lines[line.key] = line;
    }
    _changed();
  }

  void clear() {
    _lines.clear();
    _changed();
  }

  /// Replaces the cart with the items of a previous order.
  void reorder(LpgOrder order) {
    _lines.clear();
    for (final i in order.items) {
      final l = CartLine(i.productId, i.type, i.quantity);
      _lines[l.key] = l;
    }
    _changed();
  }

  /// Priced order items using live catalogue prices. Unknown or out-of-stock
  /// products are skipped.
  List<OrderItem> toOrderItems(Product? Function(String id) lookup) => [
    for (final l in _lines.values)
      if (lookup(l.productId) case final p? when p.inStock)
        OrderItem(
          productId: p.id,
          name: p.name,
          sizeKg: p.sizeKg,
          type: l.type,
          unitPrice: p.priceFor(l.type),
          quantity: l.quantity,
        ),
  ];

  void _changed() {
    notifyListeners();
    prefs?.setString(
      _storageKey,
      jsonEncode([
        for (final l in _lines.values)
          {'p': l.productId, 't': l.type.name, 'q': l.quantity},
      ]),
    );
  }

  void _load() {
    final raw = prefs?.getString(_storageKey);
    if (raw == null) return;
    try {
      for (final m in jsonDecode(raw) as List) {
        final l = CartLine(
          m['p'] as String,
          PurchaseType.parse(m['t'] as String?),
          (m['q'] as num).toInt(),
        );
        if (l.quantity > 0) _lines[l.key] = l;
      }
    } catch (_) {
      // Corrupt data: start with an empty cart.
    }
  }
}
