import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_customer/services/invoice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a valid PDF invoice for an order', () async {
    final order = LpgOrder(
      id: 'abc123',
      orderNumber: 'AL-000042',
      customerId: 'u1',
      customerName: 'Bilal Ahmed',
      customerPhone: '+923001234567',
      businessName: 'Lahore Grill',
      items: const [
        OrderItem(
          productId: 'cyl-45-4kg',
          name: '45.4kg Gas Cylinder',
          sizeKg: 45.4,
          type: PurchaseType.refill,
          unitPrice: 12682,
          quantity: 2,
        ),
      ],
      subtotal: 25364,
      deliveryFee: 0,
      total: 25364,
      address: const Address(
        label: 'Restaurant',
        line1: 'Shop 3, MM Alam Road',
        area: 'Gulberg',
      ),
      paymentMethod: PaymentMethod.jazzCash,
      paymentReference: 'TX12345',
      createdAt: DateTime(2026, 11, 20, 14, 30),
    );
    final bytes = await buildInvoicePdf(
      order,
      SeedData.settings,
      await InvoiceAssets.load(),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(10000));
    expect(invoiceFileName(order), 'Alpha-LPG-Invoice-AL-000042.pdf');
  });
}
