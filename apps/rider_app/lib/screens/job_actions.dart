import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
  if (order.awaitingOnlinePayment) {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Payment not confirmed yet'),
        content: Text(
          'This customer is paying by ${order.paymentMethod.label}. Alpha LPG '
          'confirms online payments, and only then can you finish the delivery. '
          'Do not take cash for this order. Ask Alpha LPG in chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }
  final result =
      await showModalBottomSheet<({int cash, int empties, String? photo})>(
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
    final photo = result.photo;
    if (photo != null) {
      // Best effort: the delivery is already saved.
      unawaited(session.addProof(order, photo));
    }
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

  /// One line per empty cylinder the customer should hand back.
  late final List<String> _slots = [
    for (final i in widget.order.items)
      if (i.type == PurchaseType.refill && !i.isAccessory)
        for (var n = 1; n <= i.quantity; n++)
          i.quantity == 1
              ? '${i.name} (empty)'
              : '${i.name} (empty $n of ${i.quantity})',
  ];
  late final List<bool> _took = List.filled(_slots.length, false);
  int get _empties => _took.where((t) => t).length;
  String? _photo;
  bool _photoBusy = false;

  Future<void> _takePhoto() async {
    setState(() => _photoBusy = true);
    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 2200,
        imageQuality: 90,
      );
      if (f != null) {
        final data = await compressReceiptPhoto(await f.readAsBytes());
        if (mounted) setState(() => _photo = data);
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Could not use the photo. Try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

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
        child: SingleChildScrollView(
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
                      color: context.pal.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.pal.warn, width: 2),
                    ),
                    child: Text(
                      _cashValue < due
                          ? 'You entered ${formatRupees(_cashValue)} but ${formatRupees(due)} is due. The difference is recorded.'
                          : 'You entered ${formatRupees(_cashValue)}, more than the ${formatRupees(due)} due.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              if (_slots.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.autorenew_rounded, color: Brand.blueDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Empty cylinders taken back',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '$_empties of ${_slots.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _empties == _slots.length
                            ? Brand.success
                            : context.pal.warn,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tick each empty cylinder you took from the customer, leave it unticked if they did not give it. The shop uses this to track empties still owed. A photo of the delivered cylinders protects you if the customer disputes it.',
                  style: TextStyle(
                    color: pal.muted,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: pal.line),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _slots.length; i++)
                        CheckboxListTile(
                          dense: true,
                          value: _took[i],
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            setState(() => _took[i] = v ?? false);
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            _slots[i],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(_took[i] ? 'Taken' : 'Not taken'),
                        ),
                    ],
                  ),
                ),
                if (_slots.length > 1)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() {
                        final all = _took.every((t) => t);
                        for (var i = 0; i < _took.length; i++) {
                          _took[i] = !all;
                        }
                      }),
                      child: Text(
                        _took.every((t) => t) ? 'Untick all' : 'Tick all',
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              if (_photo != null)
                Row(
                  children: [
                    ReceiptImage(_photo!, size: 64),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Delivery photo added')),
                    TextButton(
                      onPressed: () => setState(() => _photo = null),
                      child: const Text('Remove'),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                  ),
                  onPressed: _photoBusy ? null : _takePhoto,
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: Text(
                    _photoBusy
                        ? 'Please wait…'
                        : 'Take a delivery photo (recommended)',
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Brand.success),
                onPressed: _photoBusy
                    ? null
                    : () => Navigator.pop(context, (
                        cash: _cashValue,
                        empties: _empties,
                        photo: _photo,
                      )),
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Mark as delivered'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
