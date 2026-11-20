import 'package:alpha_core/alpha_core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

LpgOrder sampleOrder(String uid) => LpgOrder(
  customerId: uid,
  customerName: 'Ali',
  customerPhone: '+923001234567',
  items: const [
    OrderItem(
      productId: 'cyl-11-8kg',
      name: '11.8kg Gas Cylinder',
      sizeKg: 11.8,
      type: PurchaseType.refill,
      unitPrice: 3296,
      quantity: 2,
    ),
  ],
  subtotal: 6592,
  deliveryFee: 0,
  total: 6592,
  address: const Address(label: 'Home', line1: '12-B', area: 'Gulberg'),
);

class Repos {
  Repos(this.catalog, this.orders, this.profiles, this.quotes);
  final CatalogRepository catalog;
  final OrderRepository orders;
  final ProfileRepository profiles;
  final QuoteRepository quotes;
}

void main() {
  final impls = <String, Repos Function()>{
    'firestore': () {
      final db = FakeFirebaseFirestore();
      return Repos(
        CatalogRepository.firestore(db),
        OrderRepository.firestore(db),
        ProfileRepository.firestore(db),
        QuoteRepository.firestore(db),
      );
    },
    'memory': () {
      final s = MemoryStore();
      return Repos(
        CatalogRepository.memory(s),
        OrderRepository.memory(s),
        ProfileRepository.memory(s),
        QuoteRepository.memory(s),
      );
    },
  };
  for (final MapEntry(key: name, value: make) in impls.entries) {
    group(name, () => _suite(make));
  }
}

void _suite(Repos Function() make) {
  late Repos r;
  setUp(() => r = make());

  test('catalog falls back to seed data, then reads Firestore', () async {
    final repo = r.catalog;
    expect((await repo.watchProducts().first).length, SeedData.products.length);
    expect(
      (await repo.watchSettings().first).deliveryFee,
      SeedData.settings.deliveryFee,
    );

    await repo.seed();
    await repo.saveProduct(SeedData.products.first.copyWithPrice(1700));
    final products = await repo.watchProducts().first;
    expect(products.first.refillPrice, 1700);
    expect(products.map((p) => p.sortOrder), [1, 2, 3, 4]);
  });

  test('order lifecycle: place → assign → deliver; history kept', () async {
    final repo = r.orders;
    final id = await repo.place(sampleOrder('u1'));

    var o = (await repo.watchOrder(id).first)!;
    expect(o.status, OrderStatus.placed);
    expect(o.orderNumber, startsWith('AL-'));
    expect(o.cylinderCount, 2);
    expect(o.emptiesToCollect, 2);
    expect(o.address.area, 'Gulberg');

    await repo.updateStatus(id, OrderStatus.confirmed, 'admin');
    await repo.assignRider(
      id,
      'admin',
      riderId: 'r1',
      name: 'Imran',
      phone: '0300',
    );
    await repo.updateStatus(id, OrderStatus.delivered, 'r1');

    o = (await repo.watchOrder(id).first)!;
    expect(o.status, OrderStatus.delivered);
    expect(o.riderName, 'Imran');
    expect(o.history.map((e) => e.status), [
      OrderStatus.placed,
      OrderStatus.confirmed,
      OrderStatus.assigned,
      OrderStatus.delivered,
    ]);
    expect(o.timeOf(OrderStatus.assigned), isNotNull);
    expect(o.canBeRated, isTrue);

    await repo.submitPaymentReference(id, ' 0123456789 ');
    o = (await repo.watchOrder(id).first)!;
    expect(o.paymentReference, '0123456789');

    await repo.rate(id, 5, 'Fast and polite rider');
    o = (await repo.watchOrder(id).first)!;
    expect(o.rating, 5);
    expect(o.feedback, 'Fast and polite rider');
    expect(o.canBeRated, isFalse);
  });

  test('customer sees only their own orders, newest first', () async {
    final repo = r.orders;
    await repo.place(sampleOrder('u1'));
    await repo.place(sampleOrder('u2'));
    await repo.place(sampleOrder('u1'));
    final mine = await repo.watchCustomerOrders('u1').first;
    expect(mine, hasLength(2));
    expect(mine.every((o) => o.customerId == 'u1'), isTrue);
  });

  test('cancel stores the reason', () async {
    final repo = r.orders;
    final id = await repo.place(sampleOrder('u1'));
    final o = (await repo.watchOrder(id).first)!;
    await repo.cancelByCustomer(o, 'Ordered by mistake');
    final c = (await repo.watchOrder(id).first)!;
    expect(c.status, OrderStatus.cancelled);
    expect(c.cancelReason, 'Ordered by mistake');
    expect(c.status.isActive, isFalse);
  });

  test('profiles and addresses round-trip', () async {
    final repo = r.profiles;
    await repo.saveProfile(
      const CustomerProfile(
        uid: 'u1',
        name: 'Sara',
        phone: '+923001234567',
        type: CustomerSegment.business,
        businessName: 'Sara Café',
      ),
      isNew: true,
    );
    final p = (await repo.watchProfile('u1').first)!;
    expect(p.isBusiness, isTrue);
    expect(p.displayName, 'Sara · Sara Café');

    final a = await repo.saveAddress(
      'u1',
      const Address(
        label: 'Shop',
        line1: 'Shop 1',
        area: 'DHA',
        lat: 31.5,
        lng: 74.3,
      ),
    );
    expect(a.id, isNotEmpty);
    final list = await repo.watchAddresses('u1').first;
    expect(list.single.hasLocation, isTrue);
    await repo.deleteAddress('u1', a.id);
    expect(await repo.watchAddresses('u1').first, isEmpty);
  });

  test('quote requests are stored as new', () async {
    final repo = r.quotes;
    await repo.submit(
      const QuoteRequest(
        customerId: 'u1',
        businessName: 'Lahore Grill',
        contactName: 'Bilal',
        phone: '+923001234567',
        businessType: 'Restaurant / Café',
        monthlyKg: 900,
      ),
    );
    final q = await repo.watchForCustomer('u1').first;
    expect(q.single.status, 'new');
    expect(q.single.monthlyKg, 900);
  });
}

extension on Product {
  Product copyWithPrice(int price) =>
      Product.fromMap(id, {...toMap(), 'refillPrice': price});
}
