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
  Repos(this.catalog, this.orders, this.profiles, this.quotes, this.riders);
  final CatalogRepository catalog;
  final OrderRepository orders;
  final ProfileRepository profiles;
  final QuoteRepository quotes;
  final RiderRepository riders;
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
        RiderRepository.firestore(db),
      );
    },
    'memory': () {
      final s = MemoryStore();
      return Repos(
        CatalogRepository.memory(s),
        OrderRepository.memory(s),
        ProfileRepository.memory(s),
        QuoteRepository.memory(s),
        RiderRepository.memory(s),
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

  test('delete my account removes profile and saved locations', () async {
    final repo = r.profiles;
    await repo.saveProfile(
      const CustomerProfile(uid: 'u9', name: 'Sara', phone: '+923001234567'),
      isNew: true,
    );
    await repo.saveAddress(
      'u9',
      const Address(label: 'Home', line1: '1', area: 'DHA'),
    );
    await repo.deleteAccountData('u9');
    expect(await repo.watchProfile('u9').first, isNull);
    expect(await repo.watchAddresses('u9').first, isEmpty);
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

  test(
    'riders: available list, first-come accept, start, complete with cash',
    () async {
      final orders = r.orders;
      final id = await orders.place(sampleOrder('u1'));
      final other = await orders.place(sampleOrder('u2'));

      var open = await orders.watchAvailable().first;
      expect(open.map((o) => o.id), containsAll([id, other]));

      expect(
        await orders.acceptOrder(
          id,
          riderId: 'r1',
          name: 'Imran',
          phone: '0300',
        ),
        isTrue,
      );
      // A second rider is too late.
      expect(
        await orders.acceptOrder(
          id,
          riderId: 'r2',
          name: 'Bilal',
          phone: '0301',
        ),
        isFalse,
      );

      open = await orders.watchAvailable().first;
      expect(open.map((o) => o.id), [
        other,
      ], reason: 'taken order is no longer available');

      var o = (await orders.watchOrder(id).first)!;
      expect(o.status, OrderStatus.assigned);
      expect(o.riderId, 'r1');
      expect((await orders.watchRiderOrders('r1').first).single.id, id);

      await orders.startDelivery(id, 'r1');
      expect(
        (await orders.watchOrder(id).first)!.status,
        OrderStatus.outForDelivery,
      );

      await orders.completeDelivery(
        id,
        'r1',
        cashCollected: 6592,
        emptiesCollected: 2,
      );
      o = (await orders.watchOrder(id).first)!;
      expect(o.status, OrderStatus.delivered);
      expect(o.cashCollected, 6592);
      expect(o.emptiesCollected, 2);
      expect(o.paymentStatus, PaymentStatus.paid);
      expect(o.history.map((e) => e.status), [
        OrderStatus.placed,
        OrderStatus.assigned,
        OrderStatus.outForDelivery,
        OrderStatus.delivered,
      ]);

      final history = await orders.watchRiderHistory('r1').first;
      expect(history.single.id, id);
      expect(await orders.watchRiderOrders('r1').first, isEmpty);
    },
  );

  test('rider arrives at the door, or hands a job back to the shop', () async {
    final orders = r.orders;
    final id = await orders.place(sampleOrder('u1'));
    await orders.acceptOrder(id, riderId: 'r1', name: 'Imran', phone: '0300');
    // Hand it back: open again, nobody assigned, another rider can take it.
    await orders.releaseJob(id, 'r1');
    var o = (await orders.watchOrder(id).first)!;
    expect(o.status, OrderStatus.confirmed);
    expect(o.riderId, isNull);
    expect(
      (await orders.watchAvailable().first).map((x) => x.id),
      contains(id),
    );
    expect(
      await orders.acceptOrder(id, riderId: 'r2', name: 'Bilal', phone: '0301'),
      isTrue,
    );
    await orders.startDelivery(id, 'r2');
    expect((await orders.watchOrder(id).first)!.arrivedAt, isNull);
    await orders.markArrived(id, 'r2');
    o = (await orders.watchOrder(id).first)!;
    expect(o.arrivedAt, isNotNull);
    expect(o.status, OrderStatus.outForDelivery);
  });

  test(
    'order chat: customer, rider and shop all see the same thread',
    () async {
      final id = await r.orders.place(sampleOrder('u1'));
      await r.orders.sendMessage(
        id,
        uid: 'u1',
        role: MessageRole.customer,
        name: 'Ali',
        text: ' Gate is blue ',
      );
      await r.orders.sendMessage(
        id,
        uid: 'r1',
        role: MessageRole.rider,
        name: 'Imran',
        text: 'On my way',
      );
      await r.orders.sendMessage(
        id,
        uid: 'boss',
        role: MessageRole.admin,
        name: 'Alpha LPG',
        text: 'Thanks!',
      );
      final thread = await r.orders.watchMessages(id).first;
      expect(thread.map((m) => m.text), [
        'Gate is blue',
        'On my way',
        'Thanks!',
      ]);
      expect(thread.map((m) => m.role), [
        MessageRole.customer,
        MessageRole.rider,
        MessageRole.admin,
      ]);
      expect(await r.orders.watchMessages('other').first, isEmpty);
    },
  );

  test(
    'presence: only riders who are online AND recently seen count as live',
    () async {
      final riders = r.riders;
      await riders.saveRider(
        const RiderProfile(uid: 'a', name: 'A', phone: '0300'),
      );
      await riders.saveRider(
        const RiderProfile(uid: 'b', name: 'B', phone: '0301'),
      );
      expect(await riders.watchLiveRiderCount().first, 0);
      await riders.setOnline('a', true);
      await riders.setOnline('b', true);
      expect(await riders.watchLiveRiderCount().first, 2);
      await riders.setOnline('b', false);
      expect(await riders.watchLiveRiderCount().first, 1);
      await riders.setActive('a', false); // blocked riders are off shift
      expect(await riders.watchLiveRiderCount().first, 0);
      await riders.setActive('a', true);
      await riders.setOnline('a', true);
      await riders.heartbeat('a');
      expect(
        (await riders.watchAllRiders().first)
            .firstWhere((x) => x.uid == 'a')
            .isLive(),
        isTrue,
      );
      expect(
        (await riders.watchAllRiders().first)
            .firstWhere((x) => x.uid == 'a')
            .isLive(DateTime.now().add(const Duration(minutes: 5))),
        isFalse,
        reason: 'a rider who stopped reporting in is not live',
      );
      await riders.deleteRider('b');
      expect((await riders.watchAllRiders().first).map((x) => x.uid), ['a']);
    },
  );

  test('admin takes an order back from a rider', () async {
    final id = await r.orders.place(sampleOrder('u1'));
    await r.orders.acceptOrder(id, riderId: 'r1', name: 'Imran', phone: '0300');
    await r.orders.unassignRider(id, 'boss');
    final o = (await r.orders.watchOrder(id).first)!;
    expect(o.status, OrderStatus.confirmed);
    expect(o.riderId, isNull);
    expect(o.history.last.note, 'Taken back from the rider');
  });

  test(
    'payment request from the shop and receipts from the customer',
    () async {
      final id = await r.orders.place(
        LpgOrder(
          customerId: 'u1',
          customerName: 'Ali',
          customerPhone: '+923001234567',
          items: sampleOrder('u1').items,
          subtotal: 6592,
          deliveryFee: 0,
          total: 6592,
          paymentMethod: PaymentMethod.jazzCash,
          address: const Address(label: 'Home', line1: '1', area: 'DHA'),
        ),
      );
      await r.orders.sendPaymentRequest(
        id,
        const PaymentRequest(
          method: PaymentMethod.easyPaisa,
          account: '03001234567',
          accountTitle: 'Alpha LPG',
          note: 'Send the receipt after paying',
          amount: 6592,
        ),
      );
      var o = (await r.orders.watchOrder(id).first)!;
      expect(o.paymentRequest!.method, PaymentMethod.easyPaisa);
      expect(o.paymentRequest!.account, '03001234567');
      expect(o.paymentRequest!.amount, 6592);
      expect(o.paymentRequest!.sentAt, isNotNull);
      expect(o.receiptAt, isNull);

      await r.orders.addReceipt(
        id,
        uid: 'u1',
        data: 'QUJD',
        note: 'from Easypaisa app',
      );
      await r.orders.setPaymentIssue(id, 'The receipt is not clear');
      o = (await r.orders.watchOrder(id).first)!;
      expect(o.receiptAt, isNotNull);
      expect(o.paymentIssue, 'The receipt is not clear');
      final receipts = await r.orders.watchReceipts(id).first;
      expect(receipts.single.data, 'QUJD');

      // A new receipt clears the problem the shop pointed out.
      await r.orders.addReceipt(id, uid: 'u1', data: 'REVG');
      o = (await r.orders.watchOrder(id).first)!;
      expect(o.paymentIssue, isEmpty);
      expect((await r.orders.watchReceipts(id).first).length, 2);
    },
  );

  test('delivery with money on a wallet order does not mark it paid', () async {
    final id = await r.orders.place(
      LpgOrder(
        customerId: 'u1',
        customerName: 'Ali',
        customerPhone: '+923001234567',
        items: sampleOrder('u1').items,
        subtotal: 100,
        deliveryFee: 0,
        total: 100,
        paymentMethod: PaymentMethod.easyPaisa,
        address: const Address(label: 'Home', line1: '1', area: 'DHA'),
      ),
    );
    await r.orders.completeDelivery(
      id,
      'r1',
      cashCollected: 100,
      emptiesCollected: 1,
      markPaid: false,
    );
    final o = (await r.orders.watchOrder(id).first)!;
    expect(o.status, OrderStatus.delivered);
    expect(o.cashCollected, 100);
    expect(o.paymentStatus, isNot(PaymentStatus.paid));
  });

  test('riders: a cancelled order cannot be accepted', () async {
    final id = await r.orders.place(sampleOrder('u1'));
    await r.orders.updateStatus(id, OrderStatus.cancelled, 'u1');
    expect(
      await r.orders.acceptOrder(id, riderId: 'r1', name: 'I', phone: '0'),
      isFalse,
    );
  });

  test('live tracking: rider position reaches the customer', () async {
    final id = await r.orders.place(sampleOrder('u1'));
    expect(await r.orders.watchRiderLocation(id).first, isNull);
    await r.orders.publishRiderLocation(
      id,
      const RiderLocation(
        lat: 31.5107,
        lng: 74.3445,
        heading: 90,
        speedKmh: 24,
        accuracy: 8,
      ),
    );
    final l = (await r.orders.watchRiderLocation(id).first)!;
    expect(l.lat, closeTo(31.5107, 1e-6));
    expect(l.speedKmh, 24);
    expect(l.isFresh(), isTrue);
    expect(l.isFresh(DateTime.now().add(const Duration(minutes: 5))), isFalse);
  });

  test('rider profile and shift switch', () async {
    await r.riders.saveRider(
      const RiderProfile(uid: 'r1', name: 'Imran', phone: '0300'),
    );
    var p = (await r.riders.watchRider('r1').first)!;
    expect(p.online, isFalse);
    await r.riders.setOnline('r1', true);
    p = (await r.riders.watchRider('r1').first)!;
    expect(p.online, isTrue);
    expect(await r.riders.watchRider('nobody').first, isNull);
  });
}

extension on Product {
  Product copyWithPrice(int price) =>
      Product.fromMap(id, {...toMap(), 'refillPrice': price});
}
