import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'routing.dart';

/// Centre of Lahore, used when the phone's location is unavailable.
const lahoreCentre = LatLng(31.5204, 74.3587);

/// Rough bounding box of the Lahore delivery region.
bool isInsideLahore(LatLng p) =>
    p.latitude >= 31.20 &&
    p.latitude <= 31.80 &&
    p.longitude >= 74.05 &&
    p.longitude <= 74.70;

enum LocationAccess { granted, denied, deniedForever, serviceOff }

/// An address worked out from map coordinates.
@immutable
class ResolvedPlace {
  const ResolvedPlace({this.line1 = '', this.area = ''});
  final String line1;
  final String area;

  bool get isEmpty => line1.isEmpty && area.isEmpty;
}

@immutable
class PlaceHit {
  const PlaceHit(this.title, this.subtitle, this.point);
  final String title;
  final String subtitle;
  final LatLng point;
}

/// Everything location-related, behind an interface so tests (and the demo
/// on devices without Google services) can swap it.
/// Where map tiles come from for the current theme.
@immutable
class MapTiles {
  const MapTiles(this.urlTemplate, {this.darkIsNative = false});

  /// OpenStreetMap's public tiles: free, but meant for light use only.
  const MapTiles.osm()
    : urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      darkIsNative = false;

  /// `{z}/{x}/{y}` (and optionally `{r}` for retina) template.
  final String urlTemplate;

  /// True when [urlTemplate] already is a dark map, so no colour filter is needed.
  final bool darkIsNative;
}

abstract class LocationService {
  /// Whether real map tiles should be drawn.
  bool get hasMap => true;

  /// Tile source for the light or dark theme.
  MapTiles tiles({required bool dark}) => const MapTiles.osm();

  /// Credit line the map provider requires on screen.
  String get attribution => '© OpenStreetMap contributors';

  Future<LocationAccess> access();
  Future<LocationAccess> requestAccess();

  /// Current GPS position, or null when unavailable / not permitted.
  Future<LatLng?> currentPosition();

  /// Street + area for [p]. Never throws; returns an empty place on failure.
  Future<ResolvedPlace> reverse(LatLng p);

  /// Free-text place search around Lahore.
  Future<List<PlaceHit>> search(String query);

  Future<void> openSettings() => Geolocator.openAppSettings();

  /// Driving route between two points; null when unavailable (tests, offline).
  Future<RoutePath?> route(LatLng from, LatLng to) async => null;
}

class DeviceLocationService extends LocationService {
  late final _geo = geo.Geocoding();

  @override
  Future<RoutePath?> route(LatLng from, LatLng to) =>
      RouteClient.fetch(from, to);

  @override
  Future<LocationAccess> access() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    return _map(await Geolocator.checkPermission());
  }

  @override
  Future<LocationAccess> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return _map(perm);
  }

  static LocationAccess _map(LocationPermission p) => switch (p) {
    LocationPermission.always ||
    LocationPermission.whileInUse => LocationAccess.granted,
    LocationPermission.deniedForever => LocationAccess.deniedForever,
    _ => LocationAccess.denied,
  };

  @override
  Future<LatLng?> currentPosition() async {
    try {
      if (await requestAccess() != LocationAccess.granted) return null;
      // A recent fix is instant; fall back to a fresh one.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          DateTime.now().difference(last.timestamp) <
              const Duration(minutes: 3)) {
        return LatLng(last.latitude, last.longitude);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ResolvedPlace> reverse(LatLng p) async {
    try {
      final marks = await _geo
          .placemarkFromCoordinates(p.latitude, p.longitude)
          .timeout(const Duration(seconds: 6));
      if (marks.isEmpty) return const ResolvedPlace();
      final m = marks.first;
      bool good(String? s) =>
          s != null && s.trim().isNotEmpty && !_plusCode.hasMatch(s);
      final street = [
        if (good(m.name)) m.name!.trim(),
        if (good(m.thoroughfare) && m.thoroughfare != m.name)
          m.thoroughfare!.trim(),
      ];
      final line1 = street.isNotEmpty
          ? street.join(', ')
          : (good(m.street) ? m.street!.trim() : '');
      final area = good(m.subLocality)
          ? m.subLocality!.trim()
          : (good(m.locality) ? m.locality!.trim() : '');
      return ResolvedPlace(line1: line1, area: area);
    } catch (_) {
      return const ResolvedPlace();
    }
  }

  static final _plusCode = RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,}');

  @override
  Future<List<PlaceHit>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    try {
      final locs = await _geo
          .locationFromAddress('$q, Lahore, Pakistan')
          .timeout(const Duration(seconds: 6));
      final hits = <PlaceHit>[];
      for (final l in locs.take(4)) {
        final p = LatLng(l.latitude, l.longitude);
        if (!isInsideLahore(p)) continue;
        final place = await reverse(p);
        hits.add(
          PlaceHit(
            place.line1.isNotEmpty ? place.line1 : q,
            place.area.isNotEmpty ? '${place.area}, Lahore' : 'Lahore',
            p,
          ),
        );
      }
      return hits;
    } catch (_) {
      return const [];
    }
  }
}

/// Deterministic stand-in for tests: no map tiles, instant GPS fix.
class FakeLocationService extends LocationService {
  FakeLocationService({
    this.position = const LatLng(31.5107, 74.3445),
    this.place = const ResolvedPlace(
      line1: 'Main Boulevard',
      area: 'Gulberg III',
    ),
    this.denied = false,
  });

  final LatLng position;
  final ResolvedPlace place;
  final bool denied;

  @override
  bool get hasMap => false;

  @override
  Future<LocationAccess> access() async =>
      denied ? LocationAccess.denied : LocationAccess.granted;

  @override
  Future<LocationAccess> requestAccess() => access();

  @override
  Future<LatLng?> currentPosition() async => denied ? null : position;

  @override
  Future<ResolvedPlace> reverse(LatLng p) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return place;
  }

  @override
  Future<List<PlaceHit>> search(String query) async => [
    PlaceHit(place.line1, '${place.area}, Lahore', position),
  ];

  @override
  Future<void> openSettings() async {}
}
