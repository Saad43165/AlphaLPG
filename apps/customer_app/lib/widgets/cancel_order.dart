import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../services/backend.dart';
import '../state/app_state.dart';
import '../theme/brand.dart';
import '../utils/launch.dart';
import 'common.dart';

/// Asks why, then cancels. Handles every outcome: cancelled, already
/// confirmed by the shop (call instead), or a network problem.
/// Returns true when the order was cancelled.
Future<bool> cancelOrderFlow(BuildContext context, LpgOrder o) async {
  final backend = context.read<Backend>();
  final phone = context.read<AppState>().settings.phone;
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => const CancelDialog(),
  );
  if (reason == null || !context.mounted) return false;
  try {
    // The screens are live, so [o] is current. If the shop confirmed it while
    // the dialog was open, the database refuses and we offer a call below.
    if (!o.status.customerCanCancel) {
      if (context.mounted) {
        await _callInstead(
          context,
          o.status == OrderStatus.cancelled
              ? 'This order was already cancelled.'
              : 'The shop has already confirmed your order, so it cannot be cancelled in the app. Please call us and we will help.',
          phone,
          o.status != OrderStatus.cancelled,
        );
      }
      return false;
    }
    await backend.orders.cancelByCustomer(o, reason);
    if (context.mounted) showMessage(context, 'Order cancelled');
    return true;
  } catch (_) {
    if (context.mounted) {
      await _callInstead(
        context,
        'We could not cancel it. It may already be confirmed, or your internet is slow. Please call us.',
        phone,
        true,
      );
    }
    return false;
  }
}

Future<void> _callInstead(
  BuildContext context,
  String text,
  String phone,
  bool offerCall,
) => showDialog<void>(
  context: context,
  builder: (d) => AlertDialog(
    title: const Text('Cannot cancel here'),
    content: Text(text),
    actions: [
      TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK')),
      if (offerCall)
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(d);
            Launch.call(phone);
          },
          icon: const Icon(Icons.call_rounded, size: 18),
          label: const Text('Call Alpha LPG'),
        ),
    ],
  ),
);

class CancelDialog extends StatefulWidget {
  const CancelDialog({super.key});

  @override
  State<CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<CancelDialog> {
  static const _reasons = [
    'Ordered by mistake',
    'Need a different size',
    'Found gas elsewhere',
    'Delivery time too late',
    'Other',
  ];
  String _reason = _reasons.first;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cancel this order?'),
    content: RadioGroup<String>(
      groupValue: _reason,
      onChanged: (v) => setState(() => _reason = v!),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in _reasons)
            RadioListTile<String>(
              value: r,
              title: Text(r),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => context.pop(),
        child: const Text('Keep order'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Brand.danger,
          minimumSize: const Size(0, 44),
        ),
        onPressed: () => context.pop(_reason),
        child: const Text('Cancel order'),
      ),
    ],
  );
}
