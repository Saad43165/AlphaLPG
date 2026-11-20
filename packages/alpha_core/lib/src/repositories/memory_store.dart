import 'dart:async';

/// A tiny in-memory document store used by the demo / test implementations
/// of the repositories. Safe in release builds (no Firebase mocks).
class MemoryStore {
  final _collections = <String, Map<String, Map<String, dynamic>>>{};
  final _changes = StreamController<String>.broadcast(sync: true);
  var _seq = 0;

  Map<String, Map<String, dynamic>> collection(String path) =>
      _collections.putIfAbsent(path, () => {});

  String newId() {
    _seq++;
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '$t${_seq.toRadixString(36)}'.toUpperCase().padLeft(12, 'X');
  }

  Map<String, dynamic>? get(String path, String id) {
    final d = collection(path)[id];
    return d == null ? null : Map<String, dynamic>.from(d);
  }

  void set(
    String path,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
  }) {
    final col = collection(path);
    col[id] = merge ? {...?col[id], ...data} : Map.of(data);
    _changes.add(path);
  }

  void update(
    String path,
    String id,
    Map<String, dynamic> Function(Map<String, dynamic> current) change,
  ) {
    final current = get(path, id);
    if (current == null) throw StateError('No document $path/$id');
    set(path, id, change(current));
  }

  void delete(String path, String id) {
    collection(path).remove(id);
    _changes.add(path);
  }

  /// Emits [build] of the collection now and after every change to it.
  Stream<T> watch<T>(
    String path,
    T Function(Map<String, Map<String, dynamic>> docs) build,
  ) {
    StreamSubscription<String>? sub;
    late final StreamController<T> c;
    c = StreamController<T>(
      onListen: () {
        scheduleMicrotask(() {
          if (!c.isClosed) c.add(build(Map.of(collection(path))));
        });
        sub = _changes.stream
            .where((p) => p == path)
            .listen((_) => c.add(build(Map.of(collection(path)))));
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream;
  }
}
