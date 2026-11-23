import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_test/flutter_test.dart';

OrderItem item(int price, int qty, [PurchaseType t = PurchaseType.refill]) =>
    OrderItem(
      productId: 'p$price',
      name: 'Cyl',
      sizeKg: 11.8,
      type: t,
      unitPrice: price,
      quantity: qty,
    );

void main() {
  const settings = AppSettings(deliveryFee: 150, freeDeliveryFrom: 6000);

  test('charges delivery below the free-delivery threshold', () {
    final p = PriceBreakdown.of([item(3296, 1)], settings);
    expect(p.subtotal, 3296);
    expect(p.deliveryFee, 150);
    expect(p.total, 3446);
  });

  test('delivery is free from the threshold upwards', () {
    final p = PriceBreakdown.of([item(3296, 2)], settings);
    expect(p.subtotal, 6592);
    expect(p.deliveryFee, 0);
    expect(p.total, 6592);
  });

  test('threshold 0 means delivery is never free', () {
    final p = PriceBreakdown.of([
      item(12682, 3),
    ], const AppSettings(deliveryFee: 200));
    expect(p.deliveryFee, 200);
  });

  test('problem() enforces closed shop, empty cart, max and minimum', () {
    expect(
      PriceBreakdown.of([], settings).problem(settings),
      'Your cart is empty.',
    );
    expect(
      PriceBreakdown.of(
        [item(100, 1)],
        const AppSettings(acceptingOrders: false),
      ).problem(const AppSettings(acceptingOrders: false)),
      contains('not taking online orders'),
    );
    expect(
      PriceBreakdown.of([item(100, 21)], settings).problem(settings),
      contains('bulk order'),
    );
    const minSettings = AppSettings(minOrderTotal: 2000);
    expect(
      PriceBreakdown.of([item(1676, 1)], minSettings).problem(minSettings),
      'Minimum order is Rs. 2,000.',
    );
    expect(
      PriceBreakdown.of([item(3296, 1)], settings).problem(settings),
      isNull,
    );
  });

  test('formatRupees groups thousands', () {
    expect(formatRupees(0), 'Rs. 0');
    expect(formatRupees(999), 'Rs. 999');
    expect(formatRupees(1676), 'Rs. 1,676');
    expect(formatRupees(12682), 'Rs. 12,682');
    expect(formatRupees(1234567), 'Rs. 1,234,567');
  });

  test('product price depends on purchase type', () {
    const p = Product(
      id: 'x',
      name: 'x',
      sizeKg: 11.8,
      refillPrice: 3296,
      newCylinderPrice: 9000,
    );
    expect(p.priceFor(PurchaseType.refill), 3296);
    expect(p.priceFor(PurchaseType.newCylinder), 9000);
    expect(p.sizeLabel, '11.8 KG');
    expect(SeedData.products.first.sizeLabel, '6 KG');
    expect(SeedData.products.first.sellsNewCylinder, isFalse);
  });

  test('seed catalogue matches alphalpg.pk prices', () {
    expect(
      {
        for (final p in SeedData.products.where((p) => !p.isAccessory))
          p.sizeLabel: p.refillPrice,
      },
      {'6 KG': 1676, '10 KG': 2793, '11.8 KG': 3296, '45.4 KG': 12682},
    );
  });
}
