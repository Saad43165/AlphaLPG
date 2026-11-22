import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/common.dart';

/// A one-page guide for the owner and new staff: the shop day in five steps.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  static const _steps = <(IconData, String, String)>[
    (
      Icons.storefront_rounded,
      '1. Open the shop',
      'On the Orders tab, the bar at the top says if the shop is taking orders. '
          'Turn it on when you open. Riders switch themselves on shift in the Rider app; you can see who is free in the row of riders under the numbers.',
    ),
    (
      Icons.check_circle_rounded,
      '2. Confirm each new order',
      'New orders show in the New tab with a sound. Open one, check the items and address, then tap Confirm. '
          'A customer who orders for the first time is marked: call them once. '
          'Orders the customer scheduled for another day wait in the Scheduled tab until their day.',
    ),
    (
      Icons.two_wheeler_rounded,
      '3. Give it to a rider',
      'Tap Assign rider and choose someone who is Online. The list shows who is closest and how many cylinders they already carry. '
          'Several waiting orders? In the In progress tab tap Select several, tick them and give them to one rider together.',
    ),
    (
      Icons.payments_rounded,
      '4. Check the payments',
      'Cash on delivery: the rider collects it. '
          'JazzCash, Easypaisa or bank: open the order, tap Send payment details, wait for the customer\'s receipt, check the amount and transaction ID in your own app, then tap Mark paid. '
          'The Online payments tab lists everything waiting.',
    ),
    (
      Icons.nightlight_round,
      '5. Close the day',
      'In More: open Cash handover and receive the cash each rider hands in. Look at the Sales and cash report. '
          'Answer any open problems in Reports and problems. Then switch the shop off (or let the opening hours do it).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      appBar: AppBar(title: const Text('Your day in 5 steps')),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            for (final (icon, title, text) in _steps)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: panel(context),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: Brand.blue.withValues(alpha: 0.12),
                      child: Icon(icon, color: Brand.blueDark),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            text,
                            style: TextStyle(color: pal.muted, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const Heading('When something looks wrong'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: panel(context),
              child: Text(
                'The orange bars at the top of the Orders tab tell you what needs you: '
                'an order waiting for a rider, a receipt to check, a customer who has not paid, '
                'a rider whose phone has gone quiet. Tap a bar to go straight to it.',
                style: TextStyle(color: pal.muted, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
