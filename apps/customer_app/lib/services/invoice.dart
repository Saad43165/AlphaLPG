import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Fonts and logo used in invoices (loaded once from app assets).
class InvoiceAssets {
  const InvoiceAssets({
    required this.regular,
    required this.bold,
    required this.logo,
  });

  final pw.Font regular;
  final pw.Font bold;
  final pw.MemoryImage logo;

  static InvoiceAssets? _cache;

  static Future<InvoiceAssets> load([AssetBundle? bundle]) async {
    if (_cache != null) return _cache!;
    final b = bundle ?? rootBundle;
    // Loaded one by one: Future.wait misbehaves with the SynchronousFutures
    // some asset bundles return.
    final regular = await b.load('assets/fonts/Inter-400.ttf');
    final bold = await b.load('assets/fonts/Inter-700.ttf');
    final logo = await b.load('assets/brand/logo.png');
    return _cache = InvoiceAssets(
      regular: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
      logo: pw.MemoryImage(
        logo.buffer.asUint8List(logo.offsetInBytes, logo.lengthInBytes),
      ),
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

/// A4 invoice / cash memo for an order.
Future<Uint8List> buildInvoicePdf(
  LpgOrder o,
  AppSettings s,
  InvoiceAssets a,
) async {
  final date = DateFormat('d MMM yyyy, h:mm a');
  final paid = o.paymentStatus == PaymentStatus.paid;
  final doc = pw.Document(
    title: 'Invoice ${o.displayNumber}',
    author: 'Alpha LPG',
    theme: pw.ThemeData.withFont(base: a.regular, bold: a.bold),
  );

  pw.Widget label(String t) => pw.Text(
    t.toUpperCase(),
    style: const pw.TextStyle(fontSize: 8, color: _muted, letterSpacing: 1),
  );

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
            fontSize: big ? 13 : 10,
            fontWeight: big ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Image(a.logo, height: 54),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    o.displayNumber,
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  if (o.createdAt != null)
                    pw.Text(
                      date.format(o.createdAt!),
                      style: const pw.TextStyle(fontSize: 9, color: _muted),
                    ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: pw.BoxDecoration(
                      color: paid ? _green : _amber,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      paid ? 'PAID' : 'PAYMENT DUE',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          // From / Bill to / Deliver to
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    label('From'),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Alpha LPG',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      s.shopAddress,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      '${s.phone} · ${s.email}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    label('Bill to'),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      o.customerName,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    if (o.businessName.isNotEmpty)
                      pw.Text(
                        o.businessName,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    pw.Text(
                      o.customerPhone,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    label('Deliver to'),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      o.address.label,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      o.address.oneLine,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          // Items
          pw.TableHelper.fromTextArray(
            headers: ['Item', 'Type', 'Qty', 'Unit price', 'Amount'],
            data: [
              for (final i in o.items)
                [
                  i.name,
                  i.type.label,
                  '${i.quantity}',
                  formatRupees(i.unitPrice),
                  formatRupees(i.lineTotal),
                ],
            ],
            border: null,
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            headerDecoration: const pw.BoxDecoration(color: _navy),
            cellStyle: const pw.TextStyle(fontSize: 10),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _line)),
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.4),
              2: const pw.FlexColumnWidth(0.7),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
            },
            cellAlignments: {
              2: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
            headerAlignments: {
              2: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: _tint,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      label('Payment'),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        o.paymentMethod.label,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      if (o.paymentReference.isNotEmpty)
                        pw.Text(
                          'Transaction ID: ${o.paymentReference}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      if (o.emptiesToCollect > 0) ...[
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'Refill pricing: ${o.emptiesToCollect} empty cylinder(s) exchanged.',
                          style: const pw.TextStyle(fontSize: 9, color: _muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 24),
              pw.SizedBox(
                width: 200,
                child: pw.Column(
                  children: [
                    totalRow('Subtotal', formatRupees(o.subtotal)),
                    totalRow(
                      'Delivery',
                      o.deliveryFee == 0 ? 'Free' : formatRupees(o.deliveryFee),
                    ),
                    pw.Divider(color: _line),
                    totalRow('Total', formatRupees(o.total), big: true),
                  ],
                ),
              ),
            ],
          ),
          pw.Spacer(),
          pw.Divider(color: _line),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Thank you for choosing Alpha LPG. Keep cylinders upright and in a ventilated place. '
                  'If you smell gas, turn off the valve, open windows and call ${s.phone} or Rescue 1122.',
                  style: const pw.TextStyle(fontSize: 8, color: _muted),
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Text(
                'alphalpg.pk',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: _blue,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
