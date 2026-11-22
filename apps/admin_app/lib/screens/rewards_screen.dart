import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/order_x.dart';
import '../widgets/common.dart';

/// Coupons, invite-a-friend and reward points, all in one place.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final pal = context.pal;
    final st = s.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Coupons and rewards')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editCoupon(context, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New coupon'),
      ),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            const Heading('Coupons'),
            Text(
              'A customer types the code at checkout. Each code works once per customer.',
              style: TextStyle(color: pal.muted, height: 1.35),
            ),
            const SizedBox(height: 10),
            if (s.coupons.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: panel(context),
                child: const Text(
                  'No coupons yet. Tap "New coupon". For example WELCOME200: Rs. 200 off.',
                ),
              ),
            for (final c in s.coupons)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: panel(context),
                child: Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    onTap: () => editCoupon(context, c),
                    title: Text(
                      c.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    subtitle: Text(
                      [
                        c.summary,
                        if (c.minOrder > 0) 'min order ${rs(c.minOrder)}',
                        if (c.expiresAt != null)
                          'until ${DateFormat('d MMM').format(c.expiresAt!)}',
                        if (!c.active) 'switched off',
                      ].join(' · '),
                    ),
                    trailing: Switch(
                      value: c.active,
                      onChanged: (v) => s.saveCoupon(
                        Coupon(
                          code: c.code,
                          title: c.title,
                          percent: c.percent,
                          value: c.value,
                          maxDiscount: c.maxDiscount,
                          minOrder: c.minOrder,
                          active: v,
                          expiresAt: c.expiresAt,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const Heading('Reward points'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: panel(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Use reward points',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        st.pointsEnabled
                            ? 'On. Customers see their points.'
                            : 'Off. Customers do not see points.',
                      ),
                      value: st.pointsEnabled,
                      onChanged: s.isOwner
                          ? (v) => s.saveSettings(
                              AppSettings.fromMap({
                                ...st.toMap(),
                                'pointsSince': v
                                    ? DateTime.now().millisecondsSinceEpoch
                                    : 0,
                              }),
                            )
                          : null,
                    ),
                  ),
                  if (st.pointsEnabled) ...[
                    Text(
                      'Customers earn ${st.pointsPerHundred} points for every Rs. 100 of an order delivered from now on. '
                      '1 point is worth ${rs(st.pointValue)} and can pay up to ${st.maxPointsPercent}% of a new order. '
                      'Points appear after the delivery is marked done, while this app is open.',
                      style: TextStyle(color: pal.muted, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: s.isOwner
                            ? () => editRewardSettings(context)
                            : null,
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: Text(s.isOwner ? 'Change' : 'Owner only'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Heading('Refill plan'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: panel(context),
              child: Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Let customers set up a refill plan',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'They repeat their last order on a schedule and get reminded. Nothing is ordered automatically.',
                  ),
                  value: st.planEnabled,
                  onChanged: s.isOwner
                      ? (v) => s.saveSettings(
                          AppSettings.fromMap({
                            ...st.toMap(),
                            'planEnabled': v,
                          }),
                        )
                      : null,
                ),
              ),
            ),
            const Heading('Invite a friend'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: panel(context),
              child: Text(
                'Every customer has their own invite code (REF-…). A friend who uses it gets ${rs(st.referralDiscount)} off their first order'
                '${st.pointsEnabled ? ', and the customer gets ${st.referralBonusPoints} points when that order is delivered.' : '.'}',
                style: TextStyle(color: pal.muted, height: 1.4),
              ),
            ),
            const Heading('Refill reminders'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: panel(context),
              child: Text(
                'Customers get a "time to refill?" notification ${st.reminderDays} days after a delivery.',
                style: TextStyle(color: pal.muted, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> editRewardSettings(BuildContext context) async {
  final s = context.read<AdminSession>();
  final st = s.settings;
  final c = {
    'pointsPerHundred': TextEditingController(text: '${st.pointsPerHundred}'),
    'pointValue': TextEditingController(text: '${st.pointValue}'),
    'maxPointsPercent': TextEditingController(text: '${st.maxPointsPercent}'),
    'referralDiscount': TextEditingController(text: '${st.referralDiscount}'),
    'referralBonusPoints': TextEditingController(
      text: '${st.referralBonusPoints}',
    ),
    'reminderDays': TextEditingController(text: '${st.reminderDays}'),
  };
  const labels = {
    'pointsPerHundred': 'Points earned per Rs. 100',
    'pointValue': 'Rupees one point is worth',
    'maxPointsPercent': 'Most of an order points can pay (%)',
    'referralDiscount': 'Friend discount (Rs.)',
    'referralBonusPoints': 'Points for the friend who invited',
    'reminderDays': 'Send "time to refill" after (days)',
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Reward settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in c.entries)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(
                  controller: e.value,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: labels[e.key]),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(d, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  int n(String k, int min, int max, int fallback) {
    final v = int.tryParse(c[k]!.text.trim());
    return v == null ? fallback : v.clamp(min, max);
  }

  final next = AppSettings.fromMap({
    ...st.toMap(),
    'pointsPerHundred': n('pointsPerHundred', 0, 50, st.pointsPerHundred),
    'pointValue': n('pointValue', 0, 100, st.pointValue),
    'maxPointsPercent': n('maxPointsPercent', 0, 100, st.maxPointsPercent),
    'referralDiscount': n('referralDiscount', 0, 2000, st.referralDiscount),
    'referralBonusPoints': n(
      'referralBonusPoints',
      0,
      5000,
      st.referralBonusPoints,
    ),
    'reminderDays': n('reminderDays', 7, 90, st.reminderDays),
  });
  final err = await s.saveSettings(next);
  if (!context.mounted) return;
  showMessage(context, err ?? 'Saved.', error: err != null);
}

Future<void> editCoupon(BuildContext context, Coupon? existing) async {
  final s = context.read<AdminSession>();
  final code = TextEditingController(text: existing?.code ?? '');
  final value = TextEditingController(text: '${existing?.value ?? ''}');
  final cap = TextEditingController(
    text: (existing?.maxDiscount ?? 0) > 0 ? '${existing!.maxDiscount}' : '',
  );
  final min = TextEditingController(
    text: (existing?.minOrder ?? 0) > 0 ? '${existing!.minOrder}' : '',
  );
  final days = TextEditingController();
  var percent = existing?.percent ?? false;
  String? error;
  await showDialog<void>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setS) => AlertDialog(
        title: Text(existing == null ? 'New coupon' : 'Edit ${existing.code}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: code,
                enabled: existing == null,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Code (what customers type)',
                  hintText: 'WELCOME200',
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Rupees off')),
                  ButtonSegment(value: true, label: Text('Percent off')),
                ],
                selected: {percent},
                onSelectionChanged: (v) => setS(() => percent = v.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: value,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: percent ? 'Percent (1–90)' : 'Rupees off',
                ),
              ),
              if (percent) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: cap,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Most it can take off (Rs., optional)',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: min,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum order (Rs., optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: days,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: existing?.expiresAt == null
                      ? 'Valid for how many days? (empty = no end)'
                      : 'New end: days from today (empty = keep)',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Brand.danger),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () async {
                final nav = Navigator.of(d);
                await s.deleteCoupon(existing);
                nav.pop();
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Brand.danger),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final c = Coupon.clean(code.text);
              final v = int.tryParse(value.text.trim()) ?? 0;
              if (!RegExp(r'^[A-Z0-9]{3,20}$').hasMatch(c) ||
                  c.startsWith('REF-')) {
                setS(() => error = 'Use 3–20 letters or numbers for the code.');
                return;
              }
              if (v <= 0 || (percent && v > 90)) {
                setS(
                  () => error = percent
                      ? 'Percent must be 1–90.'
                      : 'Enter the rupees off.',
                );
                return;
              }
              final n = int.tryParse(days.text.trim());
              final nav = Navigator.of(d);
              final err = await s.saveCoupon(
                Coupon(
                  code: c,
                  percent: percent,
                  value: v,
                  maxDiscount: int.tryParse(cap.text.trim()) ?? 0,
                  minOrder: int.tryParse(min.text.trim()) ?? 0,
                  active: existing?.active ?? true,
                  expiresAt: n != null && n > 0
                      ? DateTime.now().add(Duration(days: n))
                      : existing?.expiresAt,
                ),
              );
              if (err != null) {
                setS(() => error = err);
                return;
              }
              nav.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
