import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

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
  factory Backend.memory() {
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
    return backend;
  }

  final AuthService auth;
  final CatalogRepository catalog;
  final OrderRepository orders;
  final ProfileRepository profiles;
  final QuoteRepository quotes;
  final RiderRepository riders;
  final bool isDemo;

  /// Connects to the real Firebase project. There is no demo mode: if
  /// Firebase is not set up the app shows a "not set up" screen.
  static Future<Backend> init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return Backend.firebase(FirebaseFirestore.instance, FirebaseAuth.instance);
  }
}
