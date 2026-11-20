import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/brand.dart';
import 'common.dart';

extension PaymentMethodUi on PaymentMethod {
  IconData get icon => switch (this) {
    PaymentMethod.cashOnDelivery => Icons.payments_rounded,
    PaymentMethod.jazzCash => Icons.account_balance_wallet_rounded,
    PaymentMethod.easyPaisa => Icons.phone_android_rounded,
    PaymentMethod.bankTransfer => Icons.account_balance_rounded,
  };

  Color get color => switch (this) {
    PaymentMethod.cashOnDelivery => Brand.success,
    PaymentMethod.jazzCash => const Color(0xFFC8102E),
    PaymentMethod.easyPaisa => const Color(0xFF2E9E48),
    PaymentMethod.bankTransfer => Brand.blueDark,
  };

  String get tagline => switch (this) {
    PaymentMethod.cashOnDelivery => 'Pay the rider in cash on delivery',
    PaymentMethod.jazzCash => 'Send to our JazzCash account',
    PaymentMethod.easyPaisa => 'Send to our Easypaisa account',
    PaymentMethod.bankTransfer => 'Transfer to our bank account',
  };

  /// Alpha LPG's receiving account for this method (empty if not set up).
  String accountIn(AppSettings s) => switch (this) {
    PaymentMethod.cashOnDelivery => '',
    PaymentMethod.jazzCash => s.jazzCashAccount,
    PaymentMethod.easyPaisa => s.easyPaisaAccount,
    PaymentMethod.bankTransfer => s.bankDetails,
  };
}

/// Radio cards for every payment method, with transfer instructions and an
/// optional transaction ID field for prepaid methods.
class PaymentMethodPicker extends StatelessWidget {
  const PaymentMethodPicker({
    super.key,
    required this.value,
    required this.settings,
    required this.total,
    required this.reference,
    required this.onChanged,
  });

  final PaymentMethod value;
  final AppSettings settings;
  final int total;
  final TextEditingController reference;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final m in PaymentMethod.available) ...[
        _MethodTile(
          method: m,
          selected: m == value,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(m);
          },
        ),
        const SizedBox(height: 8),
      ],
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        alignment: Alignment.topCenter,
        child: value.isPrepaid
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PaymentInstructions(
                      method: value,
                      settings: settings,
                      total: total,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reference,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Transaction ID (optional)',
                        helperText:
                            'You can also add it later from your order page',
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    ],
  );
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? Brand.blueTint : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: selected ? Brand.blueDark : Brand.line,
        width: selected ? 1.5 : 1,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: method.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(method.icon, color: method.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    method.tagline,
                    style: const TextStyle(color: Brand.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? Brand.blueDark : Brand.muted,
            ),
          ],
        ),
      ),
    ),
  );
}

/// "Send Rs. X to …" box with copy buttons.
class PaymentInstructions extends StatelessWidget {
  const PaymentInstructions({
    super.key,
    required this.method,
    required this.settings,
    required this.total,
  });

  final PaymentMethod method;
  final AppSettings settings;
  final int total;

  @override
  Widget build(BuildContext context) {
    final account = method.accountIn(settings);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Brand.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Brand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Send ${formatRupees(total)} via ${method.label}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (account.isEmpty)
            Text(
              "We'll send you our ${method.label} account details on WhatsApp right after you place the order.",
              style: const TextStyle(color: Brand.muted, height: 1.35),
            )
          else ...[
            if (settings.accountTitle.isNotEmpty)
              _CopyRow(label: 'Account title', value: settings.accountTitle),
            _CopyRow(
              label: method == PaymentMethod.bankTransfer
                  ? 'Bank / IBAN'
                  : '${method.label} number',
              value: account,
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            'Send it now or when your cylinders arrive. We mark the order paid once we receive it.',
            style: TextStyle(color: Brand.muted, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Brand.muted, fontSize: 12),
              ),
              SelectableText(
                value,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Copy $label',
          icon: const Icon(Icons.copy_rounded, size: 20),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            showMessage(context, '$label copied');
          },
        ),
      ],
    ),
  );
}
