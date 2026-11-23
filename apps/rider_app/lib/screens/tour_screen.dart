import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';

/// The welcome tour a rider sees the first time the app opens.
class RiderTour extends StatelessWidget {
  const RiderTour({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => TourPage(
    appName: const Bi('Alpha LPG Rider', 'الفا ایل پی جی رائیڈر'),
    onDone: onDone,
    slides: [
      TourSlide(
        icon: Icons.waving_hand_rounded,
        title: const Bi('Welcome, rider', 'خوش آمدید، رائیڈر'),
        body: const Bi(
          'Go online and the orders come to you. Try the button below.',
          'آن لائن ہوں تو آرڈر آپ تک آتے ہیں۔ نیچے والا بٹن دبا کر دیکھیں۔',
        ),
        demo: (c, u) => TourToggleDemo(
          urdu: u,
          offTitle: const Bi('You are offline', 'آپ آف لائن ہیں'),
          onTitle: const Bi('You are online', 'آپ آن لائن ہیں'),
          offHint: const Bi(
            'Tap the button to start your shift',
            'ڈیوٹی شروع کرنے کے لیے بٹن دبائیں',
          ),
          onHint: const Bi(
            'New orders now ring on your phone',
            'اب نئے آرڈر آپ کے فون پر بجیں گے',
          ),
        ),
      ),
      TourSlide(
        icon: Icons.notifications_active_rounded,
        title: const Bi('Take an order', 'آرڈر قبول کریں'),
        body: const Bi(
          'An alert rings. The first rider to accept gets the order.',
          'الرٹ بجتا ہے۔ جو رائیڈر پہلے قبول کرے اسے آرڈر ملتا ہے۔',
        ),
        demo: (c, u) => TourStepsDemo(
          urdu: u,
          steps: const [
            TourStep(
              Icons.notifications_active_rounded,
              Bi(
                'New order · DHA · 2 cylinders',
                'نیا آرڈر · ڈی ایچ اے · 2 سلنڈر',
              ),
              Bi('Accept order', 'آرڈر قبول کریں'),
            ),
            TourStep(
              Icons.map_rounded,
              Bi(
                'Order is yours. The route is ready.',
                'آرڈر آپ کا ہے۔ راستہ تیار ہے۔',
              ),
              Bi('Navigate', 'راستہ کھولیں'),
            ),
          ],
        ),
      ),
      TourSlide(
        icon: Icons.local_shipping_rounded,
        title: const Bi('Deliver step by step', 'قدم بہ قدم ڈیلیوری'),
        body: const Bi(
          'One big button always shows the next step. Just tap it.',
          'ایک بڑا بٹن ہمیشہ اگلا قدم دکھاتا ہے۔ بس اسے دبائیں۔',
        ),
        demo: (c, u) => TourStepsDemo(
          urdu: u,
          steps: const [
            TourStep(
              Icons.two_wheeler_rounded,
              Bi('Pick up the full cylinders', 'بھرے ہوئے سلنڈر اٹھائیں'),
              Bi('On my way', 'میں روانہ ہوں'),
            ),
            TourStep(
              Icons.near_me_rounded,
              Bi(
                'Customer sees you coming, live',
                'کسٹمر آپ کو لائیو آتا دیکھتا ہے',
              ),
              Bi('I have arrived', 'میں پہنچ گیا'),
            ),
            TourStep(
              Icons.payments_rounded,
              Bi(
                'Take the cash and the empty cylinders',
                'رقم اور خالی سلنڈر لیں',
              ),
              Bi('Mark delivered', 'ڈیلیور ہو گیا'),
            ),
          ],
        ),
      ),
      TourSlide(
        icon: Icons.tips_and_updates_rounded,
        title: const Bi('Handy to know', 'کام کی باتیں'),
        body: const Bi(
          'Tap each one to see what it does.',
          'ہر ایک کو دبا کر دیکھیں کہ وہ کیا کرتا ہے۔',
        ),
        demo: (c, u) => TourTilesDemo(
          urdu: u,
          tiles: const [
            TourTile(
              Icons.layers_rounded,
              Bi('Many orders', 'کئی آرڈر'),
              Bi(
                'You can carry several orders at once. The app puts the stops in the best order for you.',
                'آپ ایک ساتھ کئی آرڈر لے جا سکتے ہیں۔ ایپ سب سے بہتر ترتیب خود بنا دیتی ہے۔',
              ),
            ),
            TourTile(
              Icons.call_rounded,
              Bi('Call', 'کال'),
              Bi(
                'Call or WhatsApp the customer from the order. No need to save the number.',
                'آرڈر سے ہی کسٹمر کو کال یا واٹس ایپ کریں۔ نمبر محفوظ کرنے کی ضرورت نہیں۔',
              ),
            ),
            TourTile(
              Icons.account_balance_wallet_rounded,
              Bi('Cash', 'رقم'),
              Bi(
                'Cash you collect is listed in Account. Hand it in at the end of the day.',
                'جو رقم آپ جمع کریں وہ اکاؤنٹ میں لکھی ہوتی ہے۔ دن کے آخر میں جمع کروائیں۔',
              ),
            ),
            TourTile(
              Icons.battery_charging_full_rounded,
              Bi('Stay on', 'چالو رہیں'),
              Bi(
                'Keep location on and the screen unlocked while delivering, so customers can follow you.',
                'ڈیلیوری کے دوران لوکیشن آن رکھیں تاکہ کسٹمر آپ کو دیکھ سکیں۔',
              ),
            ),
          ],
        ),
      ),
      TourSlide(
        icon: Icons.verified_rounded,
        title: const Bi('You are ready', 'آپ تیار ہیں'),
        body: const Bi(
          'You can replay this tour any time from Account > How the app works.',
          'یہ ٹور کسی بھی وقت اکاؤنٹ > ایپ استعمال کرنے کا طریقہ سے دوبارہ دیکھیں۔',
        ),
        demo: (c, u) => TourToggleDemo(
          urdu: u,
          offTitle: const Bi('Ready to ride?', 'چلنے کو تیار؟'),
          onTitle: const Bi('Good luck out there!', 'آپ کے لیے نیک تمنائیں!'),
          offHint: const Bi(
            'Tap, then press Get started',
            'بٹن دبائیں، پھر "شروع کریں" دبائیں',
          ),
          onHint: const Bi(
            'Press Get started below',
            'نیچے "شروع کریں" دبائیں',
          ),
        ),
      ),
    ],
  );
}
