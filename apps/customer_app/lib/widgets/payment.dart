import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

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
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: value.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: value.color.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, color: value.color),
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
    this.recommended = false,
  });

  final PaymentMethod method;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final brand = method.color;
    // Selected: the tile takes the provider's exact colours, like their app.
    final fg = selected ? Colors.white : pal.ink;
    final sub = selected ? Colors.white.withValues(alpha: 0.88) : pal.muted;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: selected ? brand : pal.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? brand : pal.line,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: brand.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
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
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: fg,
                              ),
                            ),
                          ),
                          if (recommended) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : brand.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Popular',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : brand,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        method.tagline,
                        style: TextStyle(color: sub, fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    key: ValueKey(selected),
                    color: selected ? method.accent : pal.line,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
