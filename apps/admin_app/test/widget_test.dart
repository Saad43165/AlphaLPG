import 'dart:async';
import 'dart:typed_data';

import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_admin/app.dart';
import 'package:alpha_admin/services/admin_auth.dart';
import 'package:alpha_admin/services/backend.dart';

import 'dart:ui' show Size;
import 'dart:convert';

import 'package:alpha_admin/utils/photo.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/widgets.dart' show Brightness;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show Switch, Size, Scrollable, TextField;

class FakeAuth extends AdminAuth {
  @override
  String? uid = 'boss';
  @override
  String? get email => 'boss@alphalpg.pk';
  @override
  Future<void> signIn(String e, String p) async {}
  @override
  Future<void> sendPasswordReset(String e) async {}
  @override
  Future<void> signOut() async {
    uid = null;
    notifyListeners();
  }
}

LpgOrder _order() => LpgOrder(
  customerId: 'c1',
  customerName: 'Ali Raza',
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
  paymentMethod: PaymentMethod.jazzCash,
  paymentReference: 'TX123456',
);

AdminBackend _backend(MemoryStore s, {bool admin = true}) => AdminBackend(
  auth: FakeAuth(),
  orders: OrderRepository.memory(s),
  riders: RiderRepository.memory(s),
  catalog: CatalogRepository.memory(s),
  quotes: QuoteRepository.memory(s),
  profiles: ProfileRepository.memory(s),
  ops: OpsRepository.memory(s),
  promo: PromoRepository.memory(s),
  watchIsAdmin: (_) => Stream.value(admin),
  createRiderLogin: (e, p) async => 'new-rider',
);

