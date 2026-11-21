import 'package:alpha_core/alpha_core.dart';
import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/launch.dart';
import '../utils/order_x.dart';
import '../widgets/common.dart';
import 'order_detail_screen.dart';

class RidersScreen extends StatelessWidget {
  const RidersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final riders = [...s.riders]
      ..sort((a, b) {
        int rank(RiderProfile r) => r.isLive() ? 0 : (r.active ? 1 : 2);
        return rank(a).compareTo(rank(b));
      });
    final live = s.liveRiders.length;
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            // How many are working right now.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: panel(context),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (live > 0 ? Brand.success : Brand.danger)
                          .withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$live',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: live > 0 ? Brand.success : Brand.danger,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          live == 0
                              ? 'No rider on shift'
                              : '$live of ${riders.where((r) => r.active).length} riders on shift',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          live == 0
                              ? 'Customers can still order unless you paused ordering.'
                              : 'Only riders whose app is running count.',
                          style: TextStyle(
                            color: context.pal.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (s.riders.any((r) => r.online))
                    TextButton(
                      onPressed: () async {
                        final ok = await _confirm(
                          context,
                          'Switch all riders offline?',
                          'Every rider\'s shift ends now. They will see a message in their app.',
                          'Switch off',
                        );
                        if (ok != true) return;
                        final err = await s.switchAllRidersOffline();
                        if (context.mounted) {
                          showMessage(
                            context,
                            err ?? 'All riders are offline',
                            error: err != null,
                          );
                        }
                      },
                      child: const Text('All off'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (riders.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.two_wheeler,
                  title: 'No riders yet',
                  message: 'Add a rider. They sign in to the Rider app with the email and password you set.',
                ),
              ),
            for (final r in riders)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RiderCard(rider: r),
              ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _confirm(
  BuildContext context,
  String title,
  String body,
  String action,
) => showDialog<bool>(
  context: context,
  builder: (c) => AlertDialog(
    title: Text(title),
    content: Text(body),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c, false),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: () => Navigator.pop(c, true), child: Text(action)),
    ],
  ),
);

