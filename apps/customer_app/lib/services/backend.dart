import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../firebase_options.dart';
import 'auth_service.dart';

/// Everything the UI needs to talk to the outside world.
class Backend {
  Backend({
    required this.auth,
    required this.catalog,
    required this.orders,
    required this.profiles,
    required this.quotes,
    required this.riders,
    this.isDemo = false,
  });

  factory Backend.firebase(FirebaseFirestore db, FirebaseAuth auth) => Backend(
    auth: FirebaseAuthService(auth),
    catalog: CatalogRepository.firestore(db),
    orders: OrderRepository.firestore(db),
    profiles: ProfileRepository.firestore(db),
    quotes: QuoteRepository.firestore(db),
    riders: RiderRepository.firestore(db),
  );

  /// In-memory backend. With [simulateDispatch] new orders move through
  /// confirmed → rider assigned → out for delivery → delivered by themselves.
  factory Backend.memory({bool simulateDispatch = false}) {
    final store = MemoryStore();
    final backend = Backend(
      auth: DemoAuthService(),
      catalog: CatalogRepository.memory(store),
      orders: OrderRepository.memory(store),
      profiles: ProfileRepository.memory(store),
      quotes: QuoteRepository.memory(store),
      riders: RiderRepository.memory(store),
      isDemo: true,
    );
    if (simulateDispatch) _DemoDispatcher(backend.orders, store).start();
    return backend;
  }

  final AuthService auth;
  final CatalogRepository catalog;
  final OrderRepository orders;
  final ProfileRepository profiles;
  final QuoteRepository quotes;
  final RiderRepository riders;
  final bool isDemo;

  /// Connects to Firebase, or falls back to the in-memory demo backend when
  /// Firebase is not configured (or `--dart-define=DEMO=true` is set).
  static Future<Backend> init() async {
    if (!Env.forceDemo) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        return Backend.firebase(
          FirebaseFirestore.instance,
          FirebaseAuth.instance,
        );
      } catch (e) {
        if (Env.production) rethrow;
        debugPrint('Firebase unavailable, starting demo mode: $e');
      }
    }
    return Backend.memory(simulateDispatch: true);
  }
}

/// Demo only: plays the part of the admin and rider apps so tracking can be
/// shown end-to-end. Moves each active order one step every few seconds.
class _DemoDispatcher {
  _DemoDispatcher(this.orders, this.store);
  final OrderRepository orders;
  final MemoryStore store;
  final _scheduled = <String>{};

  static const _step = Duration(seconds: 8);

  void start() {
    store.watch(FirestorePaths.orders, (docs) => docs).listen((docs) {
      for (final MapEntry(key: id, value: data) in docs.entries) {
        final status = OrderStatus.parse(data['status'] as String?);
        final key = '$id/${status.name}';
        if (!status.isActive || !_scheduled.add(key)) continue;
        Timer(_step, () => _advance(id, status));
      }
    });
  }

  void _advance(String id, OrderStatus from) {
    final current = OrderStatus.parse(
      store.get(FirestorePaths.orders, id)?['status'] as String?,
    );
    if (current != from) return; // cancelled or moved meanwhile
    final next = OrderStatus.journey[OrderStatus.journey.indexOf(from) + 1];
    if (next == OrderStatus.assigned) {
      orders.assignRider(
        id,
        'demo-admin',
        riderId: 'demo-rider',
        name: 'Imran (demo rider)',
        phone: '03085745740',
      );
    } else {
      orders.updateStatus(id, next, 'demo-admin');
    }
  }
}
