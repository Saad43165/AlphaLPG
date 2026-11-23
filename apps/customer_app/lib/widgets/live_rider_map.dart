import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart' hide Text;

import '../l10n/lang.dart';

import 'package:material_ui/material_ui.dart' as mu show Text;

import '../l10n/text.dart';

import 'package:provider/provider.dart';

import '../services/backend.dart';
import '../services/location_service.dart';
import '../services/routing.dart';
import '../utils/format.dart';
import '../theme/brand.dart';
import 'live.dart';

/// Distance in metres between the rider and the delivery spot.
double metresBetween(RiderLocation rider, Address to) => const Distance().as(
  LengthUnit.Meter,
  LatLng(rider.lat, rider.lng),
  LatLng(to.lat ?? rider.lat, to.lng ?? rider.lng),
);

/// Honest arrival estimate from straight-line distance and the rider's speed
/// (at least 15 km/h, so a rider stopped at a light does not read "never").
/// Real roads are longer, so this is labelled an estimate in the UI.
int estimatedMinutes(double metres, double speedKmh) {
  final kmh = speedKmh < 15 ? 15.0 : speedKmh;
  return ((metres / 1000) / kmh * 60).ceil().clamp(1, 999);
}

/// The rider on a map while the order is out for delivery: the road route,
/// the rider, the delivery spot, distance and arrival time.
class LiveRiderMap extends StatefulWidget {
  const LiveRiderMap({super.key, required this.order});
  final LpgOrder order;

  @override
  State<LiveRiderMap> createState() => _LiveRiderMapState();
}

class _LiveRiderMapState extends State<LiveRiderMap> {
  final _controller = MapController();
  Timer? _tick;
  bool _ready = false;

  /// The customer dragged or zoomed the map: stop re-centring on their own.
  bool _userMoved = false;
  RoutePath? _route;
  LatLng? _routeFrom;
  DateTime? _routeAt;
  bool _fetching = false;
  String _lastFit = '';

