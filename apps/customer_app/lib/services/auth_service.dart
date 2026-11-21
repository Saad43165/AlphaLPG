import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';

/// Phone-number (OTP) sign-in. Implemented by Firebase in production and by
/// [DemoAuthService] for demos and tests.
abstract class AuthService extends ChangeNotifier {
  String? get uid;
  String? get phone;
  bool get isSignedIn => uid != null;

  /// Sends an SMS code to [phoneE164]. Returns true if the user was signed in
  /// instantly (Android auto-verification), so no code needs to be typed.
  Future<bool> sendCode(String phoneE164);
  Future<void> verifyCode(String code);
  Future<void> signOut();

  /// Permanently removes the sign-in account. May ask the customer to sign
  /// in again first (Firebase wants a recent sign-in for this).
  Future<void> deleteAccount();
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class FirebaseAuthService extends AuthService {
  FirebaseAuthService(this._auth) {
    _sub = _auth.authStateChanges().listen((_) => notifyListeners());
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _sub;
  String? _verificationId;
  int? _resendToken;
  ConfirmationResult? _webConfirmation;

  @override
  String? get uid => _auth.currentUser?.uid;
  @override
  String? get phone => _auth.currentUser?.phoneNumber;

  @override
  Future<bool> sendCode(String phoneE164) async {
    try {
      if (kIsWeb) {
        _webConfirmation = await _auth.signInWithPhoneNumber(phoneE164);
        return false;
      }
      final done = Completer<bool>();
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneE164,
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (cred) async {
          await _auth.signInWithCredential(cred);
          if (!done.isCompleted) done.complete(true);
        },
        verificationFailed: (e) {
          if (!done.isCompleted) done.completeError(AuthException(_message(e)));
        },
        codeSent: (id, token) {
          _verificationId = id;
          _resendToken = token;
          if (!done.isCompleted) done.complete(false);
        },
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
      );
      return await done.future;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  @override
  Future<void> verifyCode(String code) async {
    try {
      if (kIsWeb) {
        final c = _webConfirmation;
        if (c == null) throw AuthException('Please request a new code.');
        await c.confirm(code);
        return;
      }
      final id = _verificationId;
      if (id == null) throw AuthException('Please request a new code.');
      await _auth.signInWithCredential(
        PhoneAuthProvider.credential(verificationId: id, smsCode: code),
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw AuthException(
          'For your security, please sign out, sign in again with your mobile number, then delete your account.',
        );
      }
      throw AuthException(_message(e));
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  static String _message(FirebaseAuthException e) => switch (e.code) {
    'invalid-phone-number' => 'That mobile number is not valid.',
    'invalid-verification-code' => 'The code is incorrect. Please try again.',
    'session-expired' => 'The code expired. Please request a new one.',
    'too-many-requests' => 'Too many attempts. Please wait and try again.',
    'network-request-failed' => 'No internet connection.',
    _ => e.message ?? 'Sign-in failed (${e.code}).',
  };
}

/// Accepts any Pakistani mobile number with OTP [Env.demoOtp].
class DemoAuthService extends AuthService {
  String? _uid;
  String? _phone;
  String? _pending;

  @override
  String? get uid => _uid;
  @override
  String? get phone => _phone;

  @override
  Future<bool> sendCode(String phoneE164) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _pending = phoneE164;
    return false;
  }

  @override
  Future<void> verifyCode(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (code != Env.demoOtp) {
      throw AuthException('Incorrect code. In demo mode use ${Env.demoOtp}.');
    }
    _phone = _pending;
    _uid = 'demo-${_pending!.substring(_pending!.length - 6)}';
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    _uid = null;
    _phone = null;
    notifyListeners();
  }

  @override
  Future<void> deleteAccount() => signOut();
}
