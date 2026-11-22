import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/launch.dart';
import '../utils/order_x.dart';
import '../widgets/common.dart';
import 'order_detail_screen.dart';

/// Everyone who has ordered, with what they owe and a block switch.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

enum _CFilter { all, owing, blocked }

class _CustomersScreenState extends State<CustomersScreen> {
  String _q = '';
  _CFilter _f = _CFilter.all;

  static String _initials(String name) => name
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final pal = context.pal;
    final q = _q.trim().toLowerCase();
    final rows =
        <
          ({CustomerProfile c, CustomerBalance b, int orders, DateTime? last})
        >[];
    for (final c in s.customers) {
      if (q.isNotEmpty &&
          !'${c.name} ${c.phone} ${c.businessName}'.toLowerCase().contains(q)) {
        continue;
      }
      final b = balanceFor(c.uid, s.orders, s.ledger);
      final isBlocked = s.blocked.containsKey(c.uid);
      if (_f == _CFilter.owing && b.emptiesOwed == 0 && b.deposit == 0) {
        continue;
      }
      if (_f == _CFilter.blocked && !isBlocked) continue;
      final mine = s.orders.where((o) => o.customerId == c.uid).toList();
      DateTime? last;
      for (final o in mine) {
        final t = o.createdAt;
        if (t != null && (last == null || t.isAfter(last))) last = t;
      }
      rows.add((c: c, b: b, orders: mine.length, last: last));
    }
    final day = DateFormat('d MMM');
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: Constrained(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Everyone who has ordered from you. Tap a customer to see their orders, the empty cylinders they owe and their deposit, or to block them.',
                style: TextStyle(color: pal.muted, height: 1.4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(
                  hintText: 'Search by name or phone',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: SegmentedButton<_CFilter>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _CFilter.all, label: Text('All')),
                  ButtonSegment(
                    value: _CFilter.owing,
                    label: Text('Owe empties'),
                  ),
                  ButtonSegment(
                    value: _CFilter.blocked,
                    label: Text('Blocked'),
                  ),
                ],
                selected: {_f},
                onSelectionChanged: (v) => setState(() => _f = v.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${rows.length} customer${rows.length == 1 ? '' : 's'}',
                  style: TextStyle(color: pal.muted, fontSize: 13),
                ),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? EmptyState(
                      icon: Icons.people_alt_rounded,
                      title: _f == _CFilter.all
                          ? 'No customers found'
                          : _f == _CFilter.owing
                          ? 'Nobody owes empties'
                          : 'No blocked customers',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final r = rows[i];
                        final isBlocked = s.blocked.containsKey(r.c.uid);
                        return Material(
                          color: pal.card,
                          borderRadius: BorderRadius.circular(Brand.radius),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(Brand.radius),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ChangeNotifierProvider.value(
                                  value: s,
                                  child: CustomerDetailScreen(uid: r.c.uid),
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: isBlocked
                                        ? Brand.danger
                                        : Brand.navy,
                                    child: isBlocked
                                        ? const Icon(
                                            Icons.block_rounded,
                                            color: Colors.white,
                                          )
                                        : Text(
                                            _initials(r.c.name),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.c.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          prettyPhone(r.c.phone),
                                          style: TextStyle(
                                            color: pal.muted,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        Text(
                                          '${r.orders} order${r.orders == 1 ? '' : 's'}'
                                          '${r.last == null ? '' : ' · last ${day.format(r.last!.toLocal())}'}',
                                          style: TextStyle(
                                            color: pal.muted,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (r.b.emptiesOwed > 0 ||
                                            r.b.deposit > 0 ||
                                            isBlocked)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                if (isBlocked)
                                                  const Pill(
                                                    Icons.block_rounded,
                                                    'Blocked',
                                                    color: Brand.danger,
                                                  ),
                                                if (r.b.emptiesOwed > 0)
                                                  Pill(
                                                    Icons.autorenew_rounded,
                                                    'Owes ${r.b.emptiesOwed} empty cylinder${r.b.emptiesOwed == 1 ? '' : 's'}',
                                                    color: const Color(
                                                      0xFFB45309,
                                                    ),
                                                  ),
                                                if (r.b.deposit > 0)
                                                  Pill(
                                                    Icons.savings_rounded,
                                                    'Deposit ${rs(r.b.deposit)}',
                                                    color: Brand.success,
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key, required this.uid});
  final String uid;

  Future<void> _ledger(
    BuildContext context,
    CustomerProfile c,
    LedgerKind kind,
  ) async {
    final s = context.read<AdminSession>();
    final isMoney =
        kind == LedgerKind.deposit || kind == LedgerKind.depositRefund;
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c2) => AlertDialog(
        title: Text(kind.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: isMoney ? 'Amount (Rs)' : 'Number of cylinders',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c2, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c2, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final n = int.tryParse(amount.text.trim()) ?? 0;
    if (ok != true || n <= 0 || !context.mounted) return;
    final err = await s.addLedger(
      c,
      kind,
      amount: isMoney ? n : 0,
      empties: isMoney ? 0 : n,
      note: note.text.trim(),
    );
    if (context.mounted) {
      showMessage(context, err ?? 'Saved', error: err != null);
    }
  }

  Future<void> _block(
    BuildContext context,
    CustomerProfile c,
    bool block,
  ) async {
    final s = context.read<AdminSession>();
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(block ? 'Block ${c.name}?' : 'Unblock ${c.name}?'),
        content: block
            ? TextField(
                controller: reason,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Reason (only you see it)',
                ),
              )
            : const Text('They will be able to place orders again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(block ? 'Block' : 'Unblock'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final err = await s.setCustomerBlocked(
      c,
      blocked: block,
      reason: reason.text.trim(),
    );
    if (context.mounted) {
      showMessage(
        context,
        err ?? (block ? 'Customer blocked' : 'Customer unblocked'),
        error: err != null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final pal = context.pal;
    CustomerProfile? found;
    for (final x in s.customers) {
      if (x.uid == uid) found = x;
    }
    if (found == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Customer not found',
        ),
      );
    }
    final cust = found;
    final b = balanceFor(uid, s.orders, s.ledger);
    final block = s.blocked[uid];
    final orders = s.orders.where((o) => o.customerId == uid).toList();
    final spent = orders
        .where((o) => o.status == OrderStatus.delivered)
        .fold(0, (n, o) => n + o.total);
    final entries = s.ledger.where((e) => e.customerId == uid).toList();
    final fmt = DateFormat('d MMM, h:mm a');
    final wa = whatsappNumber(cust.phone);

    Widget action(IconData icon, String title, String sub, LedgerKind kind) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: pal.card,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _ledger(context, cust, kind),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Brand.blueDark.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Brand.blueDark, size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            sub,
                            style: TextStyle(
                              color: pal.muted,
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.add_rounded),
                  ],
                ),
              ),
            ),
          ),
        );

    Widget heading(String t, [String? sub]) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                sub,
                style: TextStyle(color: pal.muted, height: 1.35, fontSize: 13),
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Customer')),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            // Who they are, and how to reach them.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: panel(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cust.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    prettyPhone(cust.phone),
                    style: TextStyle(color: pal.muted, fontSize: 15),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 46),
                          ),
                          onPressed: () => Launch.call(cust.phone),
                          icon: const Icon(Icons.call_rounded, size: 18),
                          label: const Text('Call'),
                        ),
                      ),
                      if (wa != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                            ),
                            onPressed: () => Launch.whatsapp(wa),
                            icon: const WhatsAppIcon(size: 20),
                            label: const Text('WhatsApp'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (block != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Brand.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Brand.radius),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.block_rounded, color: Brand.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Blocked${block.reason.isEmpty ? '' : ': ${block.reason}'}. They cannot place orders.',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // At a glance.
            heading('At a glance'),
            Row(
              children: [
                Expanded(
                  child: _Stat('Orders', '${orders.length}', Brand.blueDark),
                ),
                const SizedBox(width: 10),
                Expanded(child: _Stat('Delivered', rs(spent), Brand.success)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    'Empty cylinders owed',
                    '${b.emptiesOwed}',
                    b.emptiesOwed > 0 ? const Color(0xFFB45309) : Brand.success,
                    hint: b.emptiesOwed > 0
                        ? 'Still with the customer'
                        : 'All returned',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Stat(
                    'Deposit held',
                    rs(b.deposit),
                    Brand.blueDark,
                    hint: 'Money you hold for them',
                  ),
                ),
              ],
            ),

            // Changing their account.
            heading(
              'Update their account',
              'Empties from deliveries are counted automatically. Use these only when something changes outside an order.',
            ),
            action(
              Icons.savings_rounded,
              'Took a deposit',
              'The customer paid a cylinder deposit (Rs)',
              LedgerKind.deposit,
            ),
            action(
              Icons.undo_rounded,
              'Gave a deposit back',
              'You refunded their deposit (Rs)',
              LedgerKind.depositRefund,
            ),
            action(
              Icons.propane_tank_rounded,
              'Customer is keeping our empties',
              'Add cylinders they hold that are not from an order',
              LedgerKind.emptiesOwed,
            ),
            action(
              Icons.assignment_returned_rounded,
              'Customer returned empties',
              'They brought empty cylinders back',
              LedgerKind.emptiesReturned,
            ),
            if (entries.isNotEmpty) ...[
              heading('Account history'),
              for (final e in entries.take(15))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    e.kind == LedgerKind.deposit ||
                            e.kind == LedgerKind.emptiesOwed
                        ? Icons.arrow_circle_up_rounded
                        : Icons.arrow_circle_down_rounded,
                    color: pal.muted,
                  ),
                  title: Text(
                    '${e.kind.label} · ${e.kind == LedgerKind.deposit || e.kind == LedgerKind.depositRefund ? rs(e.amount) : '${e.empties} cylinder${e.empties == 1 ? '' : 's'}'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${e.at == null ? '' : fmt.format(e.at!.toLocal())}${e.note.isEmpty ? '' : ' · ${e.note}'}',
                  ),
                ),
            ],

            // Their orders.
            heading(
              'Orders',
              orders.isEmpty ? 'No orders yet.' : 'Tap an order to open it.',
            ),
            for (final o in orders.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: pal.card,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: s,
                          child: OrderDetailScreen(orderId: o.id),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o.displayNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${rs(o.total)} · ${o.createdAt == null ? '' : fmt.format(o.createdAt!.toLocal())}',
                                  style: TextStyle(
                                    color: pal.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusChip(o.status),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Block.
            heading(
              'Block this customer',
              block == null
                  ? 'Use this for fake or abusive customers. They will not be able to place orders until you unblock them.'
                  : 'They cannot place orders right now.',
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: block == null ? Brand.danger : null,
              ),
              onPressed: () => _block(context, cust, block == null),
              icon: Icon(
                block == null ? Icons.block_rounded : Icons.lock_open_rounded,
              ),
              label: Text(
                block == null ? 'Block customer' : 'Unblock customer',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color, {this.hint});
  final String label;
  final String value;
  final Color color;
  final String? hint;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(Brand.radius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        if (hint != null)
          Text(hint!, style: TextStyle(color: context.pal.muted, fontSize: 12)),
      ],
    ),
  );
}
