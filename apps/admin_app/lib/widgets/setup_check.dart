import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';

/// "Is the shop ready?": a short checklist at the top of More. It only shows
/// while something still needs doing, so a finished shop sees nothing.
class SetupCheck extends StatelessWidget {
  const SetupCheck({super.key});

  /// What is missing, in plain words. Empty when the shop is ready.
  static List<String> problems(AdminSession s) {
    final st = s.settings;
    final hasPay = [
      st.bankDetails,
      st.jazzCashAccount,
      st.easyPaisaAccount,
      st.raastId,
    ].any((v) => v.trim().isNotEmpty);
    return [
      if (s.products.where((p) => p.active).isEmpty)
        'Add at least one product in the catalogue.',
      if (s.products.any((p) => p.active && p.stock == 0))
        'Some products are out of stock. Update the counts.',
      if (st.phone.trim().isEmpty) 'Add the shop phone number in settings.',
      if (st.serviceAreas.isEmpty) 'Add the areas you deliver to in settings.',
      if (!s.riders.any((r) => r.active))
        'Add a rider in the team, or orders cannot be delivered.',
      if (!hasPay) 'Add a bank, JazzCash or Easypaisa account, or customers cannot pay online.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    if (!s.storeReady && s.products.isEmpty) return const SizedBox.shrink();
    final list = problems(s);
    if (list.isEmpty) return const SizedBox.shrink();
    final pal = context.pal;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.pal.warnBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.pal.warnBg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, color: context.pal.warn),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Finish setting up (${list.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final p in list)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '• $p',
                style: TextStyle(color: pal.ink, height: 1.35),
              ),
            ),
        ],
      ),
    );
  }
}
