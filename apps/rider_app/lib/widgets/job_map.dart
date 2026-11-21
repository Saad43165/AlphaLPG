import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../utils/env.dart';
import '../utils/launch.dart';

/// The delivery spot (and the rider's own position) on a bright, readable map.
class JobMap extends StatefulWidget {
  const JobMap({super.key, required this.address});
  final Address address;

  @override
  State<JobMap> createState() => _JobMapState();
}

class _JobMapState extends State<JobMap> {
  final _controller = MapController();
  StreamSubscription<Position>? _sub;
  LatLng? _me;
  bool _ready = false;

  LatLng get _dest => LatLng(widget.address.lat!, widget.address.lng!);

  @override
  void initState() {
    super.initState();
    _listen();
  }

  /// Uses the rider's position only if location is already allowed here
  /// (the app asks for it when a delivery starts).
  Future<void> _listen() async {
    try {
      final p = await Geolocator.checkPermission();
      if (p != LocationPermission.always &&
          p != LocationPermission.whileInUse) {
        return;
      }
      _sub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(distanceFilter: 15),
          ).listen((pos) {
            if (!mounted) return;
            setState(() => _me = LatLng(pos.latitude, pos.longitude));
            _fit();
          }, onError: (_) {});
    } catch (_) {}
  }

  void _fit() {
    if (!_ready) return;
    final me = _me;
    if (me == null) {
      _controller.move(_dest, 16);
    } else {
      _controller.fitCamera(
        CameraFit.coordinates(
          coordinates: [me, _dest],
          padding: const EdgeInsets.all(64),
          maxZoom: 17,
        ),
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final key = Env.geoapifyKey;
    final km = _me == null
        ? null
        : const Distance().as(LengthUnit.Meter, _me!, _dest) / 1000;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 240,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: _dest,
                initialZoom: 16,
                minZoom: 10,
                maxZoom: 19,
                backgroundColor: const Color(0xFFE6ECF2),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: () {
                  _ready = true;
                  _fit();
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: key.isEmpty
                      ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                      : 'https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}{r}.png?apiKey=$key',
                  // Never a blank map: fall back to OpenStreetMap.
                  fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'pk.alphalpg.rider',
                  retinaMode: MediaQuery.devicePixelRatioOf(context) > 1.5,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _dest,
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
                            border: Border.all(color: Colors.white, width: 3),
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
                    key.isEmpty
                        ? '© OpenStreetMap contributors'
                        : 'Powered by Geoapify · © OpenStreetMap contributors',
                  ),
                  backgroundColor: const Color(0xB3FFFFFF),
                  alignment: Alignment.bottomLeft,
                ),
              ],
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Column(
                children: [
                  _RoundButton(
                    icon: Icons.center_focus_strong_rounded,
                    tip: 'Fit both on the map',
                    onTap: _fit,
                  ),
                  const SizedBox(height: 8),
                  _RoundButton(
                    icon: Icons.navigation_rounded,
                    tip: 'Navigate in Google Maps',
                    onTap: () => Launch.navigate(
                      lat: widget.address.lat,
                      lng: widget.address.lng,
                      address: widget.address.oneLine,
                    ),
                  ),
                ],
              ),
            ),
            if (km != null)
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: pal.isDark ? Brand.navy : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33000000), blurRadius: 6),
                    ],
                  ),
                  child: Text(
                    '${km.toStringAsFixed(1)} km away',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: pal.isDark ? Colors.white : Brand.navy,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
