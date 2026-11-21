import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A driving route: the line to draw, how far and how long.
class RoutePath {
  const RoutePath({
    required this.points,
    required this.meters,
    required this.seconds,
  });
  final List<LatLng> points;
  final double meters;
  final double seconds;

  double get km => meters / 1000;
  int get minutes => (seconds / 60).ceil().clamp(1, 999);
}

/// Road routes from Geoapify (when a key is supplied) or, as a fallback, the
/// public OSRM demo server. Never throws: returns null if nothing worked, so
/// the map can fall back to a straight-line estimate.
abstract final class RouteClient {
  static const _timeout = Duration(seconds: 8);

  static Future<RoutePath?> fetch(
    LatLng from,
    LatLng to, {
    String geoapifyKey = '',
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    if (geoapifyKey.isNotEmpty) {
      try {
        final uri = Uri.https('api.geoapify.com', '/v1/routing', {
          'waypoints':
              '${from.latitude},${from.longitude}|${to.latitude},${to.longitude}',
          'mode': 'drive',
          'apiKey': geoapifyKey,
        });
        final res = await c.get(uri).timeout(_timeout);
        if (res.statusCode == 200) {
          final r = parseGeoapify(jsonDecode(res.body));
          if (r != null) return r;
        }
      } catch (_) {}
    }
    try {
      final uri = Uri.https(
        'router.project-osrm.org',
        '/route/v1/driving/'
            '${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
        {'overview': 'full', 'geometries': 'geojson'},
      );
      final res = await c.get(uri).timeout(_timeout);
      if (res.statusCode == 200) return parseOsrm(jsonDecode(res.body));
    } catch (_) {}
    return null;
  }

  static List<LatLng> _line(Object? coords) {
    final out = <LatLng>[];
    void add(Object? p) {
      if (p is List && p.length >= 2 && p[0] is num && p[1] is num) {
        out.add(LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()));
      } else if (p is List) {
        p.forEach(add);
      }
    }

    add(coords);
    return out;
  }

  /// Geoapify: `features[0].properties{distance,time}` and a (Multi)LineString
  /// whose coordinates are `[lon, lat]`.
  static RoutePath? parseGeoapify(Object? json) {
    try {
      final f = ((json as Map)['features'] as List).first as Map;
      final props = f['properties'] as Map;
      final pts = _line((f['geometry'] as Map)['coordinates']);
      final d = (props['distance'] as num?)?.toDouble();
      final t = (props['time'] as num?)?.toDouble();
      if (pts.length < 2 || d == null || t == null) return null;
      return RoutePath(points: pts, meters: d, seconds: t);
    } catch (_) {
      return null;
    }
  }

  /// OSRM: `routes[0]{distance,duration,geometry}` (GeoJSON).
  static RoutePath? parseOsrm(Object? json) {
    try {
      final r = ((json as Map)['routes'] as List).first as Map;
      final pts = _line((r['geometry'] as Map)['coordinates']);
      final d = (r['distance'] as num?)?.toDouble();
      final t = (r['duration'] as num?)?.toDouble();
      if (pts.length < 2 || d == null || t == null) return null;
      return RoutePath(points: pts, meters: d, seconds: t);
    } catch (_) {
      return null;
    }
  }
}
