import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/brand.dart';
import '../utils/launch.dart';
import 'common.dart';
import '../utils/haptics.dart';

extension PaymentMethodUi on PaymentMethod {
  /// Official logo file. Drop the provider's logo at this path to replace
  /// the branded badge.
  String get logoAsset => 'assets/payments/$name.png';

  Color get color => switch (this) {
    PaymentMethod.cashOnDelivery => Brand.success,
    PaymentMethod.jazzCash => const Color(0xFFD71921),
    PaymentMethod.easyPaisa => const Color(0xFF00A651),
    PaymentMethod.bankTransfer => const Color(0xFF14427B),
  };

  IconData get icon => switch (this) {
    PaymentMethod.cashOnDelivery => Icons.payments_rounded,
    PaymentMethod.jazzCash => Icons.account_balance_wallet_rounded,
    PaymentMethod.easyPaisa => Icons.account_balance_wallet_rounded,
    PaymentMethod.bankTransfer => Icons.account_balance_rounded,
  };

  String get tagline => switch (this) {
    PaymentMethod.cashOnDelivery =>
      'Pay the rider in cash when your cylinders arrive',
    PaymentMethod.jazzCash => 'Send money from your JazzCash wallet',
    PaymentMethod.easyPaisa => 'Send money from your Easypaisa wallet',
    PaymentMethod.bankTransfer => 'Any bank app via IBAN or Raast ID',
  };

  /// Play Store id of the provider's app (null for cash / any bank).
  String? get appId => switch (this) {
    PaymentMethod.jazzCash => 'com.techlogix.mobilinkcustomer',
    PaymentMethod.easyPaisa => 'pk.com.telenor.phoenix',
    _ => null,
  };

  /// Alpha LPG's receiving account for this method (empty if not set up).
  String accountIn(AppSettings s) => switch (this) {
    PaymentMethod.cashOnDelivery => '',
    PaymentMethod.jazzCash => s.jazzCashAccount,
    PaymentMethod.easyPaisa => s.easyPaisaAccount,
    PaymentMethod.bankTransfer =>
      s.bankDetails.isNotEmpty ? s.bankDetails : s.raastId,
  };
}

/// Provider logo if the asset exists, otherwise a clean badge in the
/// provider's brand colour.
class PaymentLogo extends StatelessWidget {
  const PaymentLogo(
    this.method, {
    super.key,
    this.width = 64,
    this.height = 44,
  });
  final PaymentMethod method;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      // Provider logos are designed for white backgrounds in both themes.
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: context.pal.line),
    ),
    clipBehavior: Clip.antiAlias,
    padding: const EdgeInsets.all(5),
    child: Image.asset(
      method.logoAsset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => _Badge(method),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.method);
  final PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final (text, bg, fg) = switch (method) {
      PaymentMethod.cashOnDelivery => ('CASH', Brand.success, Colors.white),
      PaymentMethod.jazzCash => (
        'Jazz\nCash',
        const Color(0xFFD71921),
        const Color(0xFFFFD200),
      ),
      PaymentMethod.easyPaisa => (
        'easy\npaisa',
        const Color(0xFF00A651),
        Colors.white,
      ),
      PaymentMethod.bankTransfer => (
        'BANK',
        const Color(0xFF14427B),
        Colors.white,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Center(
          child: FittedBox(
            child:
                method == PaymentMethod.cashOnDelivery ||
                    method == PaymentMethod.bankTransfer
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(method.icon, color: fg, size: 15),
                      const SizedBox(width: 3),
                      Text(
                        text,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w800,
                          fontSize: 9.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  )
                : Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      height: 1.0,
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Method cards plus step-by-step transfer instructions for prepaid methods.
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
          recommended: m == PaymentMethod.cashOnDelivery,
          onTap: () {
            Haptics.select();
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
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PaymentSteps(
                      method: value,
                      settings: settings,
                      total: total,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: reference,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[A-Za-z0-9]'),
                        ),
                        LengthLimitingTextInputFormatter(30),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Transaction ID (TID)',
                        hintText: 'e.g. 012345678901',
                        helperText: 'Optional now. You can add it later from your order',
                        prefixIcon: const Icon(Icons.tag_rounded),
                        suffixIcon: Icon(
                          Icons.receipt_long_rounded,
                          color: value.color,
                        ),
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: validateTransactionId,
                    ),
                  ],
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    ],
  );
}

