import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../widgets/address_fields.dart';
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
  late final _draft = AddressDraft(widget.initial);
  bool _saving = false;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final backend = context.read<Backend>();
    final state = context.read<AppState>();
    setState(() => _saving = true);
    try {
      final saved = await backend.profiles.saveAddress(
        state.uid!,
        _draft.toAddress(),
      );
      state.selectAddress(saved.id);
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.initial == null ? 'New address' : 'Edit address'),
    ),
    body: Constrained(
      maxWidth: 560,
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [AddressFields(draft: _draft)],
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Constrained(
          maxWidth: 560,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save address'),
          ),
        ),
      ),
    ),
  );
}
