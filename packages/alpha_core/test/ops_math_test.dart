import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_test/flutter_test.dart';

LpgOrder _o({
  String id = 'o',
  String customer = 'c1',
  String? rider,
  OrderStatus status = OrderStatus.delivered,
  int? cash,
  int toCollect = 0,
  int? collected,
}) => LpgOrder(
  id: id,
  customerId: customer,
  customerName: 'Ali',
  customerPhone: '+923001234567',
  items: [
    if (toCollect > 0)
      OrderItem(
        productId: 'p',
        name: 'Cylinder',
        sizeKg: 11.8,
        type: PurchaseType.refill,
        unitPrice: 100,
        quantity: toCollect,
      ),
  ],
  subtotal: 0,
  deliveryFee: 0,
  total: 0,
  address: const Address(label: 'Home', line1: '1', area: 'DHA'),
  status: status,
  riderId: rider,
  cashCollected: cash,
  emptiesCollected: collected,
  updatedAt: DateTime.now(),
);

void main() {
  test('customer balance: empties owed and deposit held', () {
    final orders = [
      _o(id: 'a', toCollect: 2, collected: 1), // 1 owed
      _o(id: 'b', toCollect: 1, collected: 1), // settled
      _o(id: 'c', toCollect: 3, status: OrderStatus.cancelled), // ignored
      _o(id: 'd', customer: 'c2', toCollect: 5), // someone else
    ];
    final ledger = [
      const LedgerEntry(
        customerId: 'c1',
        kind: LedgerKind.deposit,
        amount: 4000,
      ),
      const LedgerEntry(
        customerId: 'c1',
        kind: LedgerKind.depositRefund,
        amount: 1000,
      ),
      const LedgerEntry(
        customerId: 'c1',
        kind: LedgerKind.emptiesOwed,
        empties: 2,
      ),
      const LedgerEntry(
        customerId: 'c1',
        kind: LedgerKind.emptiesReturned,
        empties: 1,
      ),
    ];
    final b = balanceFor('c1', orders, ledger);
    expect(b.deposit, 3000);
    expect(b.emptiesOwed, 2); // 1 from order + 2 - 1
    expect(balanceFor('nobody', orders, ledger).emptiesOwed, 0);
  });

  test('rider cash: collected, handed in, still pending', () {
    final orders = [
      _o(id: 'a', rider: 'r1', cash: 3000),
      _o(id: 'b', rider: 'r1', cash: 2000),
      _o(id: 'c', rider: 'r2', cash: 999),
      _o(id: 'd', rider: 'r1', status: OrderStatus.outForDelivery, cash: 50),
    ];
    final handovers = [const CashHandover(riderId: 'r1', amount: 4000)];
    final c = riderCash('r1', orders, handovers);
    expect(c.collected, 5000);
    expect(c.handedIn, 4000);
    expect(c.pending, 1000);
    expect(c.deliveries, 2);
    expect(
      riderCash('r1', orders, [
        const CashHandover(riderId: 'r1', amount: 9000),
      ]).pending,
      0,
    );
  });

  test('ledger and handovers round-trip through the memory store', () async {
    final r = OpsRepository.memory(MemoryStore());
    await r.addLedger(
      const LedgerEntry(
        customerId: 'c1',
        kind: LedgerKind.deposit,
        amount: 500,
      ),
    );
    await r.addHandover(
      const CashHandover(riderId: 'r1', riderName: 'Imran', amount: 700),
    );
    await r.addAudit(
      const AuditEntry(by: 'boss', action: 'markPaid', target: 'o1'),
    );
    await r.reportError(const ErrorEntry(app: 'rider', message: 'boom'));
    expect((await r.watchLedger().first).single.amount, 500);
    expect((await r.watchRiderHandovers('r1').first).single.amount, 700);
    expect((await r.watchAudit().first).single.action, 'markPaid');
    expect((await r.watchErrors().first).single.message, 'boom');
  });
}
