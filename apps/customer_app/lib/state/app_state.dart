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
    // How many riders are on shift (public; no personal details).
    _subs.add(
      backend.riders.watchLiveRiderCount().listen((n) {
        liveRiders = n;
        notifyListeners();
      }, onError: (_) {}),
    );
    // Opening hours change with the clock, so re-check every minute.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (settings.autoHours) notifyListeners();
    });
    backend.auth.addListener(_onAuth);
    _onAuth();
  }

  Timer? _clock;

  /// Riders on shift right now; null until known.
  int? liveRiders;

  /// Whether the shop is taking orders, and why not. Set by the owner in the
  /// admin app (switch, opening hours, "pause when no riders").
  OrderingStatus get ordering =>
      OrderingStatus.of(settings, liveRiders: liveRiders);

  final Backend backend;
  final SharedPreferences? prefs;

  // ---- Order chat -----------------------------------------------------------

  /// Unread counts, last message and "seen" for the customer's orders.
  late final ChatInbox chat = ChatInbox(backend.orders, MessageRole.customer);

  // ---- Settings (saved on this device) ------------------------------------

  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
  bool haptics = true;

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

  /// Shows an important order update inside the app (set by the app shell).
  void Function(String title, String body, String route)? inAppNotice;

  /// Set when the shop has blocked this customer from ordering.
  BlockedCustomer? blocked;

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
    blocked = null;
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
        backend.profiles.watchBlocked(uid).listen((b) {
          blocked = b;
          notifyListeners();
        }, onError: (_) {}),
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
    chat.dispose();
    _clock?.cancel();
    routeSignal.dispose();
    themeMode.dispose();
    backend.auth.removeListener(_onAuth);
    for (final s in [..._subs, ..._userSubs]) {
      s.cancel();
    }
    super.dispose();
  }
}
