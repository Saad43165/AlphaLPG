import 'package:alpha_core/alpha_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/brand.dart';
import 'common.dart';

/// Holds the state of an address being entered; shared by the setup flow and
/// the add/edit address screen.
class AddressDraft extends ChangeNotifier {
  AddressDraft([Address? initial])
    : id = initial?.id ?? '',
      label = initial?.label ?? 'Home',
      line1 = TextEditingController(text: initial?.line1),
      area = TextEditingController(text: initial?.area),
      landmark = TextEditingController(text: initial?.landmark),
      lat = initial?.lat,
      lng = initial?.lng;

  final String id;
  String label;
  final TextEditingController line1;
  final TextEditingController area;
  final TextEditingController landmark;
  double? lat;
  double? lng;

  Address toAddress() => Address(
    id: id,
    label: label,
    line1: line1.text.trim(),
    area: area.text.trim(),
    landmark: landmark.text.trim(),
    lat: lat,
    lng: lng,
  );

  void changed() => notifyListeners();

  @override
  void dispose() {
    line1.dispose();
    area.dispose();
    landmark.dispose();
    super.dispose();
  }
}

/// Label chips, street, area (with Lahore shortcuts), landmark and GPS pin.
/// Place inside a [Form] to get validation.
class AddressFields extends StatefulWidget {
  const AddressFields({super.key, required this.draft});
  final AddressDraft draft;

  @override
  State<AddressFields> createState() => _AddressFieldsState();
}

class _AddressFieldsState extends State<AddressFields> {
  bool _locating = false;
  static const _labels = ['Home', 'Work', 'Shop', 'Restaurant', 'Other'];

  AddressDraft get d => widget.draft;

  Future<void> _locate() async {
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
      d
        ..lat = pos.latitude
        ..lng = pos.longitude
        ..changed();
      if (mounted) showMessage(context, 'Location pinned for the rider');
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = context.watch<AppState>().settings.serviceAreas;
    final typed = d.area.text.trim().toLowerCase();
    final suggestions = areas
        .where((a) => typed.isEmpty || a.toLowerCase().contains(typed))
        .where((a) => a.toLowerCase() != typed)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final l in _labels)
              ChoiceChip(
                label: Text(l),
                selected: d.label == l,
                showCheckmark: false,
                onSelected: (_) => setState(() => d.label = l),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: d.line1,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'House / shop no., street, block',
            hintText: 'e.g. 12-B, Street 4, Block K',
            prefixIcon: Icon(Icons.home_work_outlined),
          ),
          validator: (v) =>
              (v ?? '').trim().length < 3 ? 'Please enter the address' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: d.area,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Area / society',
            hintText: 'e.g. Gulberg III, DHA Phase 5',
            prefixIcon: Icon(Icons.map_outlined),
          ),
          onChanged: (_) => setState(() {}),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Please enter the area' : null,
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) => ActionChip(
                label: Text(suggestions[i]),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => d.area.text = suggestions[i]),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        TextFormField(
          controller: d.landmark,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nearby landmark (optional)',
            hintText: 'e.g. opposite Dolmen Mall',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: 14),
        ListenableBuilder(
          listenable: d,
          builder: (context, _) => Material(
            color: d.lat != null
                ? Brand.success.withValues(alpha: 0.08)
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: d.lat != null ? Brand.success : Brand.line,
              ),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: Icon(
                d.lat != null
                    ? Icons.location_on_rounded
                    : Icons.my_location_rounded,
                color: d.lat != null ? Brand.success : Brand.blueDark,
              ),
              title: Text(
                d.lat != null ? 'Location pinned' : 'Pin my current location',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                d.lat != null
                    ? '${d.lat!.toStringAsFixed(5)}, ${d.lng!.toStringAsFixed(5)}'
                    : 'Optional · helps the rider find you faster',
              ),
              trailing: _locating
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _locating ? null : _locate,
            ),
          ),
        ),
      ],
    );
  }
}
