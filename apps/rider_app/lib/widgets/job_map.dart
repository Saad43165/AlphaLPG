import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../services/routing.dart';
import '../utils/env.dart';
import '../utils/launch.dart';

/// What the rider's phone is doing about location, in plain words.
enum _Gps { checking, needsPermission, blocked, off, searching, ok }

/// The delivery spot, the rider's own position, the road route between them,
/// and a plain-language line saying what is going on.
class JobMap extends StatefulWidget {
  const JobMap({super.key, required this.address});
  final Address address;

  @override
  State<JobMap> createState() => _JobMapState();
}

class _JobMapState extends State<JobMap> with WidgetsBindingObserver {
  final _controller = MapController();
  StreamSubscription<Position>? _sub;
  Timer? _searchTimer;
  LatLng? _me;
  DateTime? _fixAt;
  bool _ready = false;
  bool _follow = true;
  _Gps _gps = _Gps.checking;
  RoutePath? _route;
  bool _routeFailed = false;
  LatLng? _routedFrom;
  DateTime _routedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _routing = false;

  LatLng? get _dest => widget.address.hasLocation
      ? LatLng(widget.address.lat!, widget.address.lng!)
      : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  /// Back from the phone's settings: look again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _gps != _Gps.ok) _start();
  }

  Future<void> _start({bool ask = false}) async {
    await _sub?.cancel();
    _sub = null;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _gps = _Gps.off);
        return;
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied && ask) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.deniedForever) {
        if (mounted) setState(() => _gps = _Gps.blocked);
        return;
      }
      if (p != LocationPermission.always &&
          p != LocationPermission.whileInUse) {
        if (mounted) setState(() => _gps = _Gps.needsPermission);
        return;
      }
      if (mounted) setState(() => _gps = _Gps.searching);
      // A quick first position, then the live stream.
      unawaited(
        Geolocator.getLastKnownPosition().then((last) {
          if (last != null && _me == null) _onPosition(last);
        }),
      );
      _sub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 8,
            ),
          ).listen(
            _onPosition,
            onError: (_) {
              if (mounted) setState(() => _gps = _Gps.off);
            },
          );
      // Some phones are slow to give the first fix.
      _searchTimer?.cancel();
      _searchTimer = Timer(const Duration(seconds: 12), () async {
        if (_me != null || !mounted) return;
        try {
          _onPosition(
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 15),
              ),
            ),
          );
        } catch (_) {}
      });
    } catch (_) {
      if (mounted) setState(() => _gps = _Gps.off);
    }
  }

  void _onPosition(Position pos) {
    if (!mounted) return;
    setState(() {
      _me = LatLng(pos.latitude, pos.longitude);
      _fixAt = DateTime.now();
      _gps = _Gps.ok;
    });
    if (_follow) _fit();
    _maybeRoute();
  }

  /// A road route, refreshed when the rider has moved a fair way.
  Future<void> _maybeRoute() async {
    final me = _me;
    final dest = _dest;
    if (me == null || dest == null || _routing) return;
    final moved = _routedFrom == null
        ? double.infinity
        : const Distance().as(LengthUnit.Meter, _routedFrom!, me);
    final age = DateTime.now().difference(_routedAt);
    if (_route != null && moved < 200 && age < const Duration(minutes: 2)) {
      return;
    }
    if (_route == null && _routeFailed && age < const Duration(seconds: 30)) {
      return;
    }
    _routing = true;
    final r = await RouteClient.fetch(me, dest, geoapifyKey: Env.geoapifyKey);
    _routing = false;
    if (!mounted) return;
    setState(() {
      _routedFrom = me;
      _routedAt = DateTime.now();
      if (r != null) {
        _route = r;
        _routeFailed = false;
      } else {
        _routeFailed = true;
      }
    });
    if (_follow) _fit();
  }

  void _fit() {
    if (!_ready) return;
    final me = _me;
    final dest = _dest;
    if (dest == null) return;
    if (me == null) {
      _controller.move(dest, 16);
    } else {
      _controller.fitCamera(
        CameraFit.coordinates(
          coordinates: [me, dest, ...?_route?.points],
          padding: const EdgeInsets.fromLTRB(56, 64, 56, 56),
          maxZoom: 17,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchTimer?.cancel();
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  (IconData, Color, String, String?, VoidCallback?) _status() {
    const amber = Brand.warning;
    switch (_gps) {
      case _Gps.checking:
        return (
          Icons.location_searching_rounded,
          amber,
          'Checking your location…',
          null,
          null,
        );
      case _Gps.needsPermission:
        return (
          Icons.location_disabled_rounded,
          Brand.danger,
          'Allow location so the map can show where you are and the way to the customer.',
          'Allow',
          () => _start(ask: true),
        );
      case _Gps.blocked:
        return (
          Icons.location_off_rounded,
          Brand.danger,
          'Location is blocked for this app. Open Settings, then Permissions, then Location, and allow it.',
          'Settings',
          Geolocator.openAppSettings,
        );
      case _Gps.off:
        return (
          Icons.gps_off_rounded,
          Brand.danger,
          'Your phone\'s location (GPS) is off. Turn it on to see the route.',
          'Turn on',
          Geolocator.openLocationSettings,
        );
      case _Gps.searching:
        return (
          Icons.location_searching_rounded,
          amber,
          'Finding your position… If you are indoors, step outside.',
          null,
          null,
        );
      case _Gps.ok:
        final route = _route;
        final km = _dest == null || _me == null
            ? null
            : const Distance().as(LengthUnit.Meter, _me!, _dest!) / 1000;
        final text = route != null
            ? '${route.km.toStringAsFixed(1)} km by road · about ${route.minutes} min'
            : km == null
            ? 'Your position is on the map.'
            : _routeFailed
            ? '${km.toStringAsFixed(1)} km in a straight line. Road route unavailable (check internet).'
            : '${km.toStringAsFixed(1)} km away. Finding the road route…';
        return (Icons.my_location_rounded, Brand.success, text, null, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = Env.geoapifyKey;
    final dest = _dest;
    final (icon, color, text, actionLabel, action) = _status();
    final routePoints = _route?.points;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          decoration: BoxDecoration(
            color: context.pal.card,
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),
              if (action != null)
                TextButton(onPressed: action, child: Text(actionLabel!)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (dest == null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.pal.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.pal.warn, width: 2),
            ),
            child: Text(
              'The customer did not pin the spot on the map. Use the address below, or call the customer to ask the way.',
              style: TextStyle(
                color: context.pal.ink,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 260,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _controller,
                    options: MapOptions(
                      initialCenter: dest,
                      initialZoom: 16,
                      minZoom: 8,
                      maxZoom: 19,
                      backgroundColor: const Color(0xFFE6ECF2),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onMapReady: () {
                        _ready = true;
                        _fit();
                      },
                      // The rider moved the map: stop snapping back.
                      onPositionChanged: (_, byGesture) {
                        if (byGesture && _follow) {
                          setState(() => _follow = false);
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: key.isEmpty
                            ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                            : 'https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}{r}.png?apiKey=$key',
                        fallbackUrl:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'pk.alphalpg.rider',
                        retinaMode:
                            MediaQuery.devicePixelRatioOf(context) > 1.5,
                      ),
                      if (routePoints != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: routePoints,
                              strokeWidth: 8,
                              color: Colors.white,
                            ),
                            Polyline(
                              points: routePoints,
                              strokeWidth: 5,
                              color: Brand.blueDark,
                            ),
                          ],
                        )
                      else if (_me != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [_me!, dest],
                              strokeWidth: 3,
                              color: Brand.blueDark.withValues(alpha: 0.6),
                              pattern: StrokePattern.dashed(
                                segments: const [8, 8],
                              ),
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: dest,
                            width: 46,
                            height: 56,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Brand.cylinderRed,
                              size: 46,
                            ),
                          ),
                          if (_me != null)
                            Marker(
                              point: _me!,
                              width: 44,
                              height: 44,
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
                                  size: 22,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SimpleAttributionWidget(
                        source: Text(
                          key.isEmpty ? '© OpenStreetMap contributors' : 'Powered by Geoapify · © OpenStreetMap contributors',
                        ),
                        backgroundColor: const Color(0xB3FFFFFF),
                        alignment: Alignment.bottomLeft,
                      ),
                    ],
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _RoundButton(
                      icon: _follow
                          ? Icons.center_focus_strong_rounded
                          : Icons.my_location_rounded,
                      tip: 'Show me and the customer',
                      onTap: () {
                        setState(() => _follow = true);
                        _fit();
                      },
                    ),
                  ),
                  if (_fixAt != null)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(color: Color(0x33000000), blurRadius: 6),
                          ],
                        ),
                        child: const Text(
                          'You: blue · Customer: red',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            color: Brand.navy,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => Launch.navigate(
            lat: widget.address.lat,
            lng: widget.address.lng,
            address: widget.address.oneLine,
          ),
          icon: const Icon(Icons.navigation_rounded),
          label: const Text('Start navigation (Google Maps)'),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tip,
    required this.onTap,
  });
  final IconData icon;
  final String tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 3,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Tooltip(
        message: tip,
        child: SizedBox.square(
          dimension: 42,
          child: Icon(icon, color: Brand.navy, size: 22),
        ),
      ),
    ),
  );
}