  @override
  void initState() {
    super.initState();
    // Re-check "how old is the last update" without a new location arriving.
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Asks for a fresh road route when there is none, the rider moved well
  /// away from the last start point, or the route is getting old.
  void _maybeRoute(LocationService svc, RiderLocation loc, Address a) {
    if (_fetching || !a.hasLocation) return;
    final from = LatLng(loc.lat, loc.lng);
    final moved = _routeFrom == null
        ? 1e9
        : const Distance().as(LengthUnit.Meter, _routeFrom!, from);
    final age = _routeAt == null
        ? 999
        : DateTime.now().difference(_routeAt!).inSeconds;
    if (_route != null && moved < 120 && age < 90) return;
    // After a failure, wait a little before trying again.
    if (_route == null && _routeAt != null && age < 30) return;
    _fetching = true;
    _routeAt = DateTime.now();
    svc.route(from, LatLng(a.lat!, a.lng!)).then((r) {
      if (!mounted) return;
      setState(() {
        _fetching = false;
        if (r != null) {
          _route = r;
          _routeFrom = from;
        }
      });
    });
  }

  void _fit(RiderLocation loc, {bool force = false}) {
    final a = widget.order.address;
    if (!_ready || !a.hasLocation) return;
    if (_userMoved && !force) return;
    final key =
        '${loc.lat.toStringAsFixed(4)},${loc.lng.toStringAsFixed(4)},${_route?.points.length}';
    if (!force && key == _lastFit) return;
    _lastFit = key;
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: [
          LatLng(loc.lat, loc.lng),
          LatLng(a.lat!, a.lng!),
          ...?_route?.points,
        ],
        padding: const EdgeInsets.fromLTRB(48, 70, 48, 48),
        maxZoom: 17.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final pal = context.pal;
    final o = widget.order;
    return Live<RiderLocation?>(
      cacheKey: o.id,
      stream: () => backend.orders.watchRiderLocation(o.id),
      builder: (context, snap) {
        final loc = snap.data;
        final fresh = loc != null && loc.isFresh();
        if (o.arrivedAt != null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.pal.card,
              border: Border.all(color: Brand.success, width: 2),
              borderRadius: BorderRadius.circular(Brand.radius),
            ),
            child: const Row(
              children: [
                Icon(Icons.pin_drop_rounded, color: Brand.success, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your rider is at your door. Please keep your empty cylinders ready.',
                    style: TextStyle(fontWeight: FontWeight.w700, height: 1.35),
                  ),
                ),
              ],
            ),
          );
        }
        if (!fresh) {
          // No endless spinner: show the delivery spot on the map and say
          // honestly what is going on.
          return _WaitingMap(order: o, paused: loc != null);
        }
        final a = o.address;
        final hasPin = a.hasLocation;
        final svc = context.read<LocationService>();
        final metres = hasPin ? metresBetween(loc, a) : null;
        final route = _route;
        final minutes = route != null
            ? route.minutes
            : (metres == null ? null : estimatedMinutes(metres, loc.speedKmh));
        final km = route != null
            ? route.km
            : (metres == null ? null : metres / 1000);
        final ago = DateTime.now().difference(loc.updatedAt!).inSeconds;
        if (hasPin && svc.hasMap) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _maybeRoute(svc, loc, a);
            _fit(loc);
          });
        }
        return Container(
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(Brand.radius),
            boxShadow: pal.shadow,
            border: pal.isDark ? Border.all(color: pal.line) : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SizedBox(
                height: 340,
                child: !svc.hasMap || !hasPin
                    ? Container(
                        color: pal.tint,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.two_wheeler_rounded,
                          size: 48,
                          color: pal.muted,
                        ),
                      )
                    : Stack(
                        children: [
                          FlutterMap(
                            mapController: _controller,
                            options: MapOptions(
                              initialCenter: LatLng(loc.lat, loc.lng),
                              initialZoom: 15,
                              minZoom: 8,
                              maxZoom: 19,
                              interactionOptions: const InteractionOptions(
                                flags:
                                    InteractiveFlag.all &
                                    ~InteractiveFlag.rotate,
                              ),
                              backgroundColor: const Color(0xFFE6ECF2),
                              onPositionChanged: (_, byGesture) {
                                if (byGesture && !_userMoved) {
                                  setState(() => _userMoved = true);
                                }
                              },
                              onMapReady: () {
                                _ready = true;
                                _fit(loc, force: true);
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: svc.tiles(dark: false).urlTemplate,
                                fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'pk.alphalpg.customer',
                                retinaMode:
                                    MediaQuery.devicePixelRatioOf(context) >
                                    1.5,
                              ),
                              PolylineLayer(
                                polylines: [
                                  if (route != null)
                                    Polyline(
                                      points: route.points,
                                      strokeWidth: 5.5,
                                      color: Brand.blueDark,
                                      borderStrokeWidth: 2.5,
                                      borderColor: Colors.white,
                                    )
                                  else
                                    Polyline(
                                      points: [
                                        LatLng(loc.lat, loc.lng),
                                        LatLng(a.lat!, a.lng!),
                                      ],
                                      strokeWidth: 4,
                                      color: Brand.blueDark,
                                      pattern: StrokePattern.dashed(
                                        segments: [10, 8],
                                      ),
                                    ),
                                ],
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(a.lat!, a.lng!),
                                    width: 96,
                                    height: 76,
                                    alignment: Alignment.topCenter,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x33000000),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            a.label.isEmpty
                                                ? 'Your door'
                                                : a.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: Brand.navy,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.location_on_rounded,
                                          color: Brand.cylinderRed,
                                          size: 44,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Marker(
                                    point: LatLng(loc.lat, loc.lng),
                                    width: 46,
                                    height: 46,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Brand.blueDark,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x55000000),
                                            blurRadius: 8,
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.two_wheeler_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SimpleAttributionWidget(
                                source: mu.Text(svc.attribution),
                                backgroundColor: const Color(0xB3FFFFFF),
                                alignment: Alignment.bottomLeft,
                              ),
                            ],
                          ),
                          if (metres != null && metres >= 150)
                            Positioned(
                              left: 10,
                              top: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Brand.navy,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x44000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.two_wheeler_rounded,
                                      color: Brand.flame,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    mu.Text(
                                      '${minutes ?? '–'} min · ${km?.toStringAsFixed(1) ?? '–'} km',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Bring the whole trip back into view after panning.
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Material(
                              color: Colors.white,
                              elevation: 3,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  setState(() => _userMoved = false);
                                  _fit(loc, force: true);
                                },
                                child: Tooltip(
                                  message: tr('Show rider and my door'),
                                  child: SizedBox.square(
                                    dimension: 42,
                                    child: Icon(
                                      Icons.center_focus_strong_rounded,
                                      color: Brand.navy,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.near_me_rounded,
                          color: Brand.blueDark,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                metres == null
                                    ? 'Your rider is on the way'
                                    : metres < 150
                                    ? 'Your rider is almost there'
                                    : 'About $minutes min away',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                [
                                  if (km != null && (metres ?? 0) >= 150)
                                    route != null
                                        ? '${km.toStringAsFixed(1)} km by road'
                                        : '${km.toStringAsFixed(1)} km straight-line',
                                  if (route == null) 'estimate',
                                  'updated ${ago < 10 ? 'just now' : '${ago}s ago'}',
                                ].join(' · '),
                                style: TextStyle(
                                  color: pal.muted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (minutes != null && (metres ?? 0) >= 150) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _Stat(
                            'Distance',
                            km == null ? '–' : '${km.toStringAsFixed(1)} km',
                          ),
                          _Stat(
                            'Arrives about',
                            formatTime(
                              DateTime.now().add(Duration(minutes: minutes)),
                            ),
                          ),
                          _Stat('Time left', '$minutes min'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: context.pal.tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: context.pal.muted, fontSize: 11.5),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Before the rider's first position arrives (or when it goes quiet).
class _WaitingMap extends StatelessWidget {
  const _WaitingMap({required this.order, required this.paused});
  final LpgOrder order;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final svc = context.read<LocationService>();
    final a = order.address;
    return Container(
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(Brand.radius),
        boxShadow: pal.shadow,
        border: pal.isDark ? Border.all(color: pal.line) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (svc.hasMap && a.hasLocation)
            SizedBox(
              height: 170,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(a.lat!, a.lng!),
                  initialZoom: 15.5,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                  backgroundColor: const Color(0xFFE6ECF2),
                ),
                children: [
                  TileLayer(
                    urlTemplate: svc.tiles(dark: false).urlTemplate,
                    fallbackUrl:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'pk.alphalpg.customer',
                    retinaMode: MediaQuery.devicePixelRatioOf(context) > 1.5,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(a.lat!, a.lng!),
                        width: 44,
                        height: 54,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Brand.cylinderRed,
                          size: 44,
                        ),
                      ),
                    ],
                  ),
                  SimpleAttributionWidget(
                    source: mu.Text(svc.attribution),
                    backgroundColor: const Color(0xB3FFFFFF),
                    alignment: Alignment.bottomLeft,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  paused
                      ? Icons.location_searching_rounded
                      : Icons.two_wheeler_rounded,
                  color: Brand.blueDark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    paused
                        ? 'Your rider\'s location is paused. They are still on the way: call them if you need.'
                        : 'Your rider is on the way. Their live position appears here as soon as their phone shares it. You can call them below.',
                    style: TextStyle(color: pal.muted, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
