import 'package:alpha_ui/alpha_ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/launch.dart';
import '../widgets/common.dart';
import 'reports_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final newQuotes = s.quotes.where((q) => q.status == 'new').length;
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: panel(context),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Brand.navy,
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Brand.flame,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Owner',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          s.backend.auth.email ?? '',
                          style: TextStyle(
                            color: context.pal.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.insights_rounded),
              title: const Text('Sales & cash report'),
              subtitle: const Text('Today, 7 days, 30 days'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ReportsScreen()),
              ),
            ),
            ListTile(
              leading: Badge(
                isLabelVisible: newQuotes > 0,
                label: Text('$newQuotes'),
                child: const Icon(Icons.business_center_rounded),
              ),
              title: const Text('Business quotes'),
              subtitle: const Text('Bulk supply enquiries'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const QuotesScreen()),
              ),
            ),
            const Heading('Appearance'),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: s.themeMode,
              builder: (_, mode, _) => SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Auto'),
                    icon: Icon(Icons.brightness_auto_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_rounded),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (v) => s.setThemeMode(v.first),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: s.signOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Alpha LPG Admin 1.0.0',
                style: TextStyle(color: context.pal.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuotesScreen extends StatelessWidget {
  const QuotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final fmt = DateFormat('d MMM');
    return Scaffold(
      appBar: AppBar(title: const Text('Business quotes')),
      body: Constrained(
        child: s.quotes.isEmpty
            ? const EmptyState(
                icon: Icons.business_center_rounded,
                title: 'No enquiries yet',
                message: 'Restaurants, hotels and factories who ask for a bulk quote appear here.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: s.quotes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final q = s.quotes[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: panel(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                q.businessName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (q.createdAt != null)
                              Text(
                                fmt.format(q.createdAt!),
                                style: TextStyle(
                                  color: context.pal.muted,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '${q.businessType} · about ${q.monthlyKg} kg a month · ${q.preferredSize}',
                          style: TextStyle(
                            color: context.pal.muted,
                            fontSize: 13,
                          ),
                        ),
                        if (q.area.isNotEmpty)
                          Text(
                            q.area,
                            style: TextStyle(
                              color: context.pal.muted,
                              fontSize: 13,
                            ),
                          ),
                        if (q.notes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(q.notes),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          '${q.contactName} · ${prettyPhone(q.phone)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              onPressed: () => Launch.call(q.phone),
                              icon: const Icon(Icons.call_rounded),
                            ),
                            const SizedBox(width: 8),
                            const Spacer(),
                            DropdownButton<String>(
                              value:
                                  const [
                                    'new',
                                    'contacted',
                                    'won',
                                    'lost',
                                  ].contains(q.status)
                                  ? q.status
                                  : 'new',
                              underline: const SizedBox.shrink(),
                              items: const [
                                DropdownMenuItem(
                                  value: 'new',
                                  child: Text('New'),
                                ),
                                DropdownMenuItem(
                                  value: 'contacted',
                                  child: Text('Contacted'),
                                ),
                                DropdownMenuItem(
                                  value: 'won',
                                  child: Text('Won'),
                                ),
                                DropdownMenuItem(
                                  value: 'lost',
                                  child: Text('Lost'),
                                ),
                              ],
                              onChanged: (v) async {
                                if (v == null) return;
                                final err = await s.setQuoteStatus(q, v);
                                if (err != null && context.mounted)
                                  showMessage(context, err, error: true);
                              },
                            ),
                          ],
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
