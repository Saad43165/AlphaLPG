import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Email + password sign-in. The admin account is created by the owner in the
/// Firebase console (Authentication → Add user).
abstract class AdminAuth extends ChangeNotifier {
  String? get uid;
  String? get email;
  bool get isSignedIn => uid != null;

  Future<void> signIn(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

class FirebaseAdminAuth extends AdminAuth {
  FirebaseAdminAuth(this._auth) {
    _sub = _auth.authStateChanges().listen((_) => notifyListeners());
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _sub;

  @override
  String? get uid => _auth.currentUser?.uid;
  @override
  String? get email => _auth.currentUser?.email;

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  static String _message(FirebaseAuthException e) => switch (e.code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'invalid-email' => 'Email or password is incorrect.',
    'user-disabled' =>
      'This account has been disabled. Please contact Alpha LPG.',
    'too-many-requests' =>
      'Too many attempts. Please wait a few minutes and try again.',
    'network-request-failed' => 'No internet connection.',
    _ => e.message ?? 'Sign-in failed (${e.code}).',
  };
}