void main() {
  testWidgets('owner sees a new order, confirms it and assigns a rider', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final b = _backend(store);
    await tester.runAsync(() async {
      await b.riders.saveRider(
        const RiderProfile(
          uid: 'r1',
          name: 'Imran',
          phone: '03001112222',
          online: true,
        ),
      );
      await b.riders.setOnline('r1', true);
      await b.orders.place(_order());
    });

    await tester.pumpWidget(AdminApp(backend: b));
    await tester.pumpAndSettle();

    expect(find.text('Ali Raza'), findsOneWidget);
    await tester.tap(find.text('Ali Raza'));
    await tester.pumpAndSettle();
    expect(find.text('TX123456'), findsOneWidget);

    await tester.tap(find.text('Confirm order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign rider'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Imran'));
    await tester.pumpAndSettle();

    final o = (await tester.runAsync(() => b.orders.watchRecent().first))!
        .single;
    expect(o.status, OrderStatus.assigned);
    expect(o.riderId, 'r1');

    await tester.tap(find.text('Mark paid'));
    await tester.pumpAndSettle();
    expect(
      (await tester.runAsync(() => b.orders.watchRecent().first))!
          .single
          .paymentStatus,
      PaymentStatus.paid,
    );
  });

  testWidgets('owner sends payment details and flags a receipt problem', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final b = _backend(store);
    late String id;
    await tester.runAsync(() async {
      id = await b.orders.place(_order());
    });
    await tester.pumpWidget(AdminApp(backend: b));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ali Raza'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Send payment details to customer'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Send payment details to customer'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Account number'),
      '03001234567',
    );
    await tester.pump();
    await tester.tap(find.text('Send to customer'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final o = (await b.orders.watchOrder(id).first)!;
      expect(o.paymentRequest!.account, '03001234567');
      expect(o.paymentRequest!.method, PaymentMethod.jazzCash);
      expect(o.paymentRequest!.amount, 6592);
      await b.orders.addReceipt(
        id,
        uid: 'c1',
        data: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      );
    });
    await tester.pumpAndSettle();
    expect(find.text('Receipt from customer'), findsOneWidget);
    expect(find.text('Receipt problem'), findsOneWidget);
  });

  testWidgets('owner answers a bulk quote inside the app', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final b = _backend(store);
    await tester.runAsync(
      () => b.quotes.submit(
        const QuoteRequest(
          customerId: 'c1',
          businessName: 'Salt n Pepper',
          contactName: 'Bilal',
          phone: '+923001234567',
          businessType: 'Restaurant / Café',
          monthlyKg: 300,
          preferredSize: '5 cylinders',
        ),
      ),
    );
    await tester.pumpWidget(AdminApp(backend: b));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Business quotes'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Business quotes'));
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp'), findsOneWidget);
    await tester.tap(find.text('Send details'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Rate: Rs 9,800 per cylinder',
    );
    await tester.tap(find.text('Send in the app'));
    await tester.pumpAndSettle();
    final q = (await tester.runAsync(() => b.quotes.watchAll().first))!.single;
    expect(q.reply, 'Rate: Rs 9,800 per cylinder');
    expect(q.status, 'contacted');
    expect(find.text('Send again'), findsOneWidget);
  });

  testWidgets(
    'delivered orders earn points, spent points are taken off, ratings go public',
    (tester) async {
      final store = MemoryStore();
      final b = _backend(store);
      await tester.runAsync(() async {
        await b.catalog.saveSettings(
          AppSettings.fromMap({...SeedData.settings.toMap(), 'pointsSince': 1}),
        );
        final id = await b.orders.place(_order());
        await b.orders.updateStatus(id, OrderStatus.delivered, 'r1');
        await b.orders.rate(id, 5, 'Fast');
      });
      await tester.pumpWidget(AdminApp(backend: b));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      // Rs. 6,592 at 2 points per Rs. 100.
      final l = (await tester.runAsync(
        () => b.promo.watchLoyalty('c1').first,
      ))!;
      expect(l.points, 130);
      final stats = (await tester.runAsync(() => b.promo.watchStats().first))!;
      expect(stats.ratingCount, 1);
      expect(stats.ratingAverage, 5);
      expect(stats.deliveredCount, 1);
    },
  );

  testWidgets('owner makes a coupon and a customer-ready code is saved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final b = _backend(store);
    await tester.pumpWidget(AdminApp(backend: b));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coupons and rewards'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New coupon'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'welcome200');
    await tester.enterText(find.byType(TextField).at(1), '200');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final c = (await tester.runAsync(() => b.promo.findCoupon('WELCOME200')))!;
    expect(c.value, 200);
    expect(c.percent, isFalse);
    expect(find.text('WELCOME200'), findsOneWidget);
  });

  testWidgets('owner opens a customer, records a deposit and blocks them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final b = _backend(store);
    await tester.runAsync(() async {
      await b.profiles.saveProfile(
        const CustomerProfile(
          uid: 'c1',
          name: 'Ali Raza',
          phone: '+923001234567',
        ),
        isNew: true,
      );
    });
    await tester.pumpWidget(AdminApp(backend: b));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customers'));
    await tester.pumpAndSettle();
    expect(find.text('Ali Raza'), findsOneWidget);
    await tester.tap(find.text('Ali Raza'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Took a deposit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount (Rs)'),
      '4000',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rs 4,000'), findsWidgets);

    await tester.tap(find.text('Block customer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      expect(await b.profiles.watchBlocked('c1').first, isNotNull);
      final ledger = await b.ops.watchLedger().first;
      expect(ledger.single.amount, 4000);
      final audit = await b.ops.watchAudit().first;
      expect(
        audit.map((e) => e.action),
        containsAll(['Deposit taken', 'Blocked customer']),
      );
    });
  });

  testWidgets('cash handover: rider owes cash until the owner receives it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final b = _backend(store);
    await tester.runAsync(() async {
      await b.riders.saveRider(
        const RiderProfile(
          uid: 'r1',
          name: 'Imran',
          phone: '03001112222',
          online: true,
        ),
      );
      final id = await b.orders.place(_order());
      await b.orders.assignRider(
        id,
        'boss',
        riderId: 'r1',
        name: 'Imran',
        phone: '03001112222',
      );
      await b.orders.updateStatus(id, OrderStatus.outForDelivery, 'r1');
      await b.orders.completeDelivery(
        id,
        'r1',
        cashCollected: 6592,
        emptiesCollected: 2,
      );
    });
    await tester.pumpWidget(AdminApp(backend: b));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash handover'));
    await tester.pumpAndSettle();
    expect(find.text('Rs 6,592'), findsWidgets);
    await tester.tap(find.text('Receive cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Rs 0'), findsWidgets);
    await tester.runAsync(() async {
      final h = await b.ops.watchHandovers().first;
      expect(h.single.amount, 6592);
    });
  });

  testWidgets('take back works only before the rider is on the way', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final b = _backend(store);
    late String id;
    await tester.runAsync(() async {
      id = await b.orders.place(_order());
      await b.orders.assignRider(
        id,
        'boss',
        riderId: 'r1',
        name: 'Imran',
        phone: '0300',
      );
    });
    await tester.pumpWidget(AdminApp(backend: b));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In progress · 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ali Raza'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Take back from rider'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Take back from rider'), findsOneWidget);

    // The rider leaves: the button is gone.
    await tester.runAsync(() async {
      await b.orders.updateStatus(id, OrderStatus.outForDelivery, 'r1');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('Take back from rider'), findsNothing);
  });

  testWidgets('a non-admin account is told how to become one', (tester) async {
    final b = _backend(MemoryStore(), admin: false);
    await tester.pumpWidget(AdminApp(backend: b));
    await tester.pumpAndSettle();
    expect(find.text('This account is not an admin yet'), findsOneWidget);
    expect(find.text('boss'), findsOneWidget);
  });

  testWidgets('empty shop offers to load the catalogue', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final b = _backend(MemoryStore());
    await tester.pumpWidget(AdminApp(backend: b));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load the default catalogue'));
    await tester.pumpAndSettle();
    expect(
      (await tester.runAsync(() => b.catalog.watchAllProducts().first))!.length,
      4,
    );
    expect(find.text('11.8kg Gas Cylinder'), findsOneWidget);
  });

  test(
    'photos are shrunk to a small record-friendly size, transparency kept',
    () async {
      final big = img.Image(width: 1800, height: 1400, numChannels: 4);
      img.fill(big, color: img.ColorRgba8(220, 40, 30, 255));
      final data = await compressProductPhoto(img.encodePng(big));
      final bytes = base64Decode(data);
      expect(bytes.length, lessThan(300 * 1024));
      final out = img.decodeImage(bytes)!;
      expect(out.width, lessThanOrEqualTo(520));
      expect(out.hasAlpha, isTrue);
      await expectLater(
        compressProductPhoto(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<String>()),
      );
    },
  );

  test('a new size without a photo gets the closest bundled picture', () {
    const p = Product(id: 'x', name: '14kg', sizeKg: 14, refillPrice: 1);
    expect(p.hasUploadedImage, isFalse);
    expect(p.automaticImageAsset, 'assets/products/11_8kg.png');
    expect(
      const Product(
        id: 'y',
        name: '50',
        sizeKg: 48,
        refillPrice: 1,
      ).automaticImageAsset,
      'assets/products/45_4kg.png',
    );
  });

  testWidgets('sales report totals delivered orders', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final b = _backend(store);
    await tester.runAsync(() async {
      final id = await b.orders.place(_order());
      await b.orders.updateStatus(id, OrderStatus.delivered, 'boss');
    });
    await tester.pumpWidget(AdminApp(backend: b));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sales & cash report'));
    await tester.pumpAndSettle();
    expect(find.text('Rs 6,592'), findsWidgets);
    expect(find.text('Orders delivered'), findsOneWidget);
  });

  testWidgets('the owner closes the shop and ends a rider\'s shift', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final b = _backend(store);
    await tester.runAsync(() async {
      await b.catalog.seed();
      await b.riders.saveRider(
        const RiderProfile(uid: 'r1', name: 'Imran', phone: '03001112222'),
      );
      await b.riders.setOnline('r1', true);
    });
    await tester.pumpWidget(AdminApp(backend: b));
    await tester.pumpAndSettle();
    expect(find.text('Shop is open'), findsOneWidget);
    expect(find.textContaining('1 rider on shift'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close shop'));
    await tester.pumpAndSettle();
    final settings = await tester.runAsync(
      () => b.catalog.watchStoredSettings().first,
    );
    expect(settings!.acceptingOrders, isFalse);
    expect(find.text('Shop is closed'), findsWidgets);

    await tester.tap(find.text('Riders'));
    await tester.pumpAndSettle();
    expect(find.textContaining('On shift'), findsWidgets);
    await tester.tap(find.byTooltip('Rider options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch offline'));
    await tester.pumpAndSettle();
    var riders = await tester.runAsync(() => b.riders.watchAllRiders().first);
    expect(riders!.single.online, isFalse);
    // ... and the shop can put them back on shift with the switch.
    expect(find.text('Off shift'), findsOneWidget);
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    riders = await tester.runAsync(() => b.riders.watchAllRiders().first);
    expect(riders!.single.online, isTrue);
    // A blocked rider gets a clear Unblock button.
    await tester.tap(find.byTooltip('Rider options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block rider'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    expect(find.text('Unblock this rider'), findsOneWidget);
    await tester.tap(find.text('Unblock this rider'));
    await tester.pumpAndSettle();
    riders = await tester.runAsync(() => b.riders.watchAllRiders().first);
    expect(riders!.single.active, isTrue);
  });

  testWidgets(
    'a customer message shows as unread on the order; opening the chat clears it',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = MemoryStore();
      final b = _backend(store);
      late String id;
      await tester.runAsync(() async {
        id = await b.orders.place(_order());
      });
      await tester.pumpWidget(AdminApp(backend: b));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await b.orders.sendMessage(
          id,
          uid: 'c1',
          role: MessageRole.customer,
          name: 'Ali Raza',
          text: 'Please call me',
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await tester.pumpAndSettle();
      expect(find.text('1 new'), findsOneWidget);
      await tester.tap(find.text('Ali Raza'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chat (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Please call me'), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pumpAndSettle();
      final reads = await tester.runAsync(
        () => b.orders.watchChatReads(id).first,
      );
      expect(reads!.containsKey(MessageRole.admin), isTrue);
    },
  );

  for (final dark in [false, true]) {
    testWidgets('admin screens at large text, ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      final store = MemoryStore();
      final b = _backend(store);
      await tester.runAsync(() async {
        await b.riders.saveRider(
          const RiderProfile(
            uid: 'r1',
            name: 'Imran Khan',
            phone: '03001112222',
            online: true,
          ),
        );
        await b.profiles.saveProfile(
          const CustomerProfile(
            uid: 'c1',
            name: 'Ali Raza',
            phone: '+923001234567',
          ),
          isNew: true,
        );
        final id = await b.orders.place(_order());
        await b.orders.sendPaymentRequest(
          id,
          const PaymentRequest(
            method: PaymentMethod.jazzCash,
            account: '03001234567',
            accountTitle: 'Alpha LPG',
            amount: 6592,
          ),
        );
        await b.orders.submitPayment(
          id,
          uid: 'c1',
          reference: 'TX99',
          amount: 5000,
        );
        await b.orders.addReport(
          const OrderReport(
            orderId: 'x',
            orderNumber: 'AL-1',
            customerId: 'c1',
            customerName: 'Ali Raza',
            customerPhone: '+923001234567',
            reason: 'Rider behaviour',
            details: 'Rude',
          ),
        );
      });
      await tester.pumpWidget(AdminApp(backend: b));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'orders');
      await tester.tap(find.text('Ali Raza').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'order detail');
      await tester.pageBack();
      await tester.pumpAndSettle();
      for (final tab in ['Riders', 'Shop', 'More']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
      for (final item in [
        'Reports and problems',
        'Customers',
        'Cash handover',
        'Sales & cash report',
        'Team and activity log',
        'App errors',
      ]) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(item),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(item));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: item);
        if (item == 'Customers') {
          await tester.tap(find.text('Ali Raza').first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'customer detail');
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets('with points switched off nothing is awarded', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final b = _backend(MemoryStore());
    await tester.runAsync(() async {
      final id = await b.orders.place(_order());
      await b.orders.updateStatus(id, OrderStatus.delivered, 'r1');
    });
    await tester.pumpWidget(AdminApp(backend: b));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final l = (await tester.runAsync(() => b.promo.watchLoyalty('c1').first))!;
    expect(l.points, 0);
  });

  testWidgets(
    'a scheduled order waits under Scheduled and says when it is due',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final b = _backend(MemoryStore());
      final day = DateTime.now().add(const Duration(days: 2));
      await tester.runAsync(() async {
        final id = await b.orders.place(
          LpgOrder(
            customerId: 'c1',
            customerName: 'Ali Raza',
            customerPhone: '+923001234567',
            items: const [
              OrderItem(
                productId: 'cyl-11-8kg',
                name: '11.8kg Gas Cylinder',
                sizeKg: 11.8,
                type: PurchaseType.refill,
                unitPrice: 3296,
                quantity: 1,
              ),
            ],
            subtotal: 3296,
            deliveryFee: 150,
            total: 3446,
            address: const Address(
              label: 'Home',
              line1: '12-B',
              area: 'Gulberg',
            ),
            scheduledFor: DateTime(day.year, day.month, day.day, 12),
            notes: 'Slot: Afternoon 12pm–4pm\nCall at the gate',
          ),
        );
        await b.orders.updateStatus(id, OrderStatus.confirmed, 'boss');
      });
      await tester.pumpWidget(AdminApp(backend: b));
      await tester.pumpAndSettle();
      // Not in progress yet: it is for the day after tomorrow.
      await tester.tap(find.text('In progress'));
      await tester.pumpAndSettle();
      expect(find.text('Ali Raza'), findsNothing);
      await tester.tap(find.textContaining('Scheduled · 1'));
      await tester.pumpAndSettle();
      expect(find.text('Ali Raza'), findsOneWidget);
      expect(find.textContaining('Afternoon 12pm–4pm'), findsOneWidget);
      await tester.tap(find.text('Ali Raza'));
      await tester.pumpAndSettle();
      expect(find.text('SCHEDULED DELIVERY'), findsOneWidget);
      expect(
        find.textContaining('Confirmed: send a rider on the day'),
        findsOneWidget,
      );
      // The automatic slot line is not repeated in the notes.
      expect(find.text('Call at the gate'), findsOneWidget);
      expect(find.text('Slot: Afternoon 12pm–4pm'), findsNothing);
    },
  );
}
