import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/launch.dart';
import '../utils/order_x.dart';
import 'job_detail_screen.dart';

/// All of the rider's stops on one map, numbered in the order to visit.
class StopsMapScreen extends StatefulWidget {
  const StopsMapScreen({super.key});

  @override
  State<StopsMapScreen> createState() => _StopsMapScreenState();
}

class _StopsMapScreenState extends State<StopsMapScreen> {
  final _controller = MapController();
  bool _ready = false;
  bool _fitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fit(List<LatLng> pts) {
    if (!_ready || pts.isEmpty) return;
    if (pts.length == 1) {
      _controller.move(pts.first, 15.5);
    } else {
      _controller.fitCamera(
        CameraFit.coordinates(
          coordinates: pts,
          padding: const EdgeInsets.fromLTRB(48, 100, 48, 200),
          maxZoom: 16.5,
        ),
      );
    }
  }

  Future<void> _stopSheet(RouteStop st) {
    final o = st.order;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stop ${st.number} · ${o.customerName}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 4),
              Text(o.address.oneLine),
              Text(o.itemsLine, style: TextStyle(color: ctx.pal.muted)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: () => Launch.navigate(
                        lat: o.address.lat,
                        lng: o.address.lng,
                        address: o.address.oneLine,
                      ),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Navigate'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: () => Launch.call(o.customerPhone),
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('Call'),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => JobDetailScreen(orderId: o.id),
                    ),
                  );
                },
                child: const Text('Open order'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RiderSession>();
    final stops = [
      for (final st in s.route)
        if (st.order.address.hasLocation) st,
    ];
    final me = s.profile?.hasPosition == true
        ? LatLng(s.profile!.lat!, s.profile!.lng!)
        : null;
    final points = [
      ?me,
      for (final st in stops)
        LatLng(st.order.address.lat!, st.order.address.lng!),
    ];
    if (_ready && !_fitted && points.isNotEmpty) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit(points));
    }
    final next = stops.isEmpty ? null : stops.first;
    return Scaffold(
      appBar: AppBar(title: const Text('My stops')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: me ?? const LatLng(31.5204, 74.3587),
              initialZoom: 12,
              minZoom: 8,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              backgroundColor: const Color(0xFFE6ECF2),
              onMapReady: () {
                _ready = true;
                if (points.isNotEmpty && !_fitted) {
                  _fitted = true;
                  _fit(points);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'pk.alphalpg.rider',
                retinaMode: MediaQuery.devicePixelRatioOf(context) > 1.5,
              ),
              if (stops.length + (me == null ? 0 : 1) >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      strokeWidth: 4,
                      color: Brand.blueDark,
                      pattern: StrokePattern.dashed(segments: [10, 8]),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final st in stops)
                    Marker(
                      point: LatLng(
                        st.order.address.lat!,
                        st.order.address.lng!,
                      ),
                      width: 46,
                      height: 46,
                      child: GestureDetector(
                        onTap: () => _stopSheet(st),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: st.number == 1
                                ? Brand.cylinderRed
                                : Brand.navy,
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
                          child: Text(
                            '${st.number}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (me != null)
                    Marker(
                      point: me,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Brand.blueDark,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
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
                source: Text('© OpenStreetMap', style: TextStyle(fontSize: 10)),
                backgroundColor: Color(0xB3FFFFFF),
                alignment: Alignment.bottomLeft,
              ),
            ],
          ),
          if (next != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.pal.card,
                  borderRadius: BorderRadius.circular(Brand.radius),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Brand.cylinderRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '1',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NEXT STOP',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: Brand.cylinderRed,
                            ),
                          ),
                          Text(
                            next.order.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            [
                              next.order.areaLine,
                              if (next.km != null)
                                '${next.km!.toStringAsFixed(1)} km',
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.pal.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => Launch.navigate(
                        lat: next.order.address.lat,
                        lng: next.order.address.lng,
                        address: next.order.address.oneLine,
                      ),
                      child: const Icon(Icons.navigation_rounded),
                    ),
                  ],
                ),
              ),
            ),
          if (stops.isEmpty)
            Positioned(
              left: 24,
              right: 24,
              bottom: 40,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.pal.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'No stops with a map pin yet. Accept an order whose customer pinned their location.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
