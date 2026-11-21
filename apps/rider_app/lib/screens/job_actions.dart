import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../state/session.dart';
import '../utils/order_x.dart';
import '../widgets/common.dart';

/// Start a delivery: needs location so the customer can follow the rider.
Future<void> startDeliveryFlow(
  BuildContext context,
  RiderSession session,
  LpgOrder order,
) async {
  HapticFeedback.mediumImpact();
  final result = await session.start(order);
  if (!context.mounted) return;
  switch (result) {
    case StartResult.ok:
      showMessage(context, 'On the way. The customer can now see you.');
    case StartResult.needsLocation:
      showMessage(
        context,
        'Allow location to start. The customer follows you on the map.',
        error: true,
      );
    case StartResult.needsLocationSettings:
      await _locationDialog(
        context,
        session,
        title: 'Location is blocked',
        body: 'Turn location on for this app in Settings so customers can follow their delivery.',
        button: 'Open settings',
      );
    case StartResult.locationOff:
      await _locationDialog(
        context,
        session,
        title: 'Location is off',
        body: 'Turn on your phone\'s location (GPS), then try again.',
        button: 'Open settings',
      );
    case StartResult.error:
      showMessage(
        context,
        'Could not start. Check your internet and try again.',
        error: true,
      );
  }
}

Future<void> _locationDialog(
  BuildContext context,
  RiderSession session, {
  required String title,
  required String body,
  required String button,
}) => showDialog<void>(
  context: context,
  builder: (c) => AlertDialog(
    title: Text(title),
    content: Text(body),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () {
          Navigator.pop(c);
          session.tracker.openSettings();
        },
        child: Text(button),
      ),
    ],
  ),
);

/// Finish a delivery: cash taken at the door and empties brought back.
Future<bool> completeDeliveryFlow(
  BuildContext context,
  RiderSession session,
  LpgOrder order,
) async {
  final result = await showModalBottomSheet<({int cash, int empties})>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CompleteSheet(order: order),
  );
  if (result == null || !context.mounted) return false;
  final ok = await session.complete(
    order,
    cash: result.cash,
    empties: result.empties,
  );
  if (!context.mounted) return ok;
  if (ok) {
    HapticFeedback.heavyImpact();
    showMessage(context, 'Delivered. Well done!');
  } else {
    showMessage(
      context,
      session.completeError ??
          'Could not save. Check your internet and try again.',
      error: true,
    );
  }
  return ok;
}

class _CompleteSheet extends StatefulWidget {
  const _CompleteSheet({required this.order});
  final LpgOrder order;

  @override
  State<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<_CompleteSheet> {
  late final _cash = TextEditingController(
    text: widget.order.amountDue > 0 ? '${widget.order.amountDue}' : '0',
  );
  late int _empties = widget.order.emptiesToCollect;

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  int get _cashValue => int.tryParse(_cash.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final due = o.amountDue;
    final pal = context.pal;
    final mismatch = due > 0 && _cashValue != due;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Confirm delivery',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${o.displayNumber} · ${o.address.label}, ${o.areaLine}',
              style: TextStyle(color: pal.muted),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _cash,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Cash collected (Rs.)',
                helperText: due > 0
                    ? 'Cash on delivery: ${formatRupees(due)} due'
                    : (o.paymentStatus == PaymentStatus.paid
                          ? 'Already paid: enter 0'
                          : 'Enter 0 if you took no cash'),
                prefixIcon: const Icon(Icons.payments_rounded),
              ),
            ),
            if (mismatch)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Brand.flame.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _cashValue < due
                        ? 'You entered ${formatRupees(_cashValue)} but ${formatRupees(due)} is due. The difference is recorded.'
                        : 'You entered ${formatRupees(_cashValue)}, more than the ${formatRupees(due)} due.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.autorenew_rounded, color: Brand.blueDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Empty cylinders collected',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Fewer empties',
                  onPressed: _empties > 0
                      ? () => setState(() => _empties--)
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '$_empties',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'More empties',
                  onPressed: _empties < 99
                      ? () => setState(() => _empties++)
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            if (o.emptiesToCollect > 0)
              Padding(
                padding: const EdgeInsets.only(left: 34, top: 2),
                child: Text(
                  'Customer should return ${o.emptiesToCollect}',
                  style: TextStyle(color: pal.muted, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Brand.success),
              onPressed: () =>
                  Navigator.pop(context, (cash: _cashValue, empties: _empties)),
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Mark as delivered'),
            ),
          ],
        ),
      ),
    );
  }
}
