import 'models/ops_models.dart';
import 'models/order.dart';
import 'models/order_status.dart';

/// What a customer holds / owes: empties from delivered orders plus manual
/// ledger lines, and the deposit money the shop is holding.
CustomerBalance balanceFor(
  String customerId,
  Iterable<LpgOrder> orders,
  Iterable<LedgerEntry> ledger,
) {
  var empties = 0;
  for (final o in orders) {
    if (o.customerId != customerId || o.status != OrderStatus.delivered) {
      continue;
    }
    final owed = o.emptiesToCollect - (o.emptiesCollected ?? 0);
    empties += owed;
  }
  var deposit = 0;
  for (final e in ledger) {
    if (e.customerId != customerId) continue;
    switch (e.kind) {
      case LedgerKind.deposit:
        deposit += e.amount;
      case LedgerKind.depositRefund:
        deposit -= e.amount;
      case LedgerKind.emptiesOwed:
        empties += e.empties;
      case LedgerKind.emptiesReturned:
        empties -= e.empties;
    }
  }
  return CustomerBalance(
    deposit: deposit < 0 ? 0 : deposit,
    emptiesOwed: empties < 0 ? 0 : empties,
  );
}

/// A rider's cash position: what they collected on deliveries, what they
/// have handed in, and what is still with them.
class RiderCash {
  const RiderCash({
    this.collected = 0,
    this.handedIn = 0,
    this.collectedToday = 0,
    this.deliveries = 0,
  });

  final int collected;
  final int handedIn;
  final int collectedToday;
  final int deliveries;

  /// Cash the rider still has to hand over (never below zero).
  int get pending => collected - handedIn < 0 ? 0 : collected - handedIn;
}

RiderCash riderCash(
  String riderId,
  Iterable<LpgOrder> orders,
  Iterable<CashHandover> handovers, {
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final startOfDay = DateTime(t.year, t.month, t.day);
  var collected = 0, today = 0, deliveries = 0;
  for (final o in orders) {
    if (o.riderId != riderId || o.status != OrderStatus.delivered) continue;
    deliveries++;
    final cash = o.cashCollected ?? 0;
    collected += cash;
    final at = o.timeOf(OrderStatus.delivered) ?? o.updatedAt;
    if (at != null && !at.isBefore(startOfDay)) today += cash;
  }
  var handed = 0;
  for (final h in handovers) {
    if (h.riderId == riderId) handed += h.amount;
  }
  return RiderCash(
    collected: collected,
    handedIn: handed,
    collectedToday: today,
    deliveries: deliveries,
  );
}
