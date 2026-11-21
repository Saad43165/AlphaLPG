// Developer preview: runs the admin app on sample data in a browser, to check
// layouts. Not part of the release app (the APK uses lib/main.dart).
import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'services/admin_auth.dart';
import 'services/backend.dart';

class _Auth extends AdminAuth {
  @override
  String? get uid => 'boss';
  @override
  String? get email => 'owner@alphalpg.pk';
  @override
  Future<void> signIn(String e, String p) async {}
  @override
  Future<void> sendPasswordReset(String e) async {}
  @override
  Future<void> signOut() async {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = MemoryStore();
  final orders = OrderRepository.memory(store);
  final riders = RiderRepository.memory(store);
  final catalog = CatalogRepository.memory(store);
  await catalog.seed();
  await riders.saveRider(
    const RiderProfile(
      uid: 'r1',
      name: 'Imran Khan',
      phone: '+923005550001',
      online: true,
    ),
  );
  await riders.saveRider(
    const RiderProfile(uid: 'r2', name: 'Bilal Ahmed', phone: '+923005550002'),
  );
  LpgOrder o(
    String name,
    String phone,
    String area,
    int qty,
    PaymentMethod pay, {
    String ref = '',
  }) => LpgOrder(
    customerId: 'c-$name',
    customerName: name,
    customerPhone: phone,
    items: [
      OrderItem(
        productId: 'cyl-11-8kg',
        name: '11.8kg Gas Cylinder',
        sizeKg: 11.8,
        type: PurchaseType.refill,
        unitPrice: 3296,
        quantity: qty,
      ),
    ],
    subtotal: 3296 * qty,
    deliveryFee: 3296 * qty >= 6000 ? 0 : 150,
    total: 3296 * qty + (3296 * qty >= 6000 ? 0 : 150),
    paymentMethod: pay,
    paymentReference: ref,
    notes: 'Blue gate, ring the bell twice',
    address: Address(
      label: 'Home',
      line1: 'House 12-B, Main Boulevard',
      area: area,
      lat: 31.5204,
      lng: 74.3587,
    ),
  );
  final a = await orders.place(
    o(
      'Ali Raza',
      '+923001234567',
      'Gulberg III',
      2,
      PaymentMethod.cashOnDelivery,
    ),
  );
  final b = await orders.place(
    o(
      'Sara Café',
      '+923211234567',
      'DHA Phase 5',
      1,
      PaymentMethod.jazzCash,
      ref: 'TX9981234',
    ),
  );
  final c = await orders.place(
    o(
      'Bilal Ahmed',
      '+923331234567',
      'Johar Town',
      1,
      PaymentMethod.cashOnDelivery,
    ),
  );
  await orders.acceptOrder(
    c,
    riderId: 'r1',
    name: 'Imran Khan',
    phone: '+923005550001',
  );
  await orders.startDelivery(c, 'r1');
  await orders.markArrived(c, 'r1');
  await orders.publishRiderLocation(
    c,
    const RiderLocation(lat: 31.52, lng: 74.35, speedKmh: 22),
  );
  await orders.sendMessage(
    c,
    uid: 'c',
    role: MessageRole.customer,
    name: 'Bilal',
    text: 'Gate is open',
  );
  await orders.updateStatus(a, OrderStatus.confirmed, 'boss');
  b;
  runApp(
    AdminApp(
      backend: AdminBackend(
        auth: _Auth(),
        orders: orders,
        riders: riders,
        catalog: catalog,
        quotes: QuoteRepository.memory(store),
        profiles: ProfileRepository.memory(store),
        ops: OpsRepository.memory(store),
        watchIsAdmin: (_) => Stream.value(true),
        createRiderLogin: (e, p) async => 'x',
      ),
    ),
  );
}
