import 'package:material_ui/material_ui.dart' hide Text;

import '../../l10n/text.dart';

import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';

/// A readable policy page: headings with short paragraphs.
class _LegalPage extends StatelessWidget {
  const _LegalPage({
    required this.title,
    required this.intro,
    required this.sections,
  });
  final String title;
  final String intro;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.watch<AppState>().settings;
    return Scaffold(
      appBar: AppBar(title: Text(title), leading: const ScreenBack()),
      body: Constrained(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            Text(
              'Last updated: November 2026',
              style: TextStyle(color: pal.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            Text(intro, style: const TextStyle(height: 1.5, fontSize: 15)),
            for (final (h, b) in sections) ...[
              const SizedBox(height: 22),
              Text(
                h,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(b, style: TextStyle(height: 1.55, color: pal.ink)),
            ],
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pal.card,
                borderRadius: BorderRadius.circular(Brand.radius),
                border: Border.all(color: pal.line),
              ),
              child: Text(
                'Questions? Contact Alpha LPG\n'
                '${s.shopAddress}\n'
                'Phone: ${s.phone}  ·  Email: ${s.email}',
                style: const TextStyle(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => const _LegalPage(
    title: 'Privacy policy',
    intro:
        'This explains what the Alpha LPG app collects, why, and the choices you have. '
        'We only collect what we need to take and deliver your gas order.',
    sections: [
      (
        'What we collect',
        '• Your mobile number, to sign you in and so the rider and shop can call you.\n'
            '• Your name, and optionally your email and business name and type.\n'
            '• Delivery addresses, including the map spot you choose.\n'
            '• Your orders: items, prices, payment method, the transaction ID you enter, notes, and any rating or feedback.\n'
            '• Payment receipt pictures you choose to send us for online payments.\n'
            '• Messages you send in the order chat with the shop and your rider.\n'
            '• A photo the rider takes at delivery, to prove the cylinders arrived.\n'
            '• Business quote requests you send us.\n'
            '• Your phone\'s location only at the moment you tap "Use my current location". It is used to place the map pin. We do not track you in the background.\n'
            '• Basic crash reports (error text and app version) if the app crashes, so we can fix it.',
      ),
      (
        'Why we use it',
        'To deliver your cylinders, contact you about an order, let your rider find you, '
            'send invoices, give support, and keep our business and safety records.',
      ),
      (
        'Who can see it',
        'Alpha LPG staff, and the rider assigned to your order. The rider sees your name, phone number and delivery address only while the order is open. '
            'During delivery you can see the rider\'s name, phone and live location. Your own location is never shared with other customers. '
            'The shop owner and staff can see your orders, receipts and messages. Orders may also be blocked by the shop if there is misuse.',
      ),
      (
        'Services we use',
        'Google Firebase stores your account and orders. '
            'Geoapify supplies map images and address search; it receives the area you are looking at or the text you search for, not your name or phone number. '
            'WhatsApp, phone calls and Google Maps open only when you tap them.',
      ),
      (
        'Payments',
        'The app does not collect card or wallet PINs. JazzCash, Easypaisa and bank transfers happen in those apps. We store the transaction ID, the amount and the receipt picture you send, so we can check and match your payment.',
      ),
      (
        'Keeping and deleting your data',
        'You can delete your account at any time in Account → Delete my account. '
            'This removes your sign-in, profile and saved locations. '
            'Past orders are kept without a way to sign in, for as long as we need them for business, tax and safety records.',
      ),
      (
        'Your choices',
        'You can edit your details in Account → Edit profile, remove saved locations, turn off notifications in your phone settings, '
            'or ask us to correct or remove information by contacting us below.',
      ),
      (
        'Children',
        'The app is for people aged 18 and over. Please do not order gas without an adult.',
      ),
      (
        'Changes',
        'If we change this policy we will update the date above. Big changes will be shown in the app.',
      ),
    ],
  );
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _LegalPage(
    title: 'Terms of service',
    intro: 'By placing an order in the Alpha LPG app you agree to these terms. They are written to be short and clear.',
    sections: [
      (
        'Ordering',
        'You are placing an order, not buying from a shelf. We confirm it by call or in the app. '
            'We may decline or cancel an order, for example if the address is outside our delivery area or stock is not available, and we will tell you.',
      ),
      (
        'Prices',
        'Prices are in Pakistani rupees and shown before you order. The price at the time of your order is the price you pay. '
            'Prices and delivery charges can change between orders.',
      ),
      (
        'Refill and new cylinders',
        'The refill price applies when you hand over an empty cylinder of the same size at delivery. '
            'If you do not have an empty cylinder, choose the "new cylinder" option where it is offered.',
      ),
      (
        'Delivery',
        'Delivery times are estimates, not promises. Please be reachable by phone and have the empty cylinder ready. '
            'If nobody can be reached, the rider may leave and we may charge for a repeat delivery.',
      ),
      (
        'Payment',
        'Pay in cash on delivery, or by JazzCash, Easypaisa or bank transfer to the account shown in the app. '
            'A transfer order is marked paid once we see the payment. Please enter the correct transaction ID.',
      ),
      (
        'Cancelling',
        'You can cancel in the app before we confirm the order. After that, please call us and we will do our best to help.',
      ),
      (
        'Safety',
        'LPG is flammable. Read the safety guide in the app. Check the cylinder for damage and smell for gas when it arrives, '
            'and tell the rider straight away if something looks wrong. In an emergency, leave the area and call the emergency services.',
      ),
      (
        'Our responsibility',
        'We take care to deliver safe, full cylinders. We are not responsible for loss caused by misuse, '
            'damaged connections or appliances, or events outside our control. Nothing here limits rights you have under the law.',
      ),
      (
        'Using the app',
        'Please give true details and do not misuse the app, place false orders or harass our riders. We may stop service to accounts that do.',
      ),
      (
        'Changes',
        'We may update these terms. The date above shows the latest version. Continuing to order means you accept it.',
      ),
    ],
  );
}
