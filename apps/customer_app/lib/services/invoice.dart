import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Fonts, logo and cylinder pictures used in invoices (loaded once).
class InvoiceAssets {
  const InvoiceAssets({
    required this.regular,
    required this.bold,
    required this.logo,
    required this.logoWhite,
    required this.cylinders,
  });

  final pw.Font regular;
  final pw.Font bold;
  final pw.MemoryImage logo;
  final pw.MemoryImage logoWhite;

  /// Bundled cylinder pictures by asset path.
  final Map<String, pw.MemoryImage> cylinders;

  static const _cylinderAssets = [
    'assets/products/6kg.png',
    'assets/products/10kg.png',
    'assets/products/11_8kg.png',
    'assets/products/45_4kg.png',
  ];

  /// The bundled cylinder picture closest in size to [kg].
  pw.MemoryImage? cylinderFor(double kg) {
    const known = <(double, String)>[
      (6.0, 'assets/products/6kg.png'),
      (10.0, 'assets/products/10kg.png'),
      (11.8, 'assets/products/11_8kg.png'),
      (45.4, 'assets/products/45_4kg.png'),
    ];
    var best = known.first;
    for (final e in known) {
      if ((e.$1 - kg).abs() < (best.$1 - kg).abs()) best = e;
    }
    return cylinders[best.$2];
  }

  static InvoiceAssets? _cache;

  static pw.MemoryImage _img(ByteData d) =>
      pw.MemoryImage(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes));

  static Future<InvoiceAssets> load([AssetBundle? bundle]) async {
    if (_cache != null) return _cache!;
    final b = bundle ?? rootBundle;
    // Loaded one by one: Future.wait misbehaves with the SynchronousFutures
    // some asset bundles return.
    final regular = await b.load('assets/fonts/Inter-400.ttf');
    final bold = await b.load('assets/fonts/Inter-700.ttf');
    final logo = await b.load('assets/brand/logo.png');
    final white = await b.load('assets/brand/logo_white.png');
    final cylinders = <String, pw.MemoryImage>{};
    for (final path in _cylinderAssets) {
      try {
        cylinders[path] = _img(await b.load(path));
      } catch (_) {}
    }
    return _cache = InvoiceAssets(
      regular: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
      logo: _img(logo),
      logoWhite: _img(white),
      cylinders: cylinders,
    );
  }
}

const _navy = PdfColor.fromInt(0xFF0F2A3F);
const _blue = PdfColor.fromInt(0xFF1F7FC0);
const _muted = PdfColor.fromInt(0xFF61758A);
const _line = PdfColor.fromInt(0xFFE2E9F0);
const _tint = PdfColor.fromInt(0xFFEAF5FC);
const _green = PdfColor.fromInt(0xFF1E9E5A);
const _amber = PdfColor.fromInt(0xFF9A6B00);

String invoiceFileName(LpgOrder o) =>
    'Alpha-LPG-Invoice-${o.displayNumber.replaceAll('#', '')}.pdf';

/// "Evening 4pm–9pm" from the order notes ("Slot: ..." on the first line).
String? invoiceSlot(LpgOrder o) {
  if (o.scheduledFor == null) return null;
  final first = o.notes.split('\n').first;
  return first.startsWith('Slot: ') ? first.replaceFirst('Slot: ', '') : null;
}

