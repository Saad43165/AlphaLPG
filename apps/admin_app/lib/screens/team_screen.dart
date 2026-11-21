import 'package:alpha_ui/alpha_ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/common.dart';

/// Owner: people who can use the admin app, and what they did.
class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final s = context.read<AdminSession>();
    final name = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Add staff'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Staff can handle orders, payments, riders and customers. '
                'They cannot change settings, delete products, cancel paid '
                'orders or add other admins.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email (login)'),
              ),
              TextField(
                controller: pass,
                decoration: const InputDecoration(
                  labelText: 'Password (6+ characters)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (name.text.trim().isEmpty ||
        !email.text.contains('@') ||
        pass.text.length < 6) {
      showMessage(
        context,
        'Enter a name, a valid email and a 6+ character password',
        error: true,
      );
      return;
    }
    final err = await s.addStaff(
      name: name.text.trim(),
      email: email.text.trim(),
      password: pass.text,
    );
    if (context.mounted) {
      showMessage(context, err ?? 'Staff added', error: err != null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final fmt = DateFormat('d MMM, h:mm a');
    return Scaffold(
      appBar: AppBar(title: const Text('Team and activity')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add staff'),
      ),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            const Text(
              'Admins',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            for (final a in s.admins)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: a.isOwner ? Brand.navy : Brand.blueDark,
                  child: Icon(
                    a.isOwner
                        ? Icons.admin_panel_settings_rounded
                        : Icons.badge_rounded,
                    color: Colors.white,
                  ),
                ),
                title: Text(a.name.isEmpty ? a.email : a.name),
                subtitle: Text('${a.isOwner ? 'Owner' : 'Staff'} · ${a.email}'),
                trailing: a.isOwner || a.uid == s.uid
                    ? null
                    : IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.person_remove_rounded),
                        onPressed: () async {
                          final err = await s.removeStaff(a);
                          if (context.mounted) {
                            showMessage(
                              context,
                              err ?? 'Removed',
                              error: err != null,
                            );
                          }
                        },
                      ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Activity log',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            if (s.auditLog.isEmpty)
              Text(
                'Nothing recorded yet.',
                style: TextStyle(color: context.pal.muted),
              ),
            for (final e in s.auditLog.take(80))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${e.action}${e.target.isEmpty ? '' : ' · ${e.target}'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${e.byName} · ${e.at == null ? '' : fmt.format(e.at!.toLocal())}'
                  '${e.detail.isEmpty ? '' : '\n${e.detail}'}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// App crashes and errors reported by the three apps.
class ErrorLogScreen extends StatelessWidget {
  const ErrorLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final fmt = DateFormat('d MMM, h:mm a');
    return Scaffold(
      appBar: AppBar(title: const Text('App errors')),
      body: Constrained(
        child: s.errorLog.isEmpty
            ? const EmptyState(
                icon: Icons.check_circle_rounded,
                title: 'No errors reported',
                message: 'Crashes from the customer, rider and admin apps show up here.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: s.errorLog.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final e = s.errorLog[i];
                  return ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      e.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${e.app} ${e.version} · ${e.at == null ? '' : fmt.format(e.at!.toLocal())}',
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText(
                          e.stack.isEmpty ? '(no details)' : e.stack,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
