import 'package:alpha_core/alpha_core.dart';

import 'backend.dart';
import 'location_tracker.dart';
import 'rider_auth.dart';

/// `--dart-define=DEMO=true`: runs the rider app on a throw-away in-memory
/// database with sample jobs, so it can be tried with no Firebase at all.
/// Nothing is saved, and nothing here is used by real builds.
const kDemo = bool.fromEnvironment('DEMO');

const demoEmail = 'rider@demo.alphalpg';

class _DemoAuth extends RiderAuth {
  String? _uid;

  @override
  String? get uid => _uid;
  @override
  String? get email => _uid == null ? null : demoEmail;

  @override
  Future<void> signIn(String email, String password) async {
    _uid = 'demo-rider';
    notifyListeners();
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {
    _uid = null;
    notifyListeners();
  }
}

Future<RiderBackend> buildDemoBackend() async {
  final store = MemoryStore();
  final orders = OrderRepository.memory(store);
  final riders = RiderRepository.memory(store);
  await riders.saveRider(
    const RiderProfile(
      uid: 'demo-rider',
      name: 'Demo Rider',
      phone: '+923000000000',
    ),
  );
  OrderItem item(String id, String name, double kg, int price, int qty) =>
      OrderItem(
        productId: id,
        name: name,
        sizeKg: kg,
        type: PurchaseType.refill,
        unitPrice: price,
        quantity: qty,
      );
  Future<void> job(
    String customer,
    String phone,
    String area,
    String line,
    double lat,
    double lng,
    OrderItem it,
    PaymentMethod pay,
  ) => orders.place(
    LpgOrder(
      customerId: 'c-$customer',
      customerName: customer,
      customerPhone: phone,
      items: [it],
      subtotal: it.lineTotal,
      deliveryFee: 150,
      total: it.lineTotal + 150,
      paymentMethod: pay,
      address: Address(
        label: 'Home',
        line1: line,
        area: area,
        lat: lat,
        lng: lng,
      ),
    ),
  );
  await job('Ali Raza', '+923001234567', 'Gulberg III', 'House 12-B, Main Boulevard',
      31.5204, 74.3587, item('cyl-11-8kg', '11.8kg Gas Cylinder', 11.8, 3296, 2), PaymentMethod.cashOnDelivery);
  await job('Sara Café', '+923211234567', 'DHA Phase 5', 'Shop 4, Y Block Market',
      31.4697, 74.4094, item('cyl-45-4kg', '45.4kg Gas Cylinder', 45.4, 12682, 1), PaymentMethod.jazzCash);
  await job('Bilal Ahmed', '+923331234567', 'Johar Town', 'Street 7, Block E',
      31.4697, 74.2728, item('cyl-6kg', '6kg Gas Cylinder', 6, 1676, 1), PaymentMethod.cashOnDelivery);

  return RiderBackend(
    auth: _DemoAuth(),
    orders: orders,
    riders: riders,
    catalog: CatalogRepository.memory(store),
    tracker: GeolocatorTracker(),
  );
}
