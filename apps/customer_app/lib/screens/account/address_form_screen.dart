import 'package:alpha_core/alpha_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';

/// Add or edit a delivery address. Pops with the saved [Address].
class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({super.key, this.initial});
  final Address? initial;

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _line1 = TextEditingController(text: widget.initial?.line1);
  late final _area = TextEditingController(text: widget.initial?.area);
  late final _landmark = TextEditingController(text: widget.initial?.landmark);
  late String _label = widget.initial?.label ?? 'Home';
  late double? _lat = widget.initial?.lat;
  late double? _lng = widget.initial?.lng;
  bool _locating = false;
  bool _saving = false;

  static const _labels = ['Home', 'Work', 'Shop', 'Restaurant', 'Other'];

  @override
  void dispose() {
    _line1.dispose();
    _area.dispose();
    _landmark.dispose();
    super.dispose();
  }

  Future<void> _useLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Please turn on location services.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'Location permission was denied.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      if (mounted) showMessage(context, 'Location pinned for the rider');
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final backend = context.read<Backend>();
    final uid = context.read<AppState>().uid!;
    setState(() => _saving = true);
    try {
      final saved = await backend.profiles.saveAddress(
        uid,
        Address(
          id: widget.initial?.id ?? '',
          label: _label,
          line1: _line1.text.trim(),
          area: _area.text.trim(),
          landmark: _landmark.text.trim(),
          lat: _lat,
          lng: _lng,
        ),
      );
      if (mounted) context.pop(saved);
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Could not save address: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = context.watch<AppState>().settings.serviceAreas;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'New address' : 'Edit address'),
      ),
      body: Constrained(
        maxWidth: 560,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final l in _labels)
                    ChoiceChip(
                      label: Text(l),
                      selected: _label == l,
                      onSelected: (_) => setState(() => _label = l),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _line1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'House / shop no., street, block',
                  hintText: 'e.g. 12-B, Street 4, Block K',
                ),
                validator: (v) => (v ?? '').trim().length < 3
                    ? 'Please enter the address'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _area,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Area / society',
                  hintText: 'e.g. Gulberg III, DHA Phase 5',
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Please enter the area' : null,
              ),
              if (areas.isNotEmpty) ...[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final a in areas.where(
                        (a) =>
                            _area.text.isEmpty ||
                            a.toLowerCase().contains(_area.text.toLowerCase()),
                      ))
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(a),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _area.text = a),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _landmark,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nearby landmark (optional)',
                  hintText: 'e.g. opposite Dolmen Mall',
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: Icon(
                    _lat != null ? Icons.location_on : Icons.my_location,
                    color: _lat != null ? Brand.success : Brand.blueDark,
                  ),
                  title: Text(
                    _lat != null
                        ? 'Location pinned'
                        : 'Pin my current location',
                  ),
                  subtitle: Text(
                    _lat != null
                        ? '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                        : 'Helps the rider find you faster',
                  ),
                  trailing: _locating
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _locating ? null : _useLocation,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Save address'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
