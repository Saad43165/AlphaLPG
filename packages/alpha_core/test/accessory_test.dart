import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final stove = SeedData.products.firstWhere(
    (p) => p.id == 'acc-germania-1burner',
  );
  final cyl = SeedData.products.first;

  OrderItem line(
    Product p, {
    PurchaseType t = PurchaseType.refill,
    int q = 1,
  }) => OrderItem(
    productId: p.id,
    name: p.name,
    sizeKg: p.sizeKg,
    type: t,
    unitPrice: p.priceFor(t),
    quantity: q,
  );

  test('seed has three accessories with a single price', () {
    final acc = SeedData.products.where((p) => p.isAccessory).toList();
    expect(acc, hasLength(3));
    for (final p in acc) {
      expect(p.sizeLabel, '');
      expect(p.sellsNewCylinder, isFalse);
      expect(p.refillPrice, greaterThan(0));
    }
  });

  test('accessories are not cylinders: no empties, no cylinder count', () {
    final items = [line(cyl, q: 2), line(stove, q: 3)];
    final price = PriceBreakdown.of(items, SeedData.settings);
    expect(price.cylinders, 2);
    expect(price.accessories, 3);
    expect(price.countLabel, '5 items');
    expect(price.problem(SeedData.settings), isNull);
  });

  test('an order of only a stove can be placed and needs no empty', () {
    final price = PriceBreakdown.of([line(stove)], SeedData.settings);
    expect(price.cylinders, 0);
    expect(price.problem(SeedData.settings), isNull);
    expect(line(stove).typeLabel, 'Accessory');
  });
}
