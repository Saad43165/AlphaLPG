import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';
import '../models/app_settings.dart';
import '../models/product.dart';
import '../seed_data.dart';
import 'memory_store.dart';

abstract interface class CatalogRepository {
  factory CatalogRepository.firestore(FirebaseFirestore db) = _FirestoreCatalog;
  factory CatalogRepository.memory(MemoryStore store) = _MemoryCatalog;

  /// Active products in display order. Falls back to [SeedData] when nothing
  /// has been seeded yet so the app is never empty.
  Stream<List<Product>> watchProducts();
  Stream<AppSettings> watchSettings();

  /// Admin view: every product (hidden ones too), exactly as stored, with no
  /// fallback. Empty until the catalogue has been loaded.
  Stream<List<Product>> watchAllProducts();

  /// Admin view: the stored settings, or null until they have been saved.
  Stream<AppSettings?> watchStoredSettings();

  /// Admin only (enforced by security rules).
  Future<void> saveProduct(Product p);
  Future<void> saveSettings(AppSettings s);
  Future<void> seed();

  /// Admin: add [delta] (negative to take) to a product's counted stock. A
  /// product with no counted stock is left alone. At 0 or less the product is
  /// marked out of stock; back above 0 it is in stock again.
  Future<void> adjustStock(String productId, int delta);
}

List<Product> _activeSorted(Iterable<Product> all) {
  final list = all.where((p) => p.active).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return list;
}

class _FirestoreCatalog implements CatalogRepository {
  _FirestoreCatalog(this._db);
  final FirebaseFirestore _db;

  @override
  Stream<List<Product>> watchProducts() => _db
      .collection(FirestorePaths.products)
      .snapshots()
      .map(
        (snap) => snap.docs.isEmpty
            ? SeedData.products
            : _activeSorted(
                snap.docs.map((d) => Product.fromMap(d.id, d.data())),
              ),
      );

  @override
  Stream<List<Product>> watchAllProducts() => _db
      .collection(FirestorePaths.products)
      .snapshots()
      .map(
        (snap) =>
            [for (final d in snap.docs) Product.fromMap(d.id, d.data())]
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      );

  @override
  Stream<AppSettings?> watchStoredSettings() => _db
      .doc(FirestorePaths.settingsDoc)
      .snapshots()
      .map((d) => d.exists ? AppSettings.fromMap(d.data()!) : null);

  @override
  Stream<AppSettings> watchSettings() => _db
      .doc(FirestorePaths.settingsDoc)
      .snapshots()
      .map(
        (d) => d.exists ? AppSettings.fromMap(d.data()!) : SeedData.settings,
      );

  @override
  Future<void> saveProduct(Product p) =>
      _db.collection(FirestorePaths.products).doc(p.id).set(p.toMap());

  @override
  Future<void> saveSettings(AppSettings s) =>
      _db.doc(FirestorePaths.settingsDoc).set(s.toMap());

  @override
  Future<void> adjustStock(String productId, int delta) async {
    final ref = _db.collection(FirestorePaths.products).doc(productId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final stock = (snap.data()?['stock'] as num?)?.round();
      if (!snap.exists || stock == null) return;
      final next = stock + delta;
      tx.update(ref, {'stock': next < 0 ? 0 : next, 'inStock': next > 0});
    });
  }

  @override
  Future<void> seed() async {
    final batch = _db.batch();
    for (final p in SeedData.products) {
      batch.set(_db.collection(FirestorePaths.products).doc(p.id), p.toMap());
    }
    batch.set(_db.doc(FirestorePaths.settingsDoc), SeedData.settings.toMap());
    await batch.commit();
  }
}

class _MemoryCatalog implements CatalogRepository {
  _MemoryCatalog(this._s);
  final MemoryStore _s;
  static const _config = 'config';

  @override
  Stream<List<Product>> watchProducts() => _s.watch(
    FirestorePaths.products,
    (docs) => docs.isEmpty
        ? SeedData.products
        : _activeSorted(
            docs.entries.map((e) => Product.fromMap(e.key, e.value)),
          ),
  );

  @override
  Stream<List<Product>> watchAllProducts() => _s.watch(
    FirestorePaths.products,
    (docs) =>
        [for (final e in docs.entries) Product.fromMap(e.key, e.value)]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
  );

  @override
  Stream<AppSettings?> watchStoredSettings() => _s.watch(_config, (docs) {
    final d = docs['app'];
    return d == null ? null : AppSettings.fromMap(d);
  });

  @override
  Stream<AppSettings> watchSettings() => _s.watch(_config, (docs) {
    final d = docs['app'];
    return d == null ? SeedData.settings : AppSettings.fromMap(d);
  });

  @override
  Future<void> saveProduct(Product p) async =>
      _s.set(FirestorePaths.products, p.id, p.toMap());

  @override
  Future<void> saveSettings(AppSettings s) async =>
      _s.set(_config, 'app', s.toMap());

  @override
  Future<void> adjustStock(String productId, int delta) async {
    final d = _s.get(FirestorePaths.products, productId);
    final stock = (d?['stock'] as num?)?.round();
    if (d == null || stock == null) return;
    final next = stock + delta;
    _s.set(FirestorePaths.products, productId, {
      ...d,
      'stock': next < 0 ? 0 : next,
      'inStock': next > 0,
    });
  }

  @override
  Future<void> seed() async {
    for (final p in SeedData.products) {
      await saveProduct(p);
    }
    await saveSettings(SeedData.settings);
  }
}
