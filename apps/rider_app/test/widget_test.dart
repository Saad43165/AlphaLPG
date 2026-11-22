import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_rider/app.dart';
import 'package:alpha_rider/services/backend.dart';
import 'package:alpha_rider/services/location_tracker.dart';
import 'package:alpha_rider/services/rider_auth.dart';
import 'package:alpha_rider/state/session.dart';
import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart' show Brightness;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class FakeAuth extends RiderAuth {
  FakeAuth({this.accounts = const {}});
  final Map<String, ({String uid, String password})> accounts;
  String? _uid;
  String? _email;

  @override
  String? get uid => _uid;
  @override
  String? get email => _email;

  @override
  Future<void> signIn(String email, String password) async {
    final a = accounts[email.trim()];
    if (a == null || a.password != password) {
      throw AuthFailure('Email or password is incorrect.');
    }
    _uid = a.uid;
    _email = email.trim();
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

class FakeTracker extends LocationTracker {
  FakeTracker({this.access = TrackerAccess.granted});
  TrackerAccess access;
  String? _id;

  @override
  String? get orderId => _id;
  DateTime? shared;
  String? error;
  @override
  DateTime? get lastShared => shared;
  @override
  String? get lastError => error;
  @override
  Future<TrackerAccess> ensureAccess() async => access;
  @override
  Future<void> start(String orderId, OrderRepository orders) async {
    _id = orderId;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    if (_id != null) {
      _id = null;
      notifyListeners();
    }
  }

  @override
  Future<void> openSettings() async {}
}

LpgOrder sampleOrder({
  String customer = 'u1',
  PaymentMethod method = PaymentMethod.cashOnDelivery,
  int qty = 2,
}) => LpgOrder(
  customerId: customer,
  customerName: 'Bilal Ahmed',
  customerPhone: '+923001234567',
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
  deliveryFee: 0,
  total: 3296 * qty,
  paymentMethod: method,
  address: const Address(
    label: 'Home',
    line1: 'Main Boulevard',
    area: 'Gulberg III',
    lat: 31.5107,
    lng: 74.3445,
  ),
);

class Rig {
  Rig({this.tracker})
    : store = MemoryStore(),
      auth = FakeAuth(
        accounts: {'imran@alphalpg.pk': (uid: 'r1', password: 'secret1')},
      );

  final MemoryStore store;
  final FakeAuth auth;
  FakeTracker? tracker;

  late final backend = RiderBackend(
    auth: auth,
    orders: OrderRepository.memory(store),
    riders: RiderRepository.memory(store),
    catalog: CatalogRepository.memory(store),
    ops: OpsRepository.memory(store),
    tracker: tracker ??= FakeTracker(),
  );
}

Future<void> pumpRider(WidgetTester tester, Rig rig) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RiderApp(backend: rig.backend));
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> signIn(
  WidgetTester tester, {
  String email = 'imran@alphalpg.pk',
  String password = 'secret1',
}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    password,
  );
  await tapText(tester, 'Sign in');
}

Future<void> addRider(WidgetTester tester, Rig rig, {bool active = true}) =>
    tester.runAsync(
      () => rig.backend.riders.saveRider(
        RiderProfile(
          uid: 'r1',
          name: 'Imran Khan',
          phone: '+923005550001',
          active: active,
        ),
      ),
    );

Future<LpgOrder> orderOf(WidgetTester tester, Rig rig, String id) async =>
    (await tester.runAsync(() => rig.backend.orders.watchOrder(id).first))!;

Future<String> placeOrder(
  WidgetTester tester,
  Rig rig, {
  PaymentMethod method = PaymentMethod.cashOnDelivery,
}) async => (await tester.runAsync(
  () => rig.backend.orders.place(sampleOrder(method: method)),
))!;

