import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Text;

import '../l10n/text.dart';

import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/brand.dart';

/// Bottom sheet to choose the "Deliver to" address or add a new one.
Future<void> showAddressPicker(BuildContext context) {
  final state = context.read<AppState>();
  if (!state.signedIn) {
    context.push('/login?from=/');
    return Future.value();
  }
  if (state.addresses.isEmpty) {
    // Nothing saved yet: go straight to the map.
    context.push<Address>('/location');
    return Future.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheet) => Consumer<AppState>(
      builder: (_, state, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Deliver to', style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final a in state.addresses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AddressOption(
                    title: a.label,
                    subtitle: a.oneLine,
                    selected: a.id == state.selectedAddress?.id,
                    onTap: () {
                      state.selectAddress(a.id);
                      Navigator.pop(sheet);
                    },
                  ),
                ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheet);
                  context.push<Address>('/location').then((a) {
                    if (a != null) state.selectAddress(a.id);
                  });
                },
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add new address'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AddressOption extends StatelessWidget {
  const _AddressOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? context.pal.tint : context.pal.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: selected ? Brand.blueDark : context.pal.line,
        width: selected ? 1.5 : 1,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? context.pal.blue : context.pal.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(subtitle, style: TextStyle(color: context.pal.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