/// A4 invoice / cash memo for an order.
Future<Uint8List> buildInvoicePdf(
  LpgOrder o,
  AppSettings s,
  InvoiceAssets a,
) async {
  final date = DateFormat('d MMM yyyy, h:mm a');
  final day = DateFormat('EEE d MMM yyyy');
  final paid = o.paymentStatus == PaymentStatus.paid;
  final cancelled = o.status == OrderStatus.cancelled;
  final doc = pw.Document(
    title: 'Invoice ${o.displayNumber}',
    author: 'Alpha LPG',
    theme: pw.ThemeData.withFont(base: a.regular, bold: a.bold),
  );

  pw.Widget label(String t) => pw.Text(
    t.toUpperCase(),
    style: pw.TextStyle(
      fontSize: 7.5,
      color: _muted,
      letterSpacing: 1.1,
      fontWeight: pw.FontWeight.bold,
    ),
  );

  pw.Widget card(String title, List<pw.Widget> children) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _tint,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [label(title), pw.SizedBox(height: 5), ...children],
      ),
    ),
  );

  pw.Widget strong(String t) => pw.Text(
    t,
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5),
  );
  pw.Widget small(String t) =>
      pw.Text(t, style: const pw.TextStyle(fontSize: 8.5, color: _muted));

  pw.Widget totalRow(String k, String v, {bool big = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            k,
            style: pw.TextStyle(
              fontSize: big ? 13 : 10,
              fontWeight: big ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.Text(
          v,
          style: pw.TextStyle(
            fontSize: big ? 14 : 10,
            fontWeight: big ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );

  pw.Widget headerCell(
    String t, {
    pw.Alignment? align,
    double? width,
    int flex = 1,
  }) {
    final cell = pw.Container(
      alignment: align ?? pw.Alignment.centerLeft,
      child: pw.Text(
        t,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 8.5,
        ),
      ),
    );
    return width != null
        ? pw.SizedBox(width: width, child: cell)
        : pw.Expanded(flex: flex, child: cell);
  }

  final slot = invoiceSlot(o);
  final deliveredAt = o.history
      .where((e) => e.status == OrderStatus.delivered)
      .map((e) => e.at)
      .fold<DateTime?>(null, (p, e) => p == null || e.isAfter(p) ? e : p);
  final stamp = cancelled
      ? ('CANCELLED', _muted)
      : paid
      ? ('PAID', _green)
      : ('PAYMENT DUE', _amber);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Brand band.
          pw.Container(
            color: _navy,
            padding: const pw.EdgeInsets.fromLTRB(40, 30, 40, 26),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Image(a.logoWhite, height: 50),
                pw.Spacer(),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 3,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      o.displayNumber,
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.white,
                      ),
                    ),
                    if (o.createdAt != null)
                      pw.Text(
                        date.format(o.createdAt!),
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColor.fromInt(0xFFB9CCDD),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          pw.Container(height: 4, color: _blue),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(40, 22, 40, 0),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Status stamp + shop line.
                pw.Row(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: pw.BoxDecoration(
                        color: stamp.$2,
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Text(
                        stamp.$1,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: small(
                        '${s.shopAddress}  ·  ${s.phone}  ·  ${s.email}',
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                // Bill to / Deliver to / Delivery.
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    card('Bill to', [
                      strong(o.customerName),
                      if (o.businessName.isNotEmpty) small(o.businessName),
                      small(o.customerPhone),
                    ]),
                    pw.SizedBox(width: 10),
                    card('Deliver to', [
                      strong(o.address.label),
                      small(o.address.oneLine),
                    ]),
                    pw.SizedBox(width: 10),
                    card('Delivery', [
                      strong(
                        deliveredAt != null
                            ? 'Delivered'
                            : o.scheduledFor != null
                            ? day.format(o.scheduledFor!)
                            : 'As soon as possible',
                      ),
                      if (deliveredAt != null)
                        small(date.format(deliveredAt))
                      else if (slot != null)
                        small(slot),
                      if (o.riderName != null) small('Rider: ${o.riderName}'),
                    ]),
                  ],
                ),
                pw.SizedBox(height: 20),
                // Items table with cylinder pictures.
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: const pw.BoxDecoration(
                    color: _navy,
                    borderRadius: pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(6),
                      topRight: pw.Radius.circular(6),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      headerCell('', width: 46),
                      headerCell('ITEM', flex: 5),
                      headerCell('QTY', width: 34, align: pw.Alignment.center),
                      headerCell(
                        'UNIT PRICE',
                        width: 78,
                        align: pw.Alignment.centerRight,
                      ),
                      headerCell(
                        'AMOUNT',
                        width: 78,
                        align: pw.Alignment.centerRight,
                      ),
                    ],
                  ),
                ),
                for (var n = 0; n < o.items.length; n++)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: pw.BoxDecoration(
                      color: n.isOdd ? _tint : PdfColors.white,
                      border: const pw.Border(
                        bottom: pw.BorderSide(color: _line),
                      ),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.SizedBox(
                          width: 46,
                          height: 44,
                          child: a.cylinderFor(o.items[n].sizeKg) == null
                              ? pw.SizedBox()
                              : pw.Image(
                                  a.cylinderFor(o.items[n].sizeKg)!,
                                  fit: pw.BoxFit.contain,
                                ),
                        ),
                        pw.Expanded(
                          flex: 5,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              strong(o.items[n].name),
                              small(o.items[n].type.label),
                            ],
                          ),
                        ),
                        pw.SizedBox(
                          width: 34,
                          child: pw.Center(
                            child: pw.Text(
                              '${o.items[n].quantity}',
                              style: const pw.TextStyle(fontSize: 10.5),
                            ),
                          ),
                        ),
                        pw.SizedBox(
                          width: 78,
                          child: pw.Text(
                            formatRupees(o.items[n].unitPrice),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.SizedBox(
                          width: 78,
                          child: pw.Text(
                            formatRupees(o.items[n].lineTotal),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              fontSize: 10.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                pw.SizedBox(height: 14),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    card('Payment', [
                      strong(o.paymentMethod.label),
                      small(
                        paid
                            ? 'Payment received'
                            : o.paymentMethod == PaymentMethod.cashOnDelivery
                            ? 'Pay the rider in cash on delivery'
                            : 'Waiting for payment confirmation',
                      ),
                      if (o.paymentReference.isNotEmpty)
                        small('Transaction ID: ${o.paymentReference}'),
                      if (o.emptiesToCollect > 0)
                        small(
                          'Refill: ${o.emptiesToCollect} empty cylinder(s) exchanged',
                        ),
                    ]),
                    pw.SizedBox(width: 24),
                    pw.SizedBox(
                      width: 210,
                      child: pw.Column(
                        children: [
                          totalRow('Subtotal', formatRupees(o.subtotal)),
                          totalRow(
                            'Delivery',
                            o.deliveryFee == 0
                                ? 'Free'
                                : formatRupees(o.deliveryFee),
                          ),
                          if (o.couponDiscount > 0)
                            totalRow(
                              'Discount (${o.couponCode})',
                              '- ${formatRupees(o.couponDiscount)}',
                            ),
                          if (o.pointsDiscount > 0)
                            totalRow(
                              'Points used (${o.pointsUsed})',
                              '- ${formatRupees(o.pointsDiscount)}',
                            ),
                          pw.Divider(color: _line),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: pw.BoxDecoration(
                              color: _navy,
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            child: pw.Row(
                              children: [
                                pw.Expanded(
                                  child: pw.Text(
                                    'TOTAL',
                                    style: pw.TextStyle(
                                      color: PdfColors.white,
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                pw.Text(
                                  formatRupees(o.total),
                                  style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (o.notes.isNotEmpty && !o.notes.startsWith('Slot: ')) ...[
                  pw.SizedBox(height: 12),
                  small('Note: ${o.notes.split('\n').last}'),
                ],
              ],
            ),
          ),
          pw.Spacer(),
          // Safety + thanks.
          pw.Container(
            color: _tint,
            padding: const pw.EdgeInsets.fromLTRB(40, 14, 40, 14),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Thank you for choosing Alpha LPG',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                          color: _navy,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Keep cylinders upright, in a ventilated place and away from flames. '
                        'If you smell gas: turn off the valve, open windows, do not switch anything on, '
                        'and call ${s.phone} or Rescue 1122.',
                        style: const pw.TextStyle(fontSize: 8, color: _muted),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Image(a.logo, height: 30),
              ],
            ),
          ),
          pw.Container(
            color: _blue,
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'alphalpg.pk  ·  This is a computer-generated invoice',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
            ),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
