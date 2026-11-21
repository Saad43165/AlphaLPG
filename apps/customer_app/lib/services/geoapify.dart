import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'location_service.dart';
import 'routing.dart';

/// Map tiles, address search and "address from a pin" from Geoapify
/// (geoapify.com). GPS still comes from the phone.
///
/// Free plan: no card needed. Attribution is required, and Geoapify's terms
/// should be checked before storing results for long periods.
class GeoapifyLocationService extends DeviceLocationService {
  GeoapifyLocationService(this.apiKey, {http.Client? client})
    : _http = client ?? http.Client();

  final String apiKey;
  final http.Client _http;

  static const _timeout = Duration(seconds: 8);

  @override
  MapTiles tiles({required bool dark}) => MapTiles(
    'https://maps.geoapify.com/v1/tile/${dark ? 'dark-matter' : 'osm-bright'}'
    '/{z}/{x}/{y}{r}.png?apiKey=$apiKey',
    darkIsNative: true,
  );

  @override
  String get attribution =>
      'Powered by Geoapify · © OpenMapTiles © OpenStreetMap contributors';

  Future<List<Map<String, dynamic>>> _get(
    String path,
    Map<String, String> query,
  ) async {
    final uri = Uri.https('api.geoapify.com', path, {
      ...query,
      'format': 'json',
      'apiKey': apiKey,
    });
    final res = await _http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) {
      throw http.ClientException('Geoapify ${res.statusCode}', uri);
    }
    final body = jsonDecode(res.body);
    if (body is! Map) return const [];
    // `format=json` gives `results`; GeoJSON gives `features[].properties`.
    final results = body['results'];
    if (results is List) {
      return [
        for (final r in results)
          if (r is Map) Map<String, dynamic>.from(r),
      ];
    }
    final features = body['features'];
    if (features is List) {
      return [
        for (final f in features)
          if (f is Map && f['properties'] is Map)
            Map<String, dynamic>.from(f['properties'] as Map),
      ];
    }
    return const [];
  }

  static String _s(Object? v) => v is String ? v.trim() : '';

  /// Street / building name for a result.
  static String _line1(Map<String, dynamic> r) {
    final line1 = _s(r['address_line1']);
    if (line1.isNotEmpty) return line1;
    final street = _s(r['street']);
    final number = _s(r['housenumber']);
    return [number, street].where((e) => e.isNotEmpty).join(' ');
  }

  /// Neighbourhood for a result: suburb, then district, then city.
  static String _area(Map<String, dynamic> r) {
    for (final k in const ['suburb', 'neighbourhood', 'district', 'city']) {
      final v = _s(r[k]);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  @override
  Future<RoutePath?> route(LatLng from, LatLng to) =>
      RouteClient.fetch(from, to, geoapifyKey: apiKey, client: _http);

  @override
  Future<ResolvedPlace> reverse(LatLng p) async {
    try {
      final rows = await _get('/v1/geocode/reverse', {
        'lat': '${p.latitude}',
        'lon': '${p.longitude}',
        'lang': 'en',
      });
      if (rows.isNotEmpty) {
        final r = rows.first;
        var line1 = _line1(r);
        final area = _area(r);
        // Do not repeat the area as the street line.
        if (line1.toLowerCase() == area.toLowerCase()) line1 = '';
        if (line1.isNotEmpty || area.isNotEmpty) {
          return ResolvedPlace(line1: line1, area: area);
        }
      }
    } catch (_) {
      // Fall through to the phone's own geocoder.
    }
    return super.reverse(p);
  }

  @override
  Future<List<PlaceHit>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    try {
      final rows = await _get('/v1/geocode/autocomplete', {
        'text': q,
        'filter': 'countrycode:pk',
        'bias': 'proximity:${lahoreCentre.longitude},${lahoreCentre.latitude}',
        'limit': '6',
        'lang': 'en',
      });
      final hits = <PlaceHit>[];
      for (final r in rows) {
        final lat = r['lat'], lon = r['lon'];
        if (lat is! num || lon is! num) continue;
        final point = LatLng(lat.toDouble(), lon.toDouble());
        if (!isInsideLahore(point)) continue;
        final title = _line1(r).isNotEmpty ? _line1(r) : _s(r['formatted']);
        final area = _area(r);
        hits.add(
          PlaceHit(title, area.isNotEmpty ? '$area, Lahore' : 'Lahore', point),
        );
      }
      return hits;
    } catch (_) {
      return super.search(q);
    }
  }
}

/// The location service for this build: Geoapify when a key was supplied,
/// otherwise the phone's own services with OpenStreetMap tiles.
LocationService defaultLocationService(String geoapifyKey) =>
    geoapifyKey.isEmpty
    ? DeviceLocationService()
    : GeoapifyLocationService(geoapifyKey);
