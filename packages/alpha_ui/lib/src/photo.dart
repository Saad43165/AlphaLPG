import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';

/// Shrinks a payment screenshot so it fits inside a Firestore document (the
/// free plan has no file storage). Returns base64 JPEG (about 150-300 KB) or
/// throws a readable message.
Future<String> compressReceiptPhoto(Uint8List original) =>
    compute(_compressReceipt, original);

String _compressReceipt(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw 'That file is not a picture we can read. Choose another one.';
  }
  var side = 1100;
  late Uint8List out;
  for (var i = 0; i < 6; i++) {
    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final resized = longest <= side
        ? decoded
        : decoded.width >= decoded.height
        ? img.copyResize(decoded, width: side)
        : img.copyResize(decoded, height: side);
    out = img.encodeJpg(resized, quality: i < 2 ? 78 : 65);
    if (out.length <= 300 * 1024) break;
    side = (side * 0.8).round();
  }
  if (out.length > 320 * 1024) {
    throw 'That picture is too detailed. Take a screenshot instead.';
  }
  return base64Encode(out);
}

/// A stored receipt picture. Tap to open it full screen.
class ReceiptImage extends StatelessWidget {
  const ReceiptImage(
    this.data, {
    super.key,
    this.size = 84,
    this.fullScreen = true,
  });
  final String data;
  final double size;
  final bool fullScreen;

  Uint8List? get _bytes {
    try {
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: bytes == null
          ? Container(
              width: size,
              height: size,
              color: Colors.black12,
              child: const Icon(Icons.broken_image_rounded),
            )
          : Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
    );
    if (!fullScreen || bytes == null) return child;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ReceiptViewer(bytes: bytes)),
      ),
      child: child,
    );
  }
}

/// Pinch-to-zoom full-screen receipt.
class ReceiptViewer extends StatelessWidget {
  const ReceiptViewer({super.key, required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('Payment receipt'),
    ),
    body: Center(
      child: InteractiveViewer(
        maxScale: 5,
        child: Image.memory(bytes, fit: BoxFit.contain),
      ),
    ),
  );
}
