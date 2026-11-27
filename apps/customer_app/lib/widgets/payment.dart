import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart' hide Text;

import '../l10n/text.dart';

import '../theme/brand.dart';
import '../utils/haptics.dart';

extension PaymentMethodUi on PaymentMethod {
  /// Official logo file. Drop the provider's logo at this path to replace
  /// the branded badge.
  String get logoAsset => 'assets/payments/$name.png';

  Color get color => switch (this) {
    PaymentMethod.cashOnDelivery => Brand.success,
    // Exact brand colours, sampled from the official logos.
    PaymentMethod.jazzCash => const Color(0xFFEE2328),
    PaymentMethod.easyPaisa => const Color(0xFF00C252),
    PaymentMethod.bankTransfer => const Color(0xFF14427B),
  };

  /// Second brand colour used for highlights (JazzCash's yellow).
  Color get accent => switch (this) {
    PaymentMethod.jazzCash => const Color(0xFFFFC709),
    _ => Colors.white,
  };

  IconData get icon => switch (this) {
    PaymentMethod.cashOnDelivery => Icons.payments_rounded,
    PaymentMethod.jazzCash => Icons.account_balance_wallet_rounded,
    PaymentMethod.easyPaisa => Icons.account_balance_wallet_rounded,
    PaymentMethod.bankTransfer => Icons.account_balance_rounded,
  };

  String get tagline => switch (this) {
    PaymentMethod.cashOnDelivery => 'Pay the rider when it arrives',
    PaymentMethod.jazzCash => 'Pay from your JazzCash wallet',
    PaymentMethod.easyPaisa => 'Pay from your Easypaisa wallet',
    PaymentMethod.bankTransfer => 'Any bank app, IBAN or Raast',
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
      PaymentMethod.cashOnDelivery => (
        'CASH',
        context.pal.tint,
        context.pal.ink,
      ),
      PaymentMethod.jazzCash => (
        'Jazz\nCash',
        const Color(0xFFEE2328),
        const Color(0xFFFFC709),
      ),
      PaymentMethod.easyPaisa => (
        'easy\npaisa',
        const Color(0xFF00C252),
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
    required this.onChanged,
  });

  final PaymentMethod value;
  final AppSettings settings;
  final int total;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final online in [false, true])
        if (PaymentMethod.available.any((m) => m.isPrepaid == online)) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
            child: Text(
              online ? 'PAY ONLINE NOW' : 'PAY WHEN IT ARRIVES',
              style: TextStyle(
                color: context.pal.muted,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                letterSpacing: 1.1,
              ),
            ),
          ),
          for (final m in PaymentMethod.available.where(
            (m) => m.isPrepaid == online,
          )) ...[
            _MethodTile(
              method: m,
              selected: m == value,
              onTap: () {
                Haptics.select();
                onChanged(m);
              },
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
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
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.pal.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.pal.line, width: 1.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: context.pal.blue,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'How it works: place your order and Alpha LPG sends the ${value.label} account to your order screen. '
                              'Pay ${formatRupees(total)}, then send the transaction ID and a screenshot there. '
                              'Your order is delivered once the payment is confirmed.',
                              style: const TextStyle(height: 1.45),
                            ),
                          ),
                        ],
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
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? pal.tint : pal.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? pal.blue : pal.line,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                child: Row(
                  children: [
                    PaymentLogo(method, width: 56, height: 42),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            method.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            method.tagline,
                            style: TextStyle(
                              color: pal.muted,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? pal.blue : pal.muted,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? Center(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: pal.blue,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