String? validateTransactionId(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return null;
  if (s.length < 6) return 'Transaction IDs are at least 6 characters';
  return null;
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
    this.recommended = false,
  });

  final PaymentMethod method;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    decoration: BoxDecoration(
      color: selected ? method.color.withValues(alpha: 0.06) : context.pal.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: selected ? method.color : context.pal.line,
        width: selected ? 1.8 : 1,
      ),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              PaymentLogo(method),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            method.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (recommended) ...[
                          const SizedBox(width: 6),
                          Tag('Popular', color: context.pal.tint),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      method.tagline,
                      style: TextStyle(color: context.pal.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  key: ValueKey(selected),
                  color: selected ? method.color : context.pal.line,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Numbered "how to pay" guide with copyable details and app shortcuts.
class PaymentSteps extends StatelessWidget {
  const PaymentSteps({
    super.key,
    required this.method,
    required this.settings,
    required this.total,
    this.orderNumber,
  });

  final PaymentMethod method;
  final AppSettings settings;
  final int total;
  final String? orderNumber;

  @override
  Widget build(BuildContext context) {
    final account = method.accountIn(settings);
    final hasAccount = account.isNotEmpty;
    final wallet =
        method == PaymentMethod.jazzCash || method == PaymentMethod.easyPaisa;
    final steps = <Widget>[
      _Step(
        n: 1,
        color: method.color,
        title: wallet ? 'Open your ${method.label} app' : 'Open your bank app',
        child: method.appId == null
            ? Text(
                'Use Raast or IBAN transfer. Both are instant and free.',
                style: TextStyle(color: context.pal.muted, fontSize: 13),
              )
            : Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    foregroundColor: method.color,
                    side: BorderSide(color: method.color),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => Launch.store(method.appId!),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text('Open ${method.label}'),
                ),
              ),
      ),
      _Step(
        n: 2,
        color: method.color,
        title: wallet ? 'Send money to Alpha LPG' : 'Transfer to Alpha LPG',
        child: hasAccount
            ? Column(
                children: [
                  if (settings.accountTitle.isNotEmpty)
                    _CopyRow(
                      label: 'Account title',
                      value: settings.accountTitle,
                    ),
                  if (method == PaymentMethod.bankTransfer) ...[
                    if (settings.bankDetails.isNotEmpty)
                      _CopyRow(
                        label: 'Bank / IBAN',
                        value: settings.bankDetails,
                      ),
                    if (settings.raastId.isNotEmpty)
                      _CopyRow(label: 'Raast ID', value: settings.raastId),
                  ] else
                    _CopyRow(label: '${method.label} number', value: account),
                ],
              )
            : Text(
                "We'll send our ${method.label} details on WhatsApp right after you place the order.",
                style: TextStyle(
                  color: context.pal.muted,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
      ),
      _Step(
        n: 3,
        color: method.color,
        title: 'Amount',
        child: _CopyRow(
          label: 'Exact amount',
          value: formatRupees(total),
          copyValue: '$total',
        ),
      ),
      _Step(
        n: 4,
        color: method.color,
        title: 'Save the transaction ID',
        last: true,
        child: Text(
          'Enter the TID from your receipt below. We confirm your payment within minutes.',
          style: TextStyle(
            color: context.pal.muted,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: context.pal.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PaymentLogo(method, width: 52, height: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'How to pay ${formatRupees(total)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...steps,
          if (orderNumber != null) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => Launch.whatsapp(
                settings.whatsapp,
                'Payment for order $orderNumber: ${formatRupees(total)} via ${method.label}. Receipt attached.',
              ),
              icon: const Icon(Icons.chat_rounded, color: Brand.whatsapp),
              label: const Text('Send payment receipt on WhatsApp'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.n,
    required this.color,
    required this.title,
    required this.child,
    this.last = false,
  });

  final int n;
  final Color color;
  final String title;
  final Widget child;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: color,
              child: Text(
                '$n',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (!last)
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: color.withValues(alpha: 0.25),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 4 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value, this.copyValue});
  final String label;
  final String value;
  final String? copyValue;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
    decoration: BoxDecoration(
      color: context.pal.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: context.pal.line),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: context.pal.muted, fontSize: 11),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Copy $label',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.copy_rounded, size: 18),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: copyValue ?? value));
            Haptics.light();
            showMessage(context, '$label copied');
          },
        ),
      ],
    ),
  );
}