void main() {
  testWidgets('wrong password is refused with a clear message', (tester) async {
    final rig = Rig();
    await pumpRider(tester, rig);
    await signIn(tester, password: 'nope');
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets(
    'a signed-in account that is not a rider is told so, and can sign out',
    (tester) async {
      final rig = Rig();
      await pumpRider(tester, rig);
      await signIn(tester);
      expect(
        find.text('This account is not set up as a rider'),
        findsOneWidget,
      );
      await tapText(tester, 'Sign out');
      expect(find.byType(Image), findsWidgets); // the Rider banner
    },
  );

  testWidgets('a blocked rider cannot get in', (tester) async {
    final rig = Rig();
    await addRider(tester, rig, active: false);
    await pumpRider(tester, rig);
    await signIn(tester);
    expect(find.text('Your rider account is switched off'), findsOneWidget);
  });

  testWidgets(
    'online → accept a job → start delivery shares location → deliver with cash',
    (tester) async {
      final rig = Rig();
      await addRider(tester, rig);
      final id = await placeOrder(tester, rig);
      await pumpRider(tester, rig);
      await signIn(tester);

      // Offline riders cannot take jobs.
      expect(find.text('You are offline'), findsOneWidget);
      await tapText(tester, 'New');
      expect(
        find.text('You are offline, so you cannot accept orders.'),
        findsOneWidget,
      );
      await tapText(tester, 'Accept job');
      expect(find.textContaining('Go online first'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('You are online and can take orders'), findsOneWidget);
      await tapText(tester, 'Accept job');
      expect(find.text('Job accepted. Find it in "My jobs".'), findsOneWidget);

      // It moved to My jobs, with the cash to collect shown.
      expect(find.text('Take Rs. 6,592 cash'), findsOneWidget);
      expect(find.text('Ready to go'), findsOneWidget);
      var o = await orderOf(tester, rig, id);
      expect(o.riderId, 'r1');
      expect(o.status, OrderStatus.assigned);

      // Start: status changes and location sharing begins.
      await tapText(tester, 'Start delivery');
      expect(rig.tracker!.orderId, id);
      expect(find.text('Finding your position…'), findsOneWidget);
      o = await orderOf(tester, rig, id);
      expect(o.status, OrderStatus.outForDelivery);

      // Deliver: cash prefilled with the amount due.
      await tapText(tester, 'Mark delivered');
      expect(find.text('Confirm delivery'), findsOneWidget);
      expect(find.widgetWithText(TextField, '6592'), findsOneWidget);
      // Empties are ticked one by one (2 refills = 2 empties).
      expect(find.text('0 of 2'), findsOneWidget);
      await tapText(tester, 'Tick all');
      expect(find.text('2 of 2'), findsOneWidget);
      await tapText(tester, 'Mark as delivered');
      expect(find.text('Delivered. Well done!'), findsOneWidget);
      expect(
        rig.tracker!.orderId,
        isNull,
        reason: 'location sharing stops when delivered',
      );
      o = await orderOf(tester, rig, id);
      expect(o.status, OrderStatus.delivered);
      expect(o.paymentStatus, PaymentStatus.paid);
      expect(o.cashCollected, 6592);
      expect(o.emptiesCollected, 2);

      // Today's totals on the History tab.
      await tapText(tester, 'History');
      expect(find.text('Rs. 6,592'), findsWidgets);
      expect(find.text('Cash with you'), findsOneWidget);
      expect(find.text('Delivered today'), findsOneWidget);
    },
  );

  testWidgets(
    'without location permission a delivery cannot start (customers could not follow)',
    (tester) async {
      final rig = Rig(tracker: FakeTracker(access: TrackerAccess.denied));
      await addRider(tester, rig);
      final id = await placeOrder(tester, rig);
      await tester.runAsync(() => rig.backend.riders.setOnline('r1', true));
      await tester.runAsync(
        () => rig.backend.orders.acceptOrder(
          id,
          riderId: 'r1',
          name: 'Imran Khan',
          phone: '0300',
        ),
      );
      await pumpRider(tester, rig);
      await signIn(tester);
      await tapText(tester, 'Start delivery');
      expect(find.textContaining('Allow location to start'), findsOneWidget);
      final o = await orderOf(tester, rig, id);
      expect(
        o.status,
        OrderStatus.assigned,
        reason: 'status must not change without location',
      );
      expect(rig.tracker!.isTracking, isFalse);
    },
  );

  testWidgets('another rider took the order first', (tester) async {
    final rig = Rig();
    await addRider(tester, rig);
    final id = await placeOrder(tester, rig);
    await tester.runAsync(() => rig.backend.riders.setOnline('r1', true));
    await pumpRider(tester, rig);
    await signIn(tester);
    await tapText(tester, 'New');
    // Someone else accepts while this rider is looking at the list.
    await tester.runAsync(
      () => rig.backend.orders.acceptOrder(
        id,
        riderId: 'r2',
        name: 'Bilal',
        phone: '0301',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No new orders'), findsOneWidget);
  });

  testWidgets('app reopened mid-delivery resumes location sharing', (
    tester,
  ) async {
    final rig = Rig();
    await addRider(tester, rig);
    final id = await placeOrder(tester, rig);
    await tester.runAsync(() async {
      await rig.backend.orders.acceptOrder(
        id,
        riderId: 'r1',
        name: 'Imran Khan',
        phone: '0300',
      );
      await rig.backend.orders.startDelivery(id, 'r1');
    });
    await pumpRider(tester, rig);
    await signIn(tester);
    expect(rig.tracker!.orderId, id);
    expect(find.text('Finding your position…'), findsOneWidget);
  });

  testWidgets(
    'the banner tells the truth: working, or failing with the reason',
    (tester) async {
      final rig = Rig();
      await addRider(tester, rig);
      final id = await placeOrder(tester, rig);
      await tester.runAsync(() async {
        await rig.backend.orders.acceptOrder(
          id,
          riderId: 'r1',
          name: 'Imran Khan',
          phone: '0300',
        );
        await rig.backend.orders.startDelivery(id, 'r1');
      });
      await pumpRider(tester, rig);
      await signIn(tester);
      rig.tracker!.error =
          'The server refused the location. Ask the shop to check the rules.';
      rig.tracker!.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.textContaining('server refused'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      rig.tracker!.error = null;
      rig.tracker!.shared = DateTime.now();
      rig.tracker!.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.textContaining('Sharing live location'), findsOneWidget);
    },
  );

  testWidgets(
    'the shop switching a rider offline, or closing, is shown to the rider',
    (tester) async {
      final rig = Rig();
      await addRider(tester, rig);
      await tester.runAsync(() => rig.backend.riders.setOnline('r1', true));
      await pumpRider(tester, rig);
      await signIn(tester);
      expect(find.textContaining('switched you offline'), findsNothing);
      // The admin app switches the rider off.
      await tester.runAsync(() => rig.backend.riders.setOnline('r1', false));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Alpha LPG switched you offline'),
        findsOneWidget,
      );
      // The owner closes the shop.
      await tester.runAsync(
        () => rig.backend.catalog.saveSettings(
          AppSettings.fromMap({
            ...SeedData.settings.toMap(),
            'acceptingOrders': false,
          }),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('closed for orders'), findsOneWidget);
    },
  );

  testWidgets(
    'rider and customer can chat on an assigned job, with unread badge and Seen',
    (tester) async {
      final rig = Rig();
      await addRider(tester, rig);
      final id = await placeOrder(tester, rig);
      await tester.runAsync(() async {
        await rig.backend.orders.acceptOrder(
          id,
          riderId: 'r1',
          name: 'Imran Khan',
          phone: '0300',
        );
      });
      await pumpRider(tester, rig);
      await signIn(tester);
      // The customer writes: the rider sees a badge on the job.
      await tester.runAsync(() async {
        await rig.backend.orders.sendMessage(
          id,
          uid: 'u1',
          role: MessageRole.customer,
          name: 'Ali',
          text: 'Blue gate please',
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.text('1'), findsWidgets); // unread badge on the job
      await tester.tap(find.byTooltip('Message customer').first);
      await tester.pumpAndSettle();
      expect(find.text('Blue gate please'), findsOneWidget);
      await tester.tap(find.text('On my way'));
      await tester.pumpAndSettle();
      final thread = await tester.runAsync(
        () => rig.backend.orders.watchMessages(id).first,
      );
      expect(thread!.map((m) => m.text), ['Blue gate please', 'On my way']);
      expect(thread.last.role, MessageRole.rider);
    },
  );

  testWidgets('prepaid orders are not shown as cash to collect', (
    tester,
  ) async {
    final rig = Rig();
    await addRider(tester, rig);
    await placeOrder(tester, rig, method: PaymentMethod.jazzCash);
    await tester.runAsync(() => rig.backend.riders.setOnline('r1', true));
    await pumpRider(tester, rig);
    await signIn(tester);
    await tapText(tester, 'New');
    expect(find.textContaining('cash'), findsNothing);
    expect(find.textContaining('JazzCash not confirmed'), findsOneWidget);
  });

  testWidgets(
    'an unpaid online order cannot be delivered; once the shop confirms it can',
    (tester) async {
      final rig = Rig();
      await addRider(tester, rig);
      final id = await placeOrder(tester, rig, method: PaymentMethod.easyPaisa);
      await tester.runAsync(() async {
        await rig.backend.riders.setOnline('r1', true);
        await rig.backend.orders.acceptOrder(
          id,
          riderId: 'r1',
          name: 'Imran Khan',
          phone: '0300',
        );
        await rig.backend.orders.updateStatus(
          id,
          OrderStatus.outForDelivery,
          'r1',
        );
      });
      await pumpRider(tester, rig);
      await signIn(tester);

      await tapText(tester, 'Mark delivered');
      expect(find.text('Payment not confirmed yet'), findsOneWidget);
      expect(find.text('Confirm delivery'), findsNothing);
      await tapText(tester, 'OK');
      var o = await orderOf(tester, rig, id);
      expect(o.status, OrderStatus.outForDelivery);

      // The shop confirms the payment: now the delivery can be finished.
      await tester.runAsync(() async {
        await rig.backend.orders.markPaid(id, 'boss');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      await tapText(tester, 'Mark delivered');
      expect(find.text('Confirm delivery'), findsOneWidget);
      await tapText(tester, 'Mark as delivered');
      o = await orderOf(tester, rig, id);
      expect(o.status, OrderStatus.delivered);
      expect(o.cashCollected, 0);

      // Earnings screen shows the delivery.
      await tapText(tester, 'Me');
      await tapText(tester, 'My earnings and cash');
      expect(find.text('My earnings and cash'), findsWidgets);
      expect(find.text('All cash handed in'), findsOneWidget);
    },
  );

  testWidgets(
    'shop takes an order back: the rider is told, and it leaves their jobs',
    (tester) async {
      final rig = Rig();
      await addRider(tester, rig);
      final id = await placeOrder(tester, rig);
      await tester.runAsync(() async {
        await rig.backend.riders.setOnline('r1', true);
        await rig.backend.orders.acceptOrder(
          id,
          riderId: 'r1',
          name: 'Imran Khan',
          phone: '0300',
        );
      });
      await pumpRider(tester, rig);
      await signIn(tester);
      expect(find.text('Ready to go'), findsOneWidget);

      await tester.runAsync(() async {
        await rig.backend.orders.unassignRider(id, 'boss');
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('Order taken back'), findsOneWidget);
      expect(find.text('Ready to go'), findsNothing);
    },
  );

  testWidgets(
    'a job the rider hands back or finishes does not show a "taken back" notice',
    (tester) async {
      final rig = Rig();
      await addRider(tester, rig);
      final id = await placeOrder(tester, rig);
      await tester.runAsync(() async {
        await rig.backend.riders.setOnline('r1', true);
        await rig.backend.orders.acceptOrder(
          id,
          riderId: 'r1',
          name: 'Imran Khan',
          phone: '0300',
        );
      });
      await pumpRider(tester, rig);
      await signIn(tester);
      final session = Provider.of<RiderSession>(
        tester.element(find.text('Ready to go')),
        listen: false,
      );
      final order = session.jobs.single;
      final ok = await tester.runAsync(() => session.release(order));
      expect(ok, isTrue);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('taken back'), findsNothing);
    },
  );

  for (final dark in [false, true]) {
    testWidgets('rider screens at large text, ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final rig = Rig();
      await addRider(tester, rig);
      final id = await placeOrder(tester, rig, method: PaymentMethod.easyPaisa);
      await placeOrder(tester, rig);
      await tester.runAsync(() async {
        await rig.backend.riders.setOnline('r1', true);
        await rig.backend.orders.acceptOrder(
          id,
          riderId: 'r1',
          name: 'Imran Khan',
          phone: '0300',
        );
      });
      await pumpRider(tester, rig);
      await signIn(tester);
      expect(tester.takeException(), isNull, reason: 'jobs');
      for (final tab in ['New', 'History', 'Me', 'My jobs']) {
        await tapText(tester, tab);
        expect(tester.takeException(), isNull, reason: tab);
      }
      await tapText(tester, 'Me');
      for (final item in ['My earnings and cash', 'Keep the app running']) {
        await tapText(tester, item);
        expect(tester.takeException(), isNull, reason: item);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets(
    'a rider reports a problem on a job: it reaches the shop, not the chat',
    (tester) async {
      final rig = Rig();
      await addRider(tester, rig);
      final id = await placeOrder(tester, rig);
      await tester.runAsync(() async {
        await rig.backend.riders.setOnline('r1', true);
        await rig.backend.orders.acceptOrder(
          id,
          riderId: 'r1',
          name: 'Imran Khan',
          phone: '0300',
        );
      });
      await pumpRider(tester, rig);
      await signIn(tester);
      final session = Provider.of<RiderSession>(
        tester.element(find.text('Ready to go')),
        listen: false,
      );
      final err = await tester.runAsync(
        () => session.reportProblem(
          session.jobs.single,
          'Customer is not answering',
          'Rang 3 times',
        ),
      );
      expect(err, isNull);
      final reports = await tester.runAsync(
        () => rig.backend.orders.watchReports().first,
      );
      expect(reports!.single.fromRider, isTrue);
      expect(reports.single.reason, 'Customer is not answering');
      expect(reports.single.riderId, 'r1');
      final mine = await tester.runAsync(
        () => rig.backend.orders.watchRiderReports(id, 'r1').first,
      );
      expect(mine, hasLength(1));
      final chat = await tester.runAsync(
        () => rig.backend.orders.watchMessages(id).first,
      );
      expect(chat, isEmpty);
    },
  );
}
