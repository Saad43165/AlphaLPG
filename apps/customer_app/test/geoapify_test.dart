import 'dart:convert';

import 'package:alpha_customer/services/geoapify.dart';
import 'package:alpha_customer/services/location_service.dart';
import 'package:alpha_customer/services/routing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

// Response shapes follow Geoapify's documented `format=json` output. They
// have not been checked against the live service from the build machine.
void main() {
  const key = 'test-key';
  late List<Uri> requests;

  GeoapifyLocationService service(
    Map<String, dynamic> Function(Uri) body, {
    int status = 200,
  }) {
    requests = [];
    return GeoapifyLocationService(
      key,
      client: MockClient((req) async {
        requests.add(req.url);
        return http.Response(jsonEncode(body(req.url)), status);
      }),
    );
  }

  test('reverse: street and neighbourhood come from the pin', () async {
    final s = service(
      (_) => {
        'results': [
          {
            'address_line1': 'Main Boulevard',
            'address_line2': 'Gulberg III, Lahore',
            'suburb': 'Gulberg III',
            'city': 'Lahore',
          },
        ],
      },
    );
    final p = await s.reverse(const LatLng(31.5107, 74.3445));
    expect(p.line1, 'Main Boulevard');
    expect(p.area, 'Gulberg III');
    final q = requests.single;
    expect(q.host, 'api.geoapify.com');
    expect(q.path, '/v1/geocode/reverse');
    expect(q.queryParameters['lat'], '31.5107');
    expect(q.queryParameters['lon'], '74.3445');
    expect(q.queryParameters['apiKey'], key);
  });

  test(
    'reverse: an area-only result does not repeat the area as the street',
    () async {
      final s = service(
        (_) => {
          'results': [
            {'address_line1': 'Johar Town', 'suburb': 'Johar Town'},
          ],
        },
      );
      final p = await s.reverse(const LatLng(31.47, 74.27));
      expect(p.line1, isEmpty);
      expect(p.area, 'Johar Town');
    },
  );

  test('reverse: GeoJSON-shaped replies are understood too', () async {
    final s = service(
      (_) => {
        'features': [
          {
            'properties': {
              'street': 'Canal Road',
              'housenumber': '12',
              'district': 'Model Town',
            },
          },
        ],
      },
    );
    final p = await s.reverse(const LatLng(31.48, 74.32));
    expect(p.line1, '12 Canal Road');
    expect(p.area, 'Model Town');
  });

  test('search: suggestions stay inside Lahore and carry area names', () async {
    final s = service(
      (_) => {
        'results': [
          {
            'lat': 31.5107,
            'lon': 74.3445,
            'address_line1': 'Gulberg Main Market',
            'suburb': 'Gulberg III',
          },
          {
            'lat': 33.6844,
            'lon': 73.0479,
            'address_line1': 'Blue Area',
            'suburb': 'Islamabad',
          },
          {'lat': 'bad', 'lon': 74.3, 'address_line1': 'Broken'},
        ],
      },
    );
    final hits = await s.search('gulberg');
    expect(hits, hasLength(1));
    expect(hits.single.title, 'Gulberg Main Market');
    expect(hits.single.subtitle, 'Gulberg III, Lahore');
    final q = requests.single;
    expect(q.path, '/v1/geocode/autocomplete');
    expect(q.queryParameters['filter'], 'countrycode:pk');
    expect(q.queryParameters['text'], 'gulberg');
  });

  test('search: very short text makes no network call', () async {
    final s = service((_) => {'results': []});
    expect(await s.search('gu'), isEmpty);
    expect(requests, isEmpty);
  });

  test('tiles: light and dark styles carry the key and retina slot', () {
    final s = service((_) => {});
    final light = s.tiles(dark: false);
    final dark = s.tiles(dark: true);
    expect(light.urlTemplate, contains('osm-bright'));
    expect(dark.urlTemplate, contains('dark-matter'));
    for (final t in [light, dark]) {
      expect(t.urlTemplate, contains('{z}/{x}/{y}{r}.png'));
      expect(t.urlTemplate, endsWith('apiKey=$key'));
      expect(t.darkIsNative, isTrue);
    }
    expect(s.attribution, contains('Geoapify'));
  });

  test('without a key the app uses the phone services and OSM', () {
    final s = defaultLocationService('');
    expect(s, isA<DeviceLocationService>());
    expect(s.tiles(dark: false).urlTemplate, contains('openstreetmap'));
    expect(defaultLocationService('abc'), isA<GeoapifyLocationService>());
  });

  test('a failing service never crashes the picker', () async {
    final s = service((_) => {}, status: 429);
    expect(await s.search('gulberg'), isEmpty);
  });

  group('road routes', () {
    test('Geoapify response: line, distance and time', () {
      final r = RouteClient.parseGeoapify({
        'features': [
          {
            'properties': {'distance': 3400, 'time': 780},
            'geometry': {
              'type': 'MultiLineString',
              'coordinates': [
                [
                  [74.3445, 31.5107],
                  [74.3500, 31.5150],
                ],
                [
                  [74.3500, 31.5150],
                  [74.3587, 31.5204],
                ],
              ],
            },
          },
        ],
      })!;
      expect(r.points.length, 4);
      expect(r.points.first.latitude, closeTo(31.5107, 1e-9));
      expect(r.points.first.longitude, closeTo(74.3445, 1e-9));
      expect(r.km, closeTo(3.4, 1e-9));
      expect(r.minutes, 13);
    });

    test('OSRM response: GeoJSON line', () {
      final r = RouteClient.parseOsrm({
        'routes': [
          {
            'distance': 1200.5,
            'duration': 90,
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [74.3, 31.5],
                [74.31, 31.51],
              ],
            },
          },
        ],
      })!;
      expect(r.points.length, 2);
      expect(r.minutes, 2);
    });

    test('garbage gives null, never a crash', () {
      expect(RouteClient.parseGeoapify({'features': []}), isNull);
      expect(RouteClient.parseGeoapify('nope'), isNull);
      expect(RouteClient.parseOsrm({'routes': [{}]}), isNull);
    });
  });
}
