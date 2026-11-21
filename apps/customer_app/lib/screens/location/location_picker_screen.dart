import 'dart:async';

import 'package:alpha_core/alpha_core.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../services/location_service.dart';
import '../../state/app_state.dart';
import '../../theme/brand.dart';
import '../../utils/haptics.dart';
import '../../widgets/common.dart';

/// Pick the delivery spot on a map, the way ride and food apps do it:
/// the phone's location is found automatically, the address is filled in for
/// you, and you only drag the map if the pin is not quite right.
///
/// Pops with the saved [Address].
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initial});
  final Address? initial;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _map = MapController();
  final _note = TextEditingController();
  final _manualArea = TextEditingController();
  final _searchText = TextEditingController();
  final _searchFocus = FocusNode();

  late LatLng _center;
  ResolvedPlace _place = const ResolvedPlace();
  bool _resolving = true;
  bool _locating = false;
  bool _dragging = false;
  bool _mapReady = false;
  bool _saving = false;
  LocationAccess? _access;
  String _label = 'Home';

  bool _searchOpen = false;
  bool _searching = false;
  List<PlaceHit> _hits = const [];

  Timer? _debounce;
  Timer? _searchDebounce;
  int _resolveToken = 0;

  LocationService get _svc => context.read<LocationService>();

  static const _labels = [
    ('Home', Icons.home_rounded),
    ('Work', Icons.work_rounded),
    ('Shop', Icons.storefront_rounded),
    ('Other', Icons.place_rounded),
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    if (a != null && a.hasLocation) {
      _center = LatLng(a.lat!, a.lng!);
      _place = ResolvedPlace(line1: a.line1, area: a.area);
      _resolving = false;
      _label = a.label;
      _note.text = a.landmark;
    } else {
      _center = lahoreCentre;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initial == null || !widget.initial!.hasLocation) {
        _findMe(auto: true);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchDebounce?.cancel();
    _note.dispose();
    _manualArea.dispose();
    _searchText.dispose();
    _searchFocus.dispose();
    _map.dispose();
    super.dispose();
  }

  // ---- Location ---------------------------------------------------------

  Future<void> _findMe({bool auto = false}) async {
    setState(() => _locating = true);
    final svc = _svc;
    final pos = await svc.currentPosition();
    if (!mounted) return;
    if (pos == null) {
      final access = await svc.access();
      if (!mounted) return;
      setState(() {
        _locating = false;
        _access = access;
      });
      // Even without GPS the customer can still drag the map.
      if (auto) _resolveNow();
      return;
    }
    setState(() {
      _locating = false;
      _access = LocationAccess.granted;
    });
    _flyTo(pos, zoom: 17.5);
    Haptics.light();
  }

  void _flyTo(LatLng p, {double zoom = 17}) {
    setState(() => _center = p);
    if (_mapReady) _map.move(p, zoom);
    _resolveNow();
  }

  void _onMoved(MapCamera camera, bool hasGesture) {
    _center = camera.center;
    if (hasGesture) {
      if (!_dragging) setState(() => _dragging = true);
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _dragging = false);
        Haptics.select();
        _resolveNow();
      });
    }
  }

  Future<void> _resolveNow() async {
    final token = ++_resolveToken;
    setState(() => _resolving = true);
    final result = await _svc.reverse(_center);
    if (!mounted || token != _resolveToken) return;
    setState(() {
      _place = result;
      _resolving = false;
    });
  }

  // ---- Search -----------------------------------------------------------

  void _openSearch() {
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocus.requestFocus(),
    );
  }

  void _closeSearch() {
    _searchFocus.unfocus();
    setState(() {
      _searchOpen = false;
      _hits = const [];
      _searchText.clear();
    });
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _hits = const []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _searching = true);
      final hits = await _svc.search(q);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _searching = false;
      });
    });
  }

  // ---- Confirm ----------------------------------------------------------

  bool get _inside => isInsideLahore(_center);

  String get _area =>
      _place.area.isNotEmpty ? _place.area : _manualArea.text.trim();

  bool get _canConfirm =>
      !_resolving && !_saving && _inside && _area.isNotEmpty;

  Future<void> _confirm() async {
    final backend = context.read<Backend>();
    final state = context.read<AppState>();
    setState(() => _saving = true);
    try {
      final saved = await backend.profiles.saveAddress(
        state.uid!,
        Address(
          id: widget.initial?.id ?? '',
          label: _label,
          line1: _place.line1.isNotEmpty ? _place.line1 : 'Pinned location',
          area: _area,
          landmark: _note.text.trim(),
          lat: _center.latitude,
          lng: _center.longitude,
        ),
      );
      state.selectAddress(saved.id);
      Haptics.medium();
      if (mounted) context.pop(saved);
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          'Could not save this location. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---- UI ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final svc = context.read<LocationService>();
    return AnnotatedRegion(
      value: pal.isDark ? Brand.lightStatusBar : Brand.darkStatusBar,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _buildMap(svc, pal)),
                  Center(
                    child: Padding(
                      // The pin's tip sits on the exact centre of the map.
                      padding: const EdgeInsets.only(bottom: 56),
                      child: _Pin(
                        lifted: _dragging || _resolving && !_locating,
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Column(
                        children: [
                          _buildTopBar(pal),
                          if (_searchOpen) _buildSearchResults(pal),
                          if (!_searchOpen &&
                              _access != null &&
                              _access != LocationAccess.granted)
                            _buildAccessBanner(pal),
                          if (!_inside) _buildOutsideBanner(),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: _MyLocationButton(busy: _locating, onTap: _findMe),
                  ),
                ],
              ),
            ),
            _buildSheet(pal),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(LocationService svc, AppPalette pal) {
    if (!svc.hasMap) return _MapPlaceholder(dark: pal.isDark);
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: widget.initial?.hasLocation == true ? 17 : 13.5,
        minZoom: 10,
        maxZoom: 19,
        backgroundColor: pal.isDark
            ? const Color(0xFF0F1D2A)
            : const Color(0xFFE6ECF2),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          _mapReady = true;
          if (_center != lahoreCentre) _map.move(_center, 17);
        },
        onPositionChanged: _onMoved,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'pk.alphalpg.customer',
          maxNativeZoom: 19,
          tileBuilder: pal.isDark ? darkModeTileBuilder : null,
        ),
        const SimpleAttributionWidget(
          source: Text('© OpenStreetMap contributors'),
          backgroundColor: Color(0xB3FFFFFF),
          alignment: Alignment.bottomLeft,
        ),
      ],
    );
  }

  Widget _buildTopBar(AppPalette pal) {
    return Row(
      children: [
        _RoundButton(
          icon: _searchOpen ? Icons.close_rounded : Icons.arrow_back_rounded,
          tooltip: _searchOpen ? 'Close search' : 'Back',
          onTap: _searchOpen ? _closeSearch : () => context.pop(),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _searchOpen
                ? TextField(
                    controller: _searchText,
                    focusNode: _searchFocus,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search area, street or landmark',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  )
                : InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _openSearch,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: pal.muted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Search area or street',
                              style: TextStyle(
                                color: pal.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(AppPalette pal) {
    final saved = context
        .read<AppState>()
        .addresses
        .where((a) => a.hasLocation)
        .toList();
    final showSaved = _searchText.text.trim().length < 3 && saved.isNotEmpty;
    final empty = !showSaved && _hits.isEmpty;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: empty
          ? Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                _searchText.text.trim().length < 3
                    ? 'Type at least 3 letters, e.g. "Gulberg III"'
                    : (_searching
                          ? 'Searching…'
                          : 'No results. Try moving the map instead.'),
                style: TextStyle(color: pal.muted),
              ),
            )
          : ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                if (showSaved)
                  for (final a in saved)
                    ListTile(
                      leading: const Icon(Icons.bookmark_rounded),
                      title: Text(
                        a.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        a.oneLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        _closeSearch();
                        _flyTo(LatLng(a.lat!, a.lng!));
                      },
                    )
                else
                  for (final h in _hits)
                    ListTile(
                      leading: const Icon(Icons.place_rounded),
                      title: Text(
                        h.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(h.subtitle),
                      onTap: () {
                        _closeSearch();
                        _flyTo(h.point);
                      },
                    ),
              ],
            ),
    );
  }

  Widget _buildAccessBanner(AppPalette pal) {
    final forever = _access == LocationAccess.deniedForever;
    final off = _access == LocationAccess.serviceOff;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded, color: Brand.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              off
                  ? 'Location is off. Turn it on to find you instantly, or move the map.'
                  : 'Allow location to find you instantly, or move the map to your spot.',
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ),
          TextButton(
            onPressed: forever || off ? _svc.openSettings : _findMe,
            child: Text(forever || off ? 'Settings' : 'Allow'),
          ),
        ],
      ),
    );
  }

  Widget _buildOutsideBanner() => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEEEB),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline_rounded, color: Brand.danger),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'We deliver within Lahore only. Move the pin inside the city.',
            style: TextStyle(
              color: Color(0xFF7A1F1F),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildSheet(AppPalette pal) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final needsArea = !_resolving && _place.area.isEmpty;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: pal.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Constrained(
              maxWidth: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'DELIVER TO THIS SPOT',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                      color: pal.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _resolving
                        ? const _AddressSkeleton(key: ValueKey('loading'))
                        : Row(
                            key: ValueKey('${_place.line1}${_place.area}'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: pal.tint,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Brand.blueDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _place.line1.isNotEmpty
                                          ? _place.line1
                                          : (_place.area.isNotEmpty
                                                ? _place.area
                                                : 'Pinned location'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _place.area.isNotEmpty &&
                                              _place.line1.isNotEmpty
                                          ? '${_place.area}, Lahore'
                                          : 'Lahore',
                                      style: TextStyle(color: pal.muted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                  if (needsArea) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _manualArea,
                      onChanged: (_) => setState(() {}),
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Area / society',
                        hintText: 'e.g. Gulberg III, DHA Phase 5',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Flat, floor or landmark (optional)',
                      prefixIcon: Icon(Icons.edit_location_alt_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final (name, icon) in _labels)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              avatar: Icon(
                                icon,
                                size: 18,
                                color: _label == name
                                    ? Colors.white
                                    : pal.muted,
                              ),
                              label: Text(name),
                              selected: _label == name,
                              showCheckmark: false,
                              onSelected: (_) {
                                Haptics.select();
                                setState(() => _label = name);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _canConfirm ? _confirm : null,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Confirm location'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// The classic centre pin. It lifts while the map is moving and settles with
/// a small shadow when it lands.
class _Pin extends StatelessWidget {
  const _Pin({required this.lifted});
  final bool lifted;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 64,
    height: 112,
    child: Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Ground shadow.
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 4),
          width: lifted ? 10 : 18,
          height: lifted ? 4 : 7,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: lifted ? 0.16 : 0.3),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: lifted ? 24 : 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: Brand.headerGradient,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Brand.blueDeep.withValues(alpha: 0.5),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Brand.flame,
                  size: 28,
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -6),
                child: Transform.rotate(
                  angle: 0.785398,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(color: Brand.blueDeep),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: context.pal.card,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 48,
          child: Icon(icon, color: context.pal.ink),
        ),
      ),
    ),
  );
}

class _MyLocationButton extends StatelessWidget {
  const _MyLocationButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Use my current location',
    child: Material(
      color: Brand.blueDark,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onTap,
        child: SizedBox.square(
          dimension: 54,
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.my_location_rounded, color: Colors.white),
        ),
      ),
    ),
  );
}

class _AddressSkeleton extends StatefulWidget {
  const _AddressSkeleton({super.key});

  @override
  State<_AddressSkeleton> createState() => _AddressSkeletonState();
}

class _AddressSkeletonState extends State<_AddressSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    Widget bar(double w, double h) => AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Color.lerp(pal.line, pal.tint, _c.value),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
    return Row(
      children: [
        bar(40, 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(double.infinity, 16),
              const SizedBox(height: 8),
              bar(150, 12),
            ],
          ),
        ),
      ],
    );
  }
}

/// Stand-in for the map when tiles are unavailable (tests, no network).
class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _GridPainter(dark: dark),
    child: const SizedBox.expand(),
  );
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark ? const Color(0xFF0F1D2A) : const Color(0xFFE6ECF2),
    );
    final p = Paint()
      ..color = (dark ? Colors.white : Colors.black).withValues(alpha: 0.06)
      ..strokeWidth = 2;
    for (double x = 0; x < size.width; x += 56) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 56) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter o) => o.dark != dark;
}
