import 'package:alpha_ui/alpha_ui.dart' show WhatsAppIcon;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Text;

import '../../l10n/text.dart';

import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/brand.dart';
import '../../utils/format.dart';
import '../../utils/launch.dart';
import '../../widgets/common.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().settings;
    final areas = s.serviceAreas.isEmpty
        ? 'all of Lahore'
        : s.serviceAreas.join(', ');
    final faqs = <(String, String)>[
      (
        'How fast is delivery?',
        'Orders placed during opening hours (${s.openingHours}) are usually delivered the same day, often within 1–3 hours. You can also schedule a day and time slot at checkout.',
      ),
      (
        'What does the refill price mean?',
        'The listed price is for the gas. Our rider swaps your empty cylinder for a full one of the same size, so please keep your empty ready.',
      ),
      (
        "I don't have an empty cylinder.",
        'No problem. Message us on WhatsApp and we will arrange a new cylinder for you.',
      ),
      (
        'Which areas do you deliver to?',
        'We currently deliver to $areas. Not on the list? Message us and we will try our best.',
      ),
      (
        'How much is delivery?',
        s.deliveryFee == 0
            ? 'Delivery is free.'
            : 'Delivery is ${formatRupees(s.deliveryFee)}${s.freeDeliveryFrom > 0 ? ', and free on orders over ${formatRupees(s.freeDeliveryFrom)}' : ''}.',
      ),
      (
        'How can I pay?',
        'Cash on delivery or bank transfer. JazzCash and Easypaisa are coming soon.',
      ),
      (
        'Can I cancel my order?',
        'Yes, you can cancel from the order screen until Alpha LPG confirms it. After that, please call or WhatsApp us.',
      ),
      (
        'Do you supply restaurants and factories?',
        'Yes. Request a business quote in the app for scheduled 45.4kg deliveries, bulk LPG and monthly billing.',
      ),
      (
        'How do I check my cylinder is safe?',
        'Check that the seal is intact and the valve is undamaged when you receive it. Use soapy water (never a flame) to check connections — bubbles mean a leak.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const ScreenBack(),
        title: const Text('Help & FAQs'),
      ),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(
                color: context.pal.card,
                borderRadius: BorderRadius.circular(Brand.radius),
                boxShadow: context.pal.shadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    for (final (i, (q, a)) in faqs.indexed) ...[
                      if (i > 0) const Divider(indent: 16, endIndent: 16),
                      Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          title: Text(
                            q,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),
                          expandedAlignment: Alignment.topLeft,
                          children: [
                            Text(
                              a,
                              style: TextStyle(
                                color: context.pal.muted,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SectionTitle('Still need help?'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    onPressed: () => Launch.whatsapp(
                      s.whatsapp,
                      'Assalam-o-Alaikum, I need help with my LPG order.',
                    ),
                    icon: const WhatsAppIcon(size: 22),
                    label: const Text('WhatsApp'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    onPressed: () => Launch.call(s.phone),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Call us'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.push('/safety'),
              icon: Icon(
                Icons.health_and_safety_rounded,
                color: context.pal.red,
              ),
              label: const Text('Read the LPG safety guide'),
            ),
          ],
        ),
      ),
    );
  }
}
