import 'package:alpha_ui/alpha_ui.dart' show showAppMessage;

import '../l10n/lang.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Text;

import '../l10n/text.dart';

import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/cart.dart';
import '../theme/brand.dart';
import '../utils/nav.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 40, this.white = false});
  final double height;
  final bool white;

  @override
  Widget build(BuildContext context) => Image.asset(
    white ? 'assets/brand/logo_white.png' : 'assets/brand/logo.png',
    height: height,
    semanticLabel: tr('Alpha LPG'),
  );
}

class ProductImage extends StatelessWidget {
  const ProductImage(this.product, {super.key, this.height = 120});
  final Product product;
  final double height;

  /// Decoded photos, so a list does not decode the same base64 again and again.
  static final _decoded = <int, Uint8List>{};

  static Uint8List _bytes(String data) => _decoded.putIfAbsent(
    Object.hash(data.length, data.hashCode),
    () => base64Decode(data),
  );

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      Icons.propane_tank_rounded,
      size: height * 0.7,
      color: Brand.cylinderRed,
    );
    // 1) the owner's own photo, 2) a web link, 3) the closest bundled picture.
    if (product.hasUploadedImage) {
      try {
        return Image.memory(
          _bytes(product.imageData),
          semanticLabel: product.name,
          height: height,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => fallback,
        );
      } catch (_) {
        // Damaged data: fall through to the automatic picture.
      }
    }
    if (product.imageUrl.isNotEmpty) {
      return Image.network(
        product.imageUrl,
        semanticLabel: product.name,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.asset(
      product.automaticImageAsset,
      semanticLabel: product.name,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// The dark navy size tag used on alphalpg.pk ("11.8 KG").
class SizeBadge extends StatelessWidget {
  const SizeBadge(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Brand.navy,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class Tag extends StatelessWidget {
  const Tag(
    this.label, {
    super.key,
    this.color = Brand.flame,
    this.dark = true,
  });
  final String label;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: dark ? Brand.navy : Colors.white,
      ),
    ),
  );
}

class CartButton extends StatelessWidget {
  const CartButton({super.key, this.onDark = false});
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final count = context.watch<Cart>().count;
    return IconButton(
      tooltip: tr('Cart'),
      onPressed: () => context.push('/cart'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: onDark ? Brand.flame : Brand.cylinderRed,
        textColor: onDark ? Brand.navy : Colors.white,
        child: Icon(
          Icons.shopping_bag_outlined,
          color: onDark ? Colors.white : context.pal.ink,
        ),
      ),
    );
  }
}

/// Floating "3 cylinders · Rs. 9,888 · View cart" bar.
class CartBar extends StatelessWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    final state = context.watch<AppState>();
    if (cart.isEmpty) return const SizedBox.shrink();
    final items = cart.toOrderItems(state.productById);
    final total = items.fold(0, (s, i) => s + i.lineTotal);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DecoratedBox(
          // Bright brand gradient + shadow so it never blends into the page,
          // in light or dark mode.
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF7A1A), Color(0xFFE5331F)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE5331F).withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push('/cart'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${cart.count}',
                        style: const TextStyle(
                          color: Color(0xFFE5331F),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatRupees(total),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            '${cart.count} cylinder${cart.count == 1 ? '' : 's'} in your cart',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'View cart',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    // Readable in both themes: card colour, theme ink for icons and number.
    final ink = pal.ink;
    final off = pal.muted.withValues(alpha: 0.45);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: pal.isDark ? pal.muted : pal.line),
        borderRadius: BorderRadius.circular(12),
        color: pal.isDark ? pal.tint : Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: tr('Decrease'),
            color: ink,
            disabledColor: off,
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: Icon(
              value <= 1 && min == 0 ? Icons.delete_outline : Icons.remove,
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: ink,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: tr('Increase'),
            color: ink,
            disabledColor: off,
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final OrderStatus status;

  static Color colorOf(OrderStatus s) => switch (s) {
    OrderStatus.placed => const Color(0xFF8A6D00),
    OrderStatus.confirmed || OrderStatus.assigned => Brand.blueDark,
    OrderStatus.outForDelivery => const Color(0xFF6A3FC1),
    OrderStatus.delivered => Brand.success,
    OrderStatus.cancelled => const Color(0xFFB3261E),
  };

  @override
  Widget build(BuildContext context) {
    final c = colorOf(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message = '',
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Brand.blue.withValues(alpha: 0.12),
            child: Icon(icon, size: 40, color: Brand.blueDark),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

/// Narrow, centred column so the app also looks right on tablets / web.
class Constrained extends StatelessWidget {
  const Constrained({super.key, required this.child, this.maxWidth = 640});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

void showMessage(BuildContext context, String message, {bool error = false}) =>
    showAppMessage(context, tr(message), error: error);

/// Back button that always works: goes back, or Home when this screen is the
/// only one in the stack (e.g. after sign-in or a deep link).
class ScreenBack extends StatelessWidget {
  const ScreenBack({super.key});

  @override
  Widget build(BuildContext context) =>
      BackButton(onPressed: () => context.backOrHome());
}
