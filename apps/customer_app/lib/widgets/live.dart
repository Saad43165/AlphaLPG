import 'package:material_ui/material_ui.dart';

/// A [StreamBuilder] that creates its stream once per [cacheKey] instead of
/// on every rebuild (which would re-subscribe to Firestore each time).
class Live<T> extends StatefulWidget {
  const Live({
    super.key,
    required this.cacheKey,
    required this.stream,
    required this.builder,
  });

  final Object? cacheKey;
  final Stream<T> Function() stream;
  final AsyncWidgetBuilder<T> builder;

  @override
  State<Live<T>> createState() => _LiveState<T>();
}

class _LiveState<T> extends State<Live<T>> {
  late Stream<T> _stream = widget.stream();

  @override
  void didUpdateWidget(Live<T> old) {
    super.didUpdateWidget(old);
    if (old.cacheKey != widget.cacheKey) _stream = widget.stream();
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<T>(stream: _stream, builder: widget.builder);
}
