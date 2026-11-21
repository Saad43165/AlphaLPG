import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../services/backend.dart';
import '../services/location_service.dart';
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

/// The rider on a map while the order is out for delivery.
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

  void _fit(RiderLocation loc) {
    final a = widget.order.address;
    if (!_ready || !a.hasLocation) return;
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: [LatLng(loc.lat, loc.lng), LatLng(a.lat!, a.lng!)],
        padding: const EdgeInsets.all(56),
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
        if (!fresh) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(Brand.radius),
              border: Border.all(color: pal.line),
            ),
            child: Row(
              children: [
                MediaQuery.disableAnimationsOf(context)
                    ? const Icon(Icons.two_wheeler_rounded, size: 22)
                    : const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    loc == null
                        ? 'Your rider is on the way. Waiting for their location…'
                        : 'Location paused. Your rider is still on the way.',
                    style: TextStyle(color: pal.muted, height: 1.35),
                  ),
                ),
              ],
            ),
          );
        }
        final hasPin = o.address.hasLocation;
        final metres = hasPin ? metresBetween(loc, o.address) : null;
        WidgetsBinding.instance.addPostFrameCallback((_) => _fit(loc));
        final svc = context.read<LocationService>();
        final ago = DateTime.now().difference(loc.updatedAt!).inSeconds;
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
                height: 230,
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
                    : FlutterMap(
                        mapController: _controller,
                        options: MapOptions(
                          initialCenter: LatLng(loc.lat, loc.lng),
                          initialZoom: 15,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                          backgroundColor: const Color(0xFFE6ECF2),
                          onMapReady: () {
                            _ready = true;
                            _fit(loc);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: svc.tiles(dark: false).urlTemplate,
                            // If the paid-style tiles fail (bad key, restriction, outage), show OpenStreetMap instead of a blank map.
                            fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'pk.alphalpg.customer',
                            retinaMode:
                                MediaQuery.devicePixelRatioOf(context) > 1.5,
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(o.address.lat!, o.address.lng!),
                                width: 44,
                                height: 54,
                                alignment: Alignment.topCenter,
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Brand.cylinderRed,
                                  size: 44,
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
                            source: Text(svc.attribution),
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
                    const Icon(Icons.near_me_rounded, color: Brand.blueDark),
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
                                : 'About ${estimatedMinutes(metres, loc.speedKmh)} min away',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            [
                              if (metres != null && metres >= 150)
                                '${(metres / 1000).toStringAsFixed(1)} km straight-line',
                              'estimate',
                              'updated ${ago < 10 ? 'just now' : '${ago}s ago'}',
                            ].join(' · '),
                            style: TextStyle(color: pal.muted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
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
