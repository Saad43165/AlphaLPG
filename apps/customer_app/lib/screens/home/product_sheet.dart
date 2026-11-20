import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../state/cart.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';

Future<void> showProductSheet(BuildContext context, Product product) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _ProductSheet(product),
    );

class _ProductSheet extends StatefulWidget {
  const _ProductSheet(this.product);
  final Product product;

  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  PurchaseType _type = PurchaseType.refill;
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Brand.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: ProductImage(p, height: 120),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizeBadge(p.sizeLabel),
                      const SizedBox(height: 8),
                      Text(
                        p.name,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatRupees(p.priceFor(_type)),
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Brand.blueDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (p.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(p.description),
            ],
            const SizedBox(height: 16),
            if (p.sellsNewCylinder)
              SegmentedButton<PurchaseType>(
                segments: [
                  for (final t in PurchaseType.values)
                    ButtonSegment(value: t, label: Text(t.label)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.autorenew, size: 18, color: Brand.blueDark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _type == PurchaseType.refill
                          ? 'Refill price — our rider collects your empty ${p.sizeLabel} cylinder.'
                          : PurchaseType.newCylinder.hint,
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                QuantityStepper(
                  value: _qty,
                  min: 1,
                  onChanged: (v) => setState(() => _qty = v),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: p.inStock
                        ? () {
                            HapticFeedback.mediumImpact();
                            context.read<Cart>().add(p.id, _type, _qty);
                            Navigator.pop(context);
                          }
                        : null,
                    child: Text(
                      p.inStock
                          ? 'Add · ${formatRupees(p.priceFor(_type) * _qty)}'
                          : 'Out of stock',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
