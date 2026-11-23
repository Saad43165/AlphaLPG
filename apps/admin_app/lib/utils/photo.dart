import 'dart:convert';

import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';

/// Shrinks a photo so it can live inside the product record (the free
/// Firebase plan has no file storage). Keeps transparency as PNG, otherwise
/// JPEG. Returns base64, or throws a readable message.
Future<String> compressProductPhoto(Uint8List original) =>
    compute(_compress, original);

String _compress(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw 'That file is not a picture we can read. Try another photo.';
  }
  final alpha = decoded.hasAlpha;
  var side = 520;
  late Uint8List out;
  for (var i = 0; i < 6; i++) {
    final resized = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: side.clamp(0, decoded.width))
        : img.copyResize(decoded, height: side.clamp(0, decoded.height));
    out = alpha
        ? img.encodePng(resized, level: 9)
        : img.encodeJpg(resized, quality: 80);
    if (out.length <= 280 * 1024) break;
    side = (side * 0.8).round();
  }
  if (out.length > 600 * 1024) {
    throw 'That picture is too detailed. Choose a simpler photo.';
  }
  return base64Encode(out);
}

/// The product's picture as the customer will see it: the owner's photo, a
/// web link, or the bundled picture closest in size.
class ProductPicture extends StatelessWidget {
  const ProductPicture(this.product, {super.key, this.height = 72, this.data});
  final Product product;
  final double height;

  /// A photo picked but not saved yet (preview).
  final String? data;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      product.isAccessory
          ? Icons.soup_kitchen_rounded
          : Icons.propane_tank_rounded,
      size: height * 0.7,
      color: product.isAccessory
          ? const Color(0xFF1F5C99)
          : const Color(0xFFE53424),
    );
    final d = data ?? product.imageData;
    if (d.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(d),
          height: height,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => fallback,
        );
      } catch (_) {}
    }
    if (product.imageUrl.isNotEmpty) {
      return Image.network(
        product.imageUrl,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    if (product.isAccessory) return fallback;
    return Image.asset(
      product.automaticImageAsset,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
