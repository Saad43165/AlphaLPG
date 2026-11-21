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
}
