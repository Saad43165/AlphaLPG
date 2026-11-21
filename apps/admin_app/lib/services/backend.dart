import 'package:alpha_core/alpha_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'admin_auth.dart';

/// Everything the admin app talks to.
class AdminBackend {
  AdminBackend({
    required this.auth,
    required this.orders,
    required this.riders,
    required this.catalog,
    required this.quotes,
    required this.profiles,
    required this.ops,
    required this.watchIsAdmin,
    required this.createRiderLogin,
  });

  factory AdminBackend.firebase(FirebaseFirestore db, FirebaseAuth auth) =>
      AdminBackend(
        auth: FirebaseAdminAuth(auth),
        orders: OrderRepository.firestore(db),
        riders: RiderRepository.firestore(db),
        catalog: CatalogRepository.firestore(db),
        quotes: QuoteRepository.firestore(db),
        profiles: ProfileRepository.firestore(db),
        ops: OpsRepository.firestore(db),
        watchIsAdmin: (uid) => db
            .doc('admins/$uid')
            .snapshots()
            .map((d) => d.exists)
            .handleError((_) {}),
        createRiderLogin: _createLogin,
      );

  final AdminAuth auth;
  final OrderRepository orders;
  final RiderRepository riders;
  final CatalogRepository catalog;
  final QuoteRepository quotes;
  final ProfileRepository profiles;
  final OpsRepository ops;

  /// True while `admins/{uid}` exists.
  final Stream<bool> Function(String uid) watchIsAdmin;

  /// Creates the email/password login for a new rider and returns its UID.
  /// Uses a second Firebase app so the owner stays signed in.
  final Future<String> Function(String email, String password) createRiderLogin;

  static Future<String> _createLogin(String email, String password) async {
    FirebaseApp app;
    try {
      app = Firebase.app('staff');
    } catch (_) {
      app = await Firebase.initializeApp(
        name: 'staff',
        options: Firebase.app().options,
      );
    }
    final staffAuth = FirebaseAuth.instanceFor(app: app);
    try {
      final cred = await staffAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      await staffAuth.signOut();
      return uid;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(switch (e.code) {
        'email-already-in-use' => 'That email already has an account.',
        'weak-password' => 'Use a stronger password (at least 6 characters).',
        'invalid-email' => 'That email address is not valid.',
        'network-request-failed' => 'No internet connection.',
        _ => e.message ?? 'Could not create the login (${e.code}).',
      });
    }
  }
}
