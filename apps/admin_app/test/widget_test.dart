import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_admin/app.dart';
import 'package:alpha_admin/services/admin_auth.dart';
import 'package:alpha_admin/services/backend.dart';
import 'dart:ui' show Size;
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets('owner sees a new order, confirms it and assigns a rider', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final b = _backend(store);
    await tester.runAsync(() async {
      await b.riders.saveRider(const RiderProfile(uid: 'r1', name: 'Imran', phone: '03001112222', online: true));
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

    final o = (await tester.runAsync(() => b.orders.watchRecent().first))!.single;
    expect(o.status, OrderStatus.assigned);
    expect(o.riderId, 'r1');

    await tester.tap(find.text('Mark paid'));
    await tester.pumpAndSettle();
    expect((await tester.runAsync(() => b.orders.watchRecent().first))!.single.paymentStatus, PaymentStatus.paid);
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
    expect((await tester.runAsync(() => b.catalog.watchAllProducts().first))!.length, 4);
    expect(find.text('11.8kg Gas Cylinder'), findsOneWidget);
  });
}
