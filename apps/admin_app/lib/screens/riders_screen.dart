import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/launch.dart';
import '../widgets/common.dart';

class RidersScreen extends StatelessWidget {
  const RidersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final riders = [...s.riders]
      ..sort((a, b) => (b.online ? 1 : 0).compareTo(a.online ? 1 : 0));
    return Scaffold(
      appBar: AppBar(title: const Text('Riders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => const _AddRider(),
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add rider'),
      ),
      body: Constrained(
        child: riders.isEmpty
            ? const EmptyState(
                icon: Icons.two_wheeler,
                title: 'No riders yet',
                message: 'Add a rider. They sign in to the Rider app with the email and password you set.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: riders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final r = riders[i];
                  final jobs = s.orders
                      .where((o) =>
                          o.riderId == r.uid &&
                          (o.status == OrderStatus.assigned || o.status == OrderStatus.outForDelivery))
                      .length;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: panel(context),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: (r.online && r.active ? Brand.success : Colors.grey).withValues(alpha: 0.15),
                          child: Icon(Icons.two_wheeler, color: r.online && r.active ? Brand.success : Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text(
                                !r.active
                                    ? 'Blocked'
                                    : r.online
                                    ? 'Online${jobs > 0 ? ' · $jobs job${jobs == 1 ? '' : 's'}' : ''}'
                                    : 'Offline',
                                style: TextStyle(
                                  color: !r.active ? Brand.danger : r.online ? Brand.success : context.pal.muted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text('${prettyPhone(r.phone)} · ${r.vehicle}',
                                  style: TextStyle(color: context.pal.muted, fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Call',
                          onPressed: () => Launch.call(r.phone),
                          icon: const Icon(Icons.call_rounded),
                        ),
                        Switch(
                          value: r.active,
                          onChanged: (v) async {
                            final err = await s.setRiderActive(r, v);
                            if (err != null && context.mounted) showMessage(context, err, error: true);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _AddRider extends StatefulWidget {
  const _AddRider();

  @override
  State<_AddRider> createState() => _AddRiderState();
}

class _AddRiderState extends State<_AddRider> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _vehicle = TextEditingController(text: 'Motorbike');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _pass, _vehicle]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await context.read<AdminSession>().addRider(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      password: _pass.text,
      vehicle: _vehicle.text.trim().isEmpty ? 'Motorbike' : _vehicle.text.trim(),
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
      showMessage(context, 'Rider added. They can sign in now.');
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
    child: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add a rider', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Enter the name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile number', hintText: '03xx xxxxxxx'),
              validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10 ? 'Enter a valid number' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vehicle,
              decoration: const InputDecoration(labelText: 'Vehicle'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Login email'),
              validator: (v) => (v ?? '').contains('@') ? null : 'Enter an email',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass,
              decoration: const InputDecoration(labelText: 'Password (min 6 characters)'),
              validator: (v) => (v ?? '').length < 6 ? 'At least 6 characters' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Brand.danger, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Create rider'),
            ),
          ],
        ),
      ),
    ),
  );
}
