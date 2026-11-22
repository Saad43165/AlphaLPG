import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Text;

import '../../l10n/text.dart';

import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        leading: const ScreenBack(),
        title: const Text('Saved addresses'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/location'),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add address'),
      ),
      body: state.addresses.isEmpty
          ? const EmptyState(
              icon: Icons.location_off_outlined,
              title: 'No saved addresses',
              message: 'Add your home, shop or restaurant for faster checkout.',
            )
          : Constrained(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: state.addresses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _AddressCard(state.addresses[i]),
              ),
            ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard(this.a);
  final Address a;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      leading: Icon(
        a.hasLocation ? Icons.location_on : Icons.location_on_outlined,
        color: a.hasLocation ? Brand.success : Brand.blueDark,
      ),
      title: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(a.oneLine),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'edit') {
            context.push('/location', extra: a);
          } else {
            final uid = context.read<AppState>().uid!;
            await context.read<Backend>().profiles.deleteAddress(uid, a.id);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    ),
  );
}
