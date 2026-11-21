import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/backend.dart';
import '../utils/haptics.dart';

/// Live data shared by every screen: catalogue, settings, and (when signed
/// in) the customer's profile and saved addresses.
class AppState extends ChangeNotifier {
  AppState(this.backend, {this.prefs, this.onboarded = true}) {
    final p = prefs;
    if (p != null) {
      themeMode.value = switch (p.getString('theme')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      haptics = p.getBool('haptics') ?? true;
      cycleDaysOverride = p.getInt('cycleDays');
    }
    Haptics.enabled = haptics;
    _subs.add(
      backend.catalog.watchProducts().listen((p) {
        products = p;
        productsLoaded = true;
        notifyListeners();
      }),
    );
    _subs.add(
      backend.catalog.watchSettings().listen((s) {
        settings = s;
        notifyListeners();
      }),
    );
    backend.auth.addListener(_onAuth);
    _onAuth();
  }

  final Backend backend;
  final SharedPreferences? prefs;

  // ---- Order chat: what the customer has read --------------------------------

  final _chatSeen = <String, int>{};

  int _seenAt(String orderId) =>
      _chatSeen[orderId] ?? prefs?.getInt('chat.$orderId') ?? 0;

  /// The customer opened the chat for [orderId]: everything so far is read.
  void markChatRead(String orderId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _chatSeen[orderId] = now;
    prefs?.setInt('chat.$orderId', now);
    notifyListeners();
  }

  /// Messages from the rider or the shop that are newer than the last visit.
  int unreadMessages(String orderId, List<OrderMessage> list) {
    final seen = _seenAt(orderId);
    return list
        .where(
          (m) =>
              m.role != MessageRole.customer &&
              (m.createdAt?.millisecondsSinceEpoch ?? 1 << 50) > seen,
        )
        .length;
  }

  // ---- Settings (saved on this device) ------------------------------------

  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
  bool haptics = true;

  /// How long a cylinder lasts for this household, if the customer set it.
  int? cycleDaysOverride;

  void setThemeMode(ThemeMode m) {
    themeMode.value = m;
    prefs?.setString('theme', m.name);
  }

  void setHaptics(bool v) {
    haptics = v;
    Haptics.enabled = v;
    prefs?.setBool('haptics', v);
    notifyListeners();
  }

  void setCycleDays(int? days) {
    cycleDaysOverride = days;
    if (days == null) {
      prefs?.remove('cycleDays');
    } else {
      prefs?.setInt('cycleDays', days);
    }
    notifyListeners();
  }

  /// False until the first-launch welcome slides have been completed.
  bool onboarded;

  void completeOnboarding() {
    onboarded = true;
    prefs?.setBool('onboarded', true);
    notifyListeners();
  }

  final _subs = <StreamSubscription<dynamic>>[];
  final _userSubs = <StreamSubscription<dynamic>>[];

  List<Product> products = SeedData.products;
  bool productsLoaded = false;
  AppSettings settings = SeedData.settings;

  String? _uid;
  CustomerProfile? profile;
  bool profileLoaded = false;
  List<Address> addresses = const [];
  String? _selectedAddressId;

  /// The "Deliver to" address chosen on the home screen (defaults to the
  /// most recently added one).
  Address? get selectedAddress {
    if (addresses.isEmpty) return null;
    return addresses.firstWhere(
      (a) => a.id == _selectedAddressId,
      orElse: () => addresses.last,
    );
  }

  void selectAddress(String id) {
    _selectedAddressId = id;
    notifyListeners();
  }

  /// Changes only when sign-in / profile-completion status changes. The
  /// router listens to this (not to every data update) so that saving an
  /// address or receiving an order update never re-runs navigation.
  final routeSignal = ValueNotifier<String>('');

  @override
  void notifyListeners() {
    routeSignal.value = '$onboarded/$signedIn/$needsProfile';
    super.notifyListeners();
  }

  String? get uid => _uid;
  bool get signedIn => _uid != null;
  bool get needsProfile => signedIn && profileLoaded && profile == null;

  Product? productById(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _onAuth() {
    final uid = backend.auth.uid;
    if (uid == _uid) return;
    for (final s in _userSubs) {
      s.cancel();
    }
    _userSubs.clear();
    _uid = uid;
    profile = null;
    addresses = const [];
    profileLoaded = false;
    if (uid != null) {
      _userSubs.add(
        backend.profiles.watchProfile(uid).listen((p) {
          profile = p;
          profileLoaded = true;
          notifyListeners();
        }),
      );
      _userSubs.add(
        backend.profiles.watchAddresses(uid).listen((a) {
          addresses = a;
          notifyListeners();
        }),
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    routeSignal.dispose();
    themeMode.dispose();
    backend.auth.removeListener(_onAuth);
    for (final s in [..._subs, ..._userSubs]) {
      s.cancel();
    }
    super.dispose();
  }
}
