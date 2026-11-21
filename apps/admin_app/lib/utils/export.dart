import 'dart:convert';
import 'dart:typed_data';

import 'package:alpha_core/alpha_core.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

String _csv(String v) {
  final needsQuote = v.contains(',') || v.contains('"') || v.contains('\n');
  final safe = v.replaceAll('"', '""');
  return needsQuote ? '"$safe"' : safe;
}

/// One line per order, opens in Excel / Google Sheets.
String ordersCsv(Iterable<LpgOrder> orders) {
  final d = DateFormat('yyyy-MM-dd HH:mm');
  final rows = <List<String>>[
    [
      'Order',
      'Date',
      'Status',
      'Customer',
      'Phone',
      'Area',
      'Address',
      'Items',
      'Subtotal',
      'Delivery',
      'Total',
      'Payment',
      'Paid',
      'Transaction ID',
      'Amount customer sent',
      'Rider',
      'Cash collected',
      'Empties collected',
    ],
    for (final o in orders)
      [
        o.displayNumber,
        o.createdAt == null ? '' : d.format(o.createdAt!.toLocal()),
        o.status.label,
        o.customerName,
        o.customerPhone,
        o.address.area,
        o.address.oneLine,
        o.items
            .map((i) => '${i.quantity}x ${i.name} (${i.type.label})')
            .join('; '),
        '${o.subtotal}',
        '${o.deliveryFee}',
        '${o.total}',
        o.paymentMethod.label,
        o.paymentStatus == PaymentStatus.paid ? 'Yes' : 'No',
        o.paymentReference,
        '${o.paidAmount ?? ''}',
        o.riderName ?? '',
        '${o.cashCollected ?? ''}',
        '${o.emptiesCollected ?? ''}',
      ],
  ];
  return '﻿${rows.map((r) => r.map(_csv).join(',')).join('\n')}';
}

/// Everything the admin app has loaded, as one JSON file (a manual backup).
String backupJson({
  required List<LpgOrder> orders,
  required List<CustomerProfile> customers,
  required List<RiderProfile> riders,
  required List<Product> products,
  required AppSettings settings,
  required List<LedgerEntry> ledger,
  required List<CashHandover> handovers,
}) {
  Object? enc(Object? o) => o is DateTime ? o.toIso8601String() : '$o';
  return JsonEncoder.withIndent(' ', enc).convert({
    'exportedAt': DateTime.now(),
    'settings': settings.toMap(),
    'products': [
      for (final p in products) {'id': p.id, ...p.toMap()..remove('imageData')},
    ],
    'orders': [
      for (final o in orders)
        {'id': o.id, 'orderNumber': o.orderNumber, ...o.toMap()},
    ],
    'customers': [
      for (final c in customers) {'id': c.uid, ...c.toMap()},
    ],
    'riders': [
      for (final r in riders) {'id': r.uid, ...r.toMap()},
    ],
    'ledger': [
      for (final e in ledger) {'id': e.id, ...e.toMap(), 'at': e.at},
    ],
    'handovers': [
      for (final h in handovers) {'id': h.id, ...h.toMap(), 'at': h.at},
    ],
  });
}

Future<void> shareBytes(
  Uint8List bytes, {
  required String name,
  required String mime,
}) => SharePlus.instance.share(
  ShareParams(
    files: [XFile.fromData(bytes, mimeType: mime)],
    fileNameOverrides: [name],
    subject: name,
  ),
);
