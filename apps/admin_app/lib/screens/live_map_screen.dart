import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/launch.dart';
import '../utils/order_x.dart';
import '../utils/rider_state.dart';
import '../widgets/common.dart';
import 'order_detail_screen.dart';

/// Every rider and every open order on one map. Tap a pin for details.
class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final _controller = MapController();
  bool _ready = false;
  bool _fitted = false;
  bool _ridersOn = true;
  bool _ordersOn = true;

  static const _lahore = LatLng(31.5204, 74.3587);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<LpgOrder> _open(AdminSession s) => [
    for (final o in s.orders)
      if (o.status.isActive && o.address.hasLocation) o,
  ];

  void _fit(List<LatLng> pts) {
    if (!_ready || pts.isEmpty) return;
    if (pts.length == 1) {
      _controller.move(pts.first, 15);
    } else {
      _controller.fitCamera(
        CameraFit.coordinates(
          coordinates: pts,
          padding: const EdgeInsets.fromLTRB(48, 120, 48, 120),
          maxZoom: 16,
        ),
      );
    }
  }

  Future<void> _riderSheet(AdminSession s, RiderProfile r) {
    final jobs = s.jobsOf(r.uid);
    final st = riderStateIn(s, r, context.pal.muted);
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  Pill(Icons.circle, st.label, color: st.color),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                jobs.isEmpty
                    ? 'No orders right now.'
                    : '${jobs.length} order${jobs.length == 1 ? '' : 's'}: ${jobs.map((o) => o.areaLine).join(', ')}',
                style: TextStyle(color: ctx.pal.muted),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () => Launch.call(r.phone),
                icon: const Icon(Icons.call_rounded),
                label: Text('Call ${r.name.split(' ').first}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _orderSheet(
    AdminSession s,
    LpgOrder o,
  ) => showModalBottomSheet<void>(
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
              '${o.displayNumber} · ${o.customerName}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(o.itemsLine),
            Text(o.address.oneLine, style: TextStyle(color: ctx.pal.muted)),
            const SizedBox(height: 6),
            Text(
              o.riderName == null ? 'No rider yet' : 'Rider: ${o.riderName}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: o.riderName == null ? Brand.danger : Brand.success,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => OrderDetailScreen(orderId: o.id),
                        ),
                      );
                    },
                    child: const Text('Open order'),
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
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final pal = context.pal;
    final riders = [
      for (final r in s.riders)
        if (r.hasPosition && (r.isLive() || s.jobsOf(r.uid).isNotEmpty)) r,
    ];
    final orders = _open(s);
    final waiting = s.waitingForRider.map((o) => o.id).toSet();
    final points = [
      if (_ridersOn)
        for (final r in riders) LatLng(r.lat!, r.lng!),
      if (_ordersOn)
        for (final o in orders) LatLng(o.address.lat!, o.address.lng!),
    ];
    if (!_fitted && _ready && points.isNotEmpty) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit(points));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Live map')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _lahore,
              initialZoom: 11.5,
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
                userAgentPackageName: 'pk.alphalpg.admin',
                retinaMode: MediaQuery.devicePixelRatioOf(context) > 1.5,
              ),
              MarkerLayer(
                markers: [
                  if (_ordersOn)
                    for (final o in orders)
                      Marker(
                        point: LatLng(o.address.lat!, o.address.lng!),
                        width: 48,
                        height: 56,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () => _orderSheet(s, o),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 48,
                            color: waiting.contains(o.id)
                                ? const Color(0xFFD9480F)
                                : o.riderName == null
                                ? Brand.danger
                                : Brand.cylinderRed,
                            shadows: const [
                              Shadow(color: Color(0x66000000), blurRadius: 6),
                            ],
                          ),
                        ),
                      ),
                  if (_ridersOn)
                    for (final r in riders)
                      Marker(
                        point: LatLng(r.lat!, r.lng!),
                        width: 78,
                        height: 76,
                        child: GestureDetector(
                          onTap: () => _riderSheet(s, r),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: riderStateIn(s, r, pal.muted).color,
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
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  r.name.split(' ').first,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Brand.navy,
                                  ),
                                ),
                              ),
                            ],
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
          Positioned(
            left: 12,
            right: 12,
            top: 10,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Toggle(
                  icon: Icons.two_wheeler_rounded,
                  label:
                      '${riders.length} rider${riders.length == 1 ? '' : 's'}',
                  on: _ridersOn,
                  onTap: () => setState(() => _ridersOn = !_ridersOn),
                ),
                _Toggle(
                  icon: Icons.location_on_rounded,
                  label:
                      '${orders.length} order${orders.length == 1 ? '' : 's'}',
                  on: _ordersOn,
                  onTap: () => setState(() => _ordersOn = !_ordersOn),
                ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 28,
            child: FloatingActionButton.small(
              heroTag: 'fit',
              onPressed: () => _fit(points),
              tooltip: 'Show everyone',
              child: const Icon(Icons.center_focus_strong_rounded),
            ),
          ),
          if (riders.isEmpty && orders.isEmpty)
            Positioned(
              left: 24,
              right: 24,
              bottom: 40,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pal.card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: pal.shadow,
                ),
                child: const Text(
                  'Nothing to show yet. Riders appear here while they are on shift with location on, and open orders appear once the customer has pinned a location.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: on ? Brand.navy : Colors.white,
    elevation: 3,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: on ? Brand.flame : Brand.navy),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : Brand.navy,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
