import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart' hide Text;
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../l10n/text.dart';
import '../state/app_state.dart';
import '../state/promo_state.dart';
import '../theme/brand.dart';

/// "Have a code?" and "Use my points" on the checkout.
class PromoPanel extends StatefulWidget {
  const PromoPanel({super.key, required this.subtotal});
  final int subtotal;

  @override
  State<PromoPanel> createState() => _PromoPanelState();
}

class _PromoPanelState extends State<PromoPanel> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final promo = context.read<PromoState>();
    FocusScope.of(context).unfocus();
    final err = await promo.applyCode(_code.text, widget.subtotal);
    if (!mounted) return;
    setState(() => _error = err);
    if (err == null) _code.clear();
  }

  @override
  Widget build(BuildContext context) {
    final promo = context.watch<PromoState>();
    final settings = context.watch<AppState>().settings;
    final pal = context.pal;
    final c = promo.coupon;
    final cd = c == null ? 0 : c.discountFor(widget.subtotal);
    final maxPts = PriceBreakdown.maxPoints(
      widget.subtotal,
      cd,
      promo.loyalty.points,
      settings,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Divider(color: pal.line, height: 1),
        const SizedBox(height: 12),
        if (c != null)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(
              color: context.pal.card,
              border: Border.all(color: Brand.success, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_offer_rounded, color: Brand.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cd > 0
                        ? '${c.code} · ${formatRupees(cd)} off'
                        : '${c.code} · does not fit this order',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: tr('Remove code'),
                  onPressed: promo.removeCode,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[A-Za-z0-9\- ]'),
                    ),
                    LengthLimitingTextInputFormatter(20),
                  ],
                  decoration: InputDecoration(
                    labelText: tr('Coupon or friend\'s invite code'),
                    prefixIcon: const Icon(Icons.local_offer_outlined),
                    errorText: _error,
                    errorMaxLines: 2,
                  ),
                  onSubmitted: (_) => _apply(),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: promo.checking ? null : _apply,
                  child: promo.checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Apply'),
                ),
              ),
            ],
          ),
        if (settings.pointsEnabled &&
            promo.loyalty.points > 0 &&
            maxPts > 0) ...[
          const SizedBox(height: 8),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: promo.usePoints,
              onChanged: promo.setUsePoints,
              title: Text(
                'Use ${maxPts} points · ${formatRupees(maxPts * settings.pointValue)} off',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'You have ${promo.loyalty.points} points',
                style: TextStyle(color: pal.muted),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
