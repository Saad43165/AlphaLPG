import 'dart:convert';
import 'dart:typed_data';

import 'package:alpha_core/alpha_core.dart' show QuoteRequest;
import 'package:alpha_ui/alpha_ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../utils/launch.dart';
import '../widgets/common.dart';
import '../widgets/setup_check.dart';
import '../utils/export.dart';
import 'cash_screen.dart';
import 'guide_screen.dart';
import 'customers_screen.dart';
import 'reports_inbox_screen.dart';
import 'reports_screen.dart';
import 'rewards_screen.dart';
import 'team_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static Future<void> _go(BuildContext context, AdminSession s, Widget page) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChangeNotifierProvider.value(value: s, child: page),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final pal = context.pal;
    final newQuotes = s.quotes.where((q) => q.status == 'new').length;
    final inbox = s.openReportCount + newQuotes;
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const SetupCheck(),
            // Who is signed in.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: panel(context),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Brand.navy,
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Brand.flame,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.isOwner ? 'Owner' : 'Staff',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          s.backend.auth.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: pal.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // What you open every day.
            Row(
              children: [
                Expanded(
                  child: _Quick(
                    icon: Icons.inbox_rounded,
                    label: 'Inbox',
                    badge: inbox,
                    onTap: () => _go(context, s, const InboxScreen()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Quick(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Money',
                    onTap: () => _go(context, s, const MoneyScreen()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Quick(
                    icon: Icons.people_alt_rounded,
                    label: 'Customers',
                    onTap: () => _go(context, s, const CustomersScreen()),
                  ),
                ),
              ],
            ),
            _Group('Shop', [
              _Item(
                icon: Icons.local_offer_rounded,
                title: 'Coupons and rewards',
                subtitle: 'Discount codes, points, invite a friend',
                onTap: () => _go(context, s, const RewardsScreen()),
              ),
              _Item(
                icon: Icons.table_view_rounded,
                title: 'Export orders',
                subtitle: 'A spreadsheet of orders, to read or print',
                onTap: () => exportOrders(context, s),
              ),
            ]),
            _Group('Help', [
              _Item(
                icon: Icons.menu_book_rounded,
                title: 'How the app works',
                subtitle: 'Guide in English and اردو',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GuideScreen(shopPhone: s.settings.phone),
                  ),
                ),
              ),
            ]),
            if (s.isOwner)
              _Group('Owner', [
                _Item(
                  icon: Icons.shield_rounded,
                  title: 'Owner tools',
                  subtitle: 'Team, backup, free up space, app errors',
                  badge: s.errorLog.length,
                  onTap: () => _go(context, s, const OwnerToolsScreen()),
                ),
              ]),
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
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: s.signOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Alpha LPG Admin ${AppInfo.current.label}',
                style: TextStyle(color: pal.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A big square button for the things opened every day.
class _Quick extends StatelessWidget {
  const _Quick({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });
  final IconData icon;
  final String label;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      decoration: panel(context),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(Brand.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Badge(
                  isLabelVisible: badge > 0,
                  label: Text('$badge'),
                  backgroundColor: Brand.cylinderRed,
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Brand.blue.withValues(alpha: 0.13),
                    child: Icon(icon, color: Brand.blueDark, size: 26),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: pal.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled card holding a few rows.
class _Group extends StatelessWidget {
  const _Group(this.title, this.items);
  final String title;
  final List<_Item> items;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: pal.muted,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: panel(context),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 66, color: pal.line),
                  items[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badge = 0,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: Badge(
      isLabelVisible: badge > 0,
      label: Text('$badge'),
      backgroundColor: Brand.cylinderRed,
      child: CircleAvatar(
        backgroundColor: Brand.blue.withValues(alpha: 0.13),
        child: Icon(icon, color: Brand.blueDark),
      ),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

/// Everything about problems and enquiries in one place.
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final quotes = s.quotes.where((q) => q.status == 'new').length;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inbox'),
          bottom: TabBar(
            tabs: [
              Tab(
                text: s.openReportCount > 0
                    ? 'Problems · ${s.openReportCount}'
                    : 'Problems',
              ),
              Tab(text: quotes > 0 ? 'Quotes · $quotes' : 'Quotes'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ReportsInboxScreen(embedded: true),
            QuotesScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}

/// Cash from riders and sales numbers.
class MoneyScreen extends StatelessWidget {
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Money'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Cash handover'),
            Tab(text: 'Sales report'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [CashScreen(embedded: true), ReportsScreen(embedded: true)],
      ),
    ),
  );
}

/// Rarely used, owner-only tools.
class OwnerToolsScreen extends StatelessWidget {
  const OwnerToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    return Scaffold(
      appBar: AppBar(title: const Text('Owner tools')),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _Group('People', [
              _Item(
                icon: Icons.groups_rounded,
                title: 'Team and activity log',
                subtitle: 'Add staff, see who did what',
                onTap: () => MoreScreen._go(context, s, const TeamScreen()),
              ),
            ]),
            _Group('Your data', [
              _Item(
                icon: Icons.cloud_download_rounded,
                title: 'Backup all data',
                subtitle: 'A safety copy of orders, customers, products',
                onTap: () => backupAll(context, s),
              ),
              _Item(
                icon: Icons.cleaning_services_rounded,
                title: 'Free up space',
                subtitle: 'Delete old receipts and delivery photos',
                onTap: () => _freeUpSpace(context, s),
              ),
            ]),
            _Group('Problems', [
              _Item(
                icon: Icons.bug_report_rounded,
                title: 'App errors',
                subtitle: 'Crashes reported by the apps',
                badge: s.errorLog.length,
                onTap: () => MoreScreen._go(context, s, const ErrorLogScreen()),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

Future<void> exportOrders(BuildContext context, AdminSession s) async {
  try {
    await shareBytes(
      Uint8List.fromList(utf8.encode(ordersCsv(s.orders))),
      name:
          'alpha-lpg-orders-${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      mime: 'text/csv',
    );
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'Could not export', error: true);
    }
  }
}

Future<void> backupAll(BuildContext context, AdminSession s) async {
  try {
    final text = backupJson(
      orders: s.orders,
      customers: s.customers,
      riders: s.riders,
      products: s.products,
      settings: s.settings,
      ledger: s.ledger,
      handovers: s.handovers,
    );
    await shareBytes(
      Uint8List.fromList(utf8.encode(text)),
      name:
          'alpha-lpg-backup-${DateFormat('yyyyMMdd').format(DateTime.now())}.json',
      mime: 'application/json',
    );
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'Could not make the backup', error: true);
    }
  }
}

class QuotesScreen extends StatelessWidget {
  const QuotesScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final fmt = DateFormat('d MMM');
    return Scaffold(
      appBar: embedded ? null : AppBar(title: const Text('Business quotes')),
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
                        if (q.hasReply)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Brand.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'You replied in the app:\n${q.reply}',
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => Launch.call(q.phone),
                              icon: const Icon(Icons.call_rounded, size: 18),
                              label: const Text('Call'),
                            ),
                            OutlinedButton.icon(
                              onPressed: whatsappNumber(q.phone) == null
                                  ? null
                                  : () => Launch.whatsapp(
                                      whatsappNumber(q.phone)!,
                                      quoteMessage(q),
                                    ),
                              icon: const WhatsAppIcon(size: 18),
                              label: const Text('WhatsApp'),
                            ),
                            FilledButton.icon(
                              onPressed: () => showQuoteReply(context, q),
                              icon: const Icon(Icons.send_rounded, size: 18),
                              label: Text(
                                q.hasReply ? 'Send again' : 'Send details',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
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

/// The first line of every WhatsApp message to a bulk customer.
String quoteMessage(QuoteRequest q) {
  final b = StringBuffer(
    'Assalam-o-Alaikum ${q.contactName}, this is Alpha LPG about your bulk '
    'request for ${q.businessName} (${q.preferredSize}, about ${q.monthlyKg} kg a month).',
  );
  if (q.hasReply) b.write('\n\n${q.reply}');
  return b.toString();
}

/// Write the rate and details once, then send them in the app, on WhatsApp,
/// or both. The customer sees an in-app reply on their bulk order screen.
Future<void> showQuoteReply(BuildContext context, QuoteRequest q) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AdminSession>(),
        child: _QuoteReplySheet(q),
      ),
    );

class _QuoteReplySheet extends StatefulWidget {
  const _QuoteReplySheet(this.q);
  final QuoteRequest q;

  @override
  State<_QuoteReplySheet> createState() => _QuoteReplySheetState();
}

class _QuoteReplySheetState extends State<_QuoteReplySheet> {
  late final _text = TextEditingController(
    text: widget.q.hasReply
        ? widget.q.reply
        : 'Rate: Rs ___ per cylinder (${widget.q.preferredSize})\n'
              'Delivery: ___\n'
              'Payment: ___\n'
              'Call us on the shop number to confirm.',
  );
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _sendInApp({bool alsoWhatsApp = false}) async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    setState(() => _busy = true);
    final s = context.read<AdminSession>();
    final err = await s.sendQuoteReply(widget.q, t);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showMessage(context, err, error: true);
      return;
    }
    final wa = whatsappNumber(widget.q.phone);
    final nav = Navigator.of(context);
    final messenger = context;
    if (alsoWhatsApp && wa != null) {
      await Launch.whatsapp(
        wa,
        'Assalam-o-Alaikum ${widget.q.contactName}, Alpha LPG here.\n\n$t',
      );
    }
    nav.pop();
    if (messenger.mounted) {
      showMessage(messenger, 'Sent. The customer sees it in the app.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Send details to ${widget.q.businessName}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              'Write the rate and plan once. The customer sees it on their '
              'bulk order screen in the app. You can also send it on WhatsApp.',
              style: TextStyle(color: pal.muted, height: 1.35, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              minLines: 5,
              maxLines: 9,
              maxLength: 900,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Rate, delivery days, payment terms…',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : () => _sendInApp(),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send in the app'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy || whatsappNumber(widget.q.phone) == null
                  ? null
                  : () => _sendInApp(alsoWhatsApp: true),
              icon: const WhatsAppIcon(size: 20),
              label: const Text('Send in the app and WhatsApp'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Old receipt and delivery pictures take most of the free database space.
/// This deletes them for orders older than 90 days; the orders themselves,
/// amounts and customers stay.
Future<void> _freeUpSpace(BuildContext context, AdminSession s) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Free up space?'),
      content: const Text(
        'This deletes the payment receipt pictures and delivery photos of orders older than 90 days. '
        'The orders, amounts and customers stay. It cannot be undone, so export a backup first if you may need the pictures.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(d, true),
          child: const Text('Delete old pictures'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  showMessage(context, 'Working…');
  final (n, err) = await s.archiveOldPhotos(90);
  if (!context.mounted) return;
  showMessage(
    context,
    err ?? (n == 0 ? 'Nothing old to delete.' : 'Deleted $n old pictures.'),
    error: err != null,
  );
}
