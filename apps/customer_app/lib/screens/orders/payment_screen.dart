import 'package:alpha_core/alpha_core.dart';
import 'package:material_ui/material_ui.dart' hide Text;

import '../../l10n/text.dart';

import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/payment.dart';
import '../../widgets/payment_request_card.dart';

/// Paying for an online (JazzCash / Easypaisa / bank) order, step by step,
/// on its own screen so it never gets lost among the delivery details.
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) => StreamBuilder<LpgOrder?>(
    stream: context.read<Backend>().orders.watchOrder(orderId),
    builder: (context, snap) {
      final o = snap.data;
      return Scaffold(
        appBar: AppBar(
          leading: const ScreenBack(),
          title: const Text('Payment'),
        ),
        body: o == null ? const DetailSkeleton() : Constrained(child: _Body(o)),
      );
    },
  );
}

class _Body extends StatelessWidget {
  const _Body(this.o);
  final LpgOrder o;

  @override
  Widget build(BuildContext context) {
    final paid = o.paymentStatus == PaymentStatus.paid;
    final sent = o.paymentRequest != null;
    final receipt = o.receiptAt != null;
    final m = o.paymentMethod;
    final pal = context.pal;

    // Which step the customer is on (1-4).
    final step = paid
        ? 4
        : !sent
        ? 1
        : receipt && o.paymentIssue.isEmpty
        ? 4
        : 2;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Summary: method, amount, status.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [m.color, Color.lerp(m.color, Brand.navy, 0.45)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(Brand.radius),
          ),
          child: Row(
            children: [
              PaymentLogo(m, width: 60, height: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatRupees(o.total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),
                    ),
                    Text(
                      '${m.label} · order ${o.displayNumber}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  paid ? 'PAID' : (receipt ? 'CHECKING' : 'UNPAID'),
                  style: TextStyle(
                    color: paid ? context.pal.green : Brand.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        _Step(
          n: 1,
          title: 'Alpha LPG sends you the account',
          state: step > 1 ? _S.done : _S.active,
          child: sent
              ? PaymentRequestCard(o.paymentRequest!)
              : Text(
                  'We are preparing the ${m.label} details for this order. You will get a notification as soon as they arrive. Please do not pay before that.',
                  style: TextStyle(color: pal.muted, height: 1.4),
                ),
        ),
        _Step(
          n: 2,
          title:
              'Send ${formatRupees(o.paymentRequest?.amount ?? o.total)} from your ${m.label} app',
          state: !sent
              ? _S.waiting
              : (receipt && o.paymentIssue.isEmpty) || paid
              ? _S.done
              : _S.active,
          child: sent && !paid && !receipt
              ? Text(
                  'Copy the account number above, open your ${m.label} app and send the exact amount. Keep the receipt it shows you.',
                  style: TextStyle(color: pal.muted, height: 1.4),
                )
              : null,
        ),
        _Step(
          n: 3,
          title: 'Send us the transaction ID and screenshot',
          state: !sent
              ? _S.waiting
              : (receipt && o.paymentIssue.isEmpty) || paid
              ? _S.done
              : _S.active,
          child: sent && !paid ? ReceiptSection(o) : null,
        ),
        _Step(
          n: 4,
          title: 'Alpha LPG confirms your payment',
          last: true,
          state: paid
              ? _S.done
              : receipt && o.paymentIssue.isEmpty
              ? _S.active
              : _S.waiting,
          child: paid
              ? Text(
                  'Payment confirmed. Thank you! Your order will be delivered.',
                  style: TextStyle(
                    color: context.pal.green,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : receipt && o.paymentIssue.isEmpty
              ? Text(
                  'We are checking transaction ${o.paymentReference}. This usually takes a few minutes during shop hours.',
                  style: TextStyle(color: pal.muted, height: 1.4),
                )
              : null,
        ),
      ],
    );
  }
}

enum _S { waiting, active, done }

class _Step extends StatelessWidget {
  const _Step({
    required this.n,
    required this.title,
    required this.state,
    this.child,
    this.last = false,
  });

  final int n;
  final String title;
  final _S state;
  final Widget? child;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final color = switch (state) {
      _S.done => Brand.success,
      _S.active => Brand.blueDark,
      _S.waiting => pal.muted,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: state == _S.waiting ? Colors.transparent : color,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                alignment: Alignment.center,
                child: state == _S.done
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : Text(
                        '$n',
                        style: TextStyle(
                          color: state == _S.active ? Colors.white : color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: state == _S.done ? Brand.success : pal.line,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 20, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                      color: state == _S.waiting ? pal.muted : pal.ink,
                    ),
                  ),
                  if (child != null) ...[const SizedBox(height: 10), child!],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
