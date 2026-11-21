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

/// Every customer: orders, empties owed, deposit held, and a block switch.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _q = '';
  bool _onlyOwing = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final q = _q.trim().toLowerCase();
    final rows = <(CustomerProfile, CustomerBalance, int)>[];
    for (final c in s.customers) {
      if (q.isNotEmpty &&
          !'${c.name} ${c.phone} ${c.businessName}'.toLowerCase().contains(q)) {
        continue;
      }
      final b = balanceFor(c.uid, s.orders, s.ledger);
      if (_onlyOwing && b.emptiesOwed == 0 && b.deposit == 0) continue;
      final count = s.orders.where((o) => o.customerId == c.uid).length;
      rows.add((c, b, count));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: Constrained(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(
                  hintText: 'Search name or phone',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Owes empties or has a deposit'),
                    selected: _onlyOwing,
                    onSelected: (v) => setState(() => _onlyOwing = v),
                  ),
                  const Spacer(),
                  Text(
                    '${rows.length} customers',
                    style: TextStyle(color: context.pal.muted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const EmptyState(
                      icon: Icons.people_alt_rounded,
                      title: 'No customers found',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final (c, b, count) = rows[i];
                        final isBlocked = s.blocked.containsKey(c.uid);
                        return Material(
                          color: context.pal.card,
                          borderRadius: BorderRadius.circular(Brand.radius),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(Brand.radius),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ChangeNotifierProvider.value(
                                  value: s,
                                  child: CustomerDetailScreen(uid: c.uid),
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isBlocked
                                        ? Brand.danger
                                        : Brand.blueDark,
                                    child: Icon(
                                      isBlocked
                                          ? Icons.block_rounded
                                          : Icons.person_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          '${prettyPhone(c.phone)} · $count orders',
                                          style: TextStyle(
                                            color: context.pal.muted,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (b.emptiesOwed > 0 ||
                                            b.deposit > 0 ||
                                            isBlocked)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
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
                                                if (b.emptiesOwed > 0)
                                                  Pill(
                                                    Icons.autorenew_rounded,
                                                    'Owes ${b.emptiesOwed} empty',
                                                    color: Brand.flame,
                                                  ),
                                                if (b.deposit > 0)
                                                  Pill(
                                                    Icons.savings_rounded,
                                                    'Deposit ${rs(b.deposit)}',
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
    CustomerProfile? c;
    for (final x in s.customers) {
      if (x.uid == uid) c = x;
    }
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Customer not found',
        ),
      );
    }
    final cust = c;
    final b = balanceFor(uid, s.orders, s.ledger);
    final block = s.blocked[uid];
    final orders = s.orders.where((o) => o.customerId == uid).toList();
    final spent = orders
        .where((o) => o.status == OrderStatus.delivered)
        .fold(0, (n, o) => n + o.total);
    final entries = s.ledger.where((e) => e.customerId == uid).toList();
    final fmt = DateFormat('d MMM, h:mm a');
    final wa = whatsappNumber(cust.phone);
    return Scaffold(
      appBar: AppBar(title: Text(cust.name)),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: panel(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cust.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${prettyPhone(cust.phone)} · ${orders.length} orders · ${rs(spent)} delivered',
                    style: TextStyle(color: context.pal.muted),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
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
                              minimumSize: const Size(0, 44),
                            ),
                            onPressed: () => Launch.whatsapp(wa),
                            icon: const Icon(Icons.chat_rounded, size: 18),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Brand.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Brand.radius),
                ),
                child: Text(
                  'Blocked${block.reason.isEmpty ? '' : ': ${block.reason}'}. They cannot place orders.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Cylinders and deposit',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    'Empties owed',
                    '${b.emptiesOwed}',
                    b.emptiesOwed > 0 ? Brand.flame : Brand.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Stat('Deposit held', rs(b.deposit), Brand.blueDark),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in LedgerKind.values)
                  ActionChip(
                    label: Text(k.label),
                    onPressed: () => _ledger(context, cust, k),
                  ),
              ],
            ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final e in entries.take(15))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${e.kind.label} · ${e.kind == LedgerKind.deposit || e.kind == LedgerKind.depositRefund ? rs(e.amount) : '${e.empties} cylinder(s)'}',
                  ),
                  subtitle: Text(
                    '${e.at == null ? '' : fmt.format(e.at!.toLocal())}${e.note.isEmpty ? '' : ' · ${e.note}'}',
                  ),
                ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Recent orders',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            if (orders.isEmpty)
              Text(
                'No orders yet.',
                style: TextStyle(color: context.pal.muted),
              ),
            for (final o in orders.take(10))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${o.displayNumber} · ${rs(o.total)}'),
                subtitle: Text(
                  '${o.status.label} · ${o.createdAt == null ? '' : fmt.format(o.createdAt!.toLocal())}',
                ),
              ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: block == null ? Brand.danger : null,
              ),
              onPressed: () => _block(context, cust, block == null),
              icon: Icon(
                block == null ? Icons.block_rounded : Icons.lock_open_rounded,
              ),
              label: Text(block == null ? 'Block this customer' : 'Unblock'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(Brand.radius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        Text(label, style: TextStyle(color: context.pal.muted, fontSize: 12)),
      ],
    ),
  );
}
