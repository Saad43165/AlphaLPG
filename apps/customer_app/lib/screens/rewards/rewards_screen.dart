import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart' show WhatsAppIcon;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart' hide Text;
import 'package:provider/provider.dart';

import '../../l10n/text.dart';
import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../state/promo_state.dart';
import '../../theme/brand.dart';
import '../../utils/format.dart';
import '../../utils/launch.dart';
import '../../widgets/common.dart';

/// Reward points and the "invite a friend" code.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final promo = context.watch<PromoState>();
    final state = context.watch<AppState>();
    final s = state.settings;
    final pal = context.pal;
    final uid = state.uid;
    final code = promo.referralCode;
    return Scaffold(
      appBar: AppBar(
        leading: const ScreenBack(),
        title: Text(s.pointsEnabled ? 'Rewards and invites' : 'Invite friends'),
      ),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (s.pointsEnabled) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: Brand.headerGradient,
                  borderRadius: BorderRadius.circular(Brand.radius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your points',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${promo.loyalty.points}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '= ${formatRupees(promo.loyalty.points * s.pointValue)} off your next orders',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You earn ${s.pointsPerHundred} points for every Rs. 100 of a delivered order. '
                'Spend them at checkout: 1 point is ${formatRupees(s.pointValue)}, up to ${s.maxPointsPercent}% of an order.',
                style: TextStyle(color: pal.muted, height: 1.4),
              ),
            ],
            const SectionTitle('Invite a friend'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _panel(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.pointsEnabled
                        ? 'Your friend gets ${formatRupees(s.referralDiscount)} off their first order. '
                              'You get ${s.referralBonusPoints} points when it is delivered.'
                        : 'Your friend gets ${formatRupees(s.referralDiscount)} off their first order.',
                    style: const TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: context.pal.card,
                      border: Border.all(color: Brand.blue, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: SelectableText(
                        code ?? '…',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: code == null
                              ? null
                              : () {
                                  Clipboard.setData(ClipboardData(text: code));
                                  showMessage(context, 'Code copied');
                                },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: code == null
                              ? null
                              : () => Launch.whatsappShare(
                                  'Order LPG gas from Alpha LPG in Lahore. Use my code $code at checkout and get '
                                  '${formatRupees(s.referralDiscount)} off your first order.',
                                ),
                          icon: const WhatsAppIcon(size: 18),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (s.pointsEnabled) const SectionTitle('Points history'),
            if (uid == null || !s.pointsEnabled)
              const SizedBox.shrink()
            else
              StreamBuilder<List<LoyaltyEntry>>(
                stream: context.read<Backend>().promo.watchLoyaltyEntries(uid),
                builder: (context, snap) {
                  final list = snap.data ?? const <LoyaltyEntry>[];
                  if (list.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _panel(context),
                      child: Text(
                        'No points yet. They appear after your first delivery.',
                        style: TextStyle(color: pal.muted),
                      ),
                    );
                  }
                  return Container(
                    decoration: _panel(context),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        children: [
                          for (final e in list.take(30))
                            ListTile(
                              dense: true,
                              title: Text(e.reason),
                              subtitle: e.at == null
                                  ? null
                                  : Text(formatDateTime(e.at!.toLocal())),
                              trailing: Text(
                                '${e.delta > 0 ? '+' : ''}${e.delta}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: e.delta > 0
                                      ? Brand.success
                                      : Brand.danger,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _panel(BuildContext context) => BoxDecoration(
    color: context.pal.card,
    borderRadius: BorderRadius.circular(Brand.radius),
    boxShadow: context.pal.shadow,
  );
}