class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.rider});
  final RiderProfile rider;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final r = rider;
    final pal = context.pal;
    final live = r.isLive();
    final jobs = s.jobsOf(r.uid);
    final (String status, Color color, IconData icon) = !r.active
        ? ('Blocked', Brand.danger, Icons.block_rounded)
        : live
        ? (
            'On shift · seen ${timeAgo(r.lastSeen)}',
            Brand.success,
            Icons.circle,
          )
        : r.online
        ? (
            'No signal · last seen ${timeAgo(r.lastSeen)}',
            const Color(0xFF8A6D00),
            Icons.signal_wifi_off_rounded,
          )
        : ('Offline', pal.muted, Icons.circle_outlined);
    Future<void> run(Future<String?> job, String ok) async {
      final err = await job;
      if (context.mounted) showMessage(context, err ?? ok, error: err != null);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
      decoration: panel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: live ? Brand.success : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: (live ? Brand.success : Colors.grey)
                      .withValues(alpha: 0.15),
                  child: Icon(
                    Icons.two_wheeler,
                    color: live ? Brand.success : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${prettyPhone(r.phone)} · ${r.vehicle}',
                      style: TextStyle(color: pal.muted, fontSize: 13),
                    ),
                    if (s.ratingOf(r.uid) case final st?)
                      InkWell(
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          isScrollControlled: true,
                          builder: (_) => _Reviews(
                            name: r.name,
                            orders: s.ratingsOf(r.uid),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFF5A623),
                                size: 17,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${st.$1.toStringAsFixed(1)} · ${st.$2} review${st.$2 == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Rider options',
                onSelected: (v) async {
                  switch (v) {
                    case 'call':
                      Launch.call(r.phone);
                    case 'edit':
                      await showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => _EditRider(rider: r),
                      );
                    case 'off':
                      await run(
                        s.switchRiderOffline(r),
                        '${r.name} is offline',
                      );
                    case 'block':
                      final ok = await _confirm(
                        context,
                        r.active ? 'Block ${r.name}?' : 'Unblock ${r.name}?',
                        r.active
                            ? 'They are switched offline and cannot use the Rider app until you unblock them.'
                            : 'They can sign in to the Rider app again.',
                        r.active ? 'Block' : 'Unblock',
                      );
                      if (ok == true) {
                        await run(
                          s.setRiderActive(r, !r.active),
                          r.active
                              ? '${r.name} is blocked'
                              : '${r.name} is unblocked',
                        );
                      }
                    case 'remove':
                      final ok = await _confirm(
                        context,
                        'Remove ${r.name}?',
                        'Their rider record is deleted. They can no longer open the Rider app. Past deliveries stay in your orders.',
                        'Remove',
                      );
                      if (ok == true)
                        await run(s.removeRider(r), '${r.name} removed');
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'call', child: Text('Call')),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit details'),
                  ),
                  if (r.online)
                    const PopupMenuItem(
                      value: 'off',
                      child: Text('Switch offline'),
                    ),
                  PopupMenuItem(
                    value: 'block',
                    child: Text(r.active ? 'Block rider' : 'Unblock rider'),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove rider'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Pill(icon, status, color: color),
                if (jobs.isNotEmpty)
                  Pill(
                    Icons.inventory_2_rounded,
                    '${jobs.length} job${jobs.length == 1 ? '' : 's'}',
                    color: Brand.blueDark,
                  ),
              ],
            ),
          ),
          // The shop can put a rider on or off shift, or unblock them, right here.
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: !r.active
                ? SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => run(
                        s.setRiderActive(r, true),
                        '${r.name} is unblocked',
                      ),
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: const Text('Unblock this rider'),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.online ? 'On shift' : 'Off shift',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Switch(
                        value: r.online,
                        onChanged: (v) => run(
                          s.setRiderOnline(r, v),
                          v ? '${r.name} is on shift' : '${r.name} is offline',
                        ),
                      ),
                    ],
                  ),
          ),
          for (final o in jobs)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OrderDetailScreen(orderId: o.id),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: pal.tint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${o.displayNumber} · ${o.areaLine}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      StatusChip(o.status),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditRider extends StatefulWidget {
  const _EditRider({required this.rider});
  final RiderProfile rider;

  @override
  State<_EditRider> createState() => _EditRiderState();
}

class _EditRiderState extends State<_EditRider> {
  late final _name = TextEditingController(text: widget.rider.name);
  late final _phone = TextEditingController(text: widget.rider.phone);
  late final _vehicle = TextEditingController(text: widget.rider.vehicle);
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _vehicle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await context.read<AdminSession>().editRider(
      widget.rider,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      vehicle: _vehicle.text.trim().isEmpty
          ? 'Motorbike'
          : _vehicle.text.trim(),
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
      showMessage(context, 'Saved');
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit ${widget.rider.name}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'Enter the name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile number'),
              validator: (v) =>
                  (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10
                  ? 'Enter a valid number'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vehicle,
              decoration: const InputDecoration(labelText: 'Vehicle'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: Brand.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    ),
  );
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
      vehicle: _vehicle.text.trim().isEmpty
          ? 'Motorbike'
          : _vehicle.text.trim(),
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
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add a rider',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'Enter the name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                hintText: '03xx xxxxxxx',
              ),
              validator: (v) =>
                  (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10
                  ? 'Enter a valid number'
                  : null,
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
              validator: (v) =>
                  (v ?? '').contains('@') ? null : 'Enter an email',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass,
              decoration: const InputDecoration(
                labelText: 'Password (min 6 characters)',
              ),
              validator: (v) =>
                  (v ?? '').length < 6 ? 'At least 6 characters' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: Brand.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create rider'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// What customers said about a rider.
class _Reviews extends StatelessWidget {
  const _Reviews({required this.name, required this.orders});
  final String name;
  final List<LpgOrder> orders;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Text(
            'Reviews for $name',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          for (final o in orders)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      i <= o.rating!
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 16,
                      color: const Color(0xFFF5A623),
                    ),
                ],
              ),
              title: Text(
                o.feedback.isEmpty ? '(no comment)' : o.feedback,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('${o.customerName} · ${o.displayNumber}'),
            ),
        ],
      ),
    ),
  );
}
