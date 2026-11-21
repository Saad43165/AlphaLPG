import 'dart:typed_data';

import 'package:alpha_core/alpha_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../services/invoice.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// In-app invoice preview with share / print, plus a direct "Share PDF"
/// action that works even where the preview cannot render.
class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({super.key, required this.order});
  final LpgOrder order;

  Future<Uint8List> _build(BuildContext context) async {
    final settings = context.read<AppState>().settings;
    return buildInvoicePdf(order, settings, await InvoiceAssets.load());
  }

  Future<void> _share(BuildContext context) async {
    try {
      final bytes = await _build(context);
      await Printing.sharePdf(bytes: bytes, filename: invoiceFileName(order));
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Could not share the invoice', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const ScreenBack(),
      title: Text('Invoice ${order.displayNumber}'),
      actions: [
        IconButton(
          tooltip: 'Share PDF',
          icon: const Icon(Icons.share_rounded),
          onPressed: () => _share(context),
        ),
      ],
    ),
    body: PdfPreview(
      build: (_) => _build(context),
      pdfFileName: invoiceFileName(order),
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      allowPrinting: true,
      allowSharing: true,
      loadingWidget: const CircularProgressIndicator(),
      onError: (context, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Preview is not available on this device.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _share(context),
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share invoice PDF'),
            ),
          ],
        ),
      ),
    ),
  );
}
