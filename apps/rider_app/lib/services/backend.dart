import 'package:alpha_core/alpha_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'location_tracker.dart';
import 'rider_auth.dart';

/// Everything the rider app talks to.
class RiderBackend {
  RiderBackend({
    required this.auth,
    required this.orders,
    required this.riders,
    required this.catalog,
    required this.ops,
    required this.tracker,
  });

  factory RiderBackend.firebase(FirebaseFirestore db, FirebaseAuth auth) =>
      RiderBackend(
        auth: FirebaseRiderAuth(auth),
        orders: OrderRepository.firestore(db),
        riders: RiderRepository.firestore(db),
        catalog: CatalogRepository.firestore(db),
        ops: OpsRepository.firestore(db),
        tracker: GeolocatorTracker(),
      );

  final RiderAuth auth;
  final OrderRepository orders;
  final RiderRepository riders;
  final CatalogRepository catalog;
  final OpsRepository ops;
  final LocationTracker tracker;
}
