import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'tour_screen.dart';

/// "How the Rider app works", in English and Urdu.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key, this.shopPhone = ''});
  final String shopPhone;

  @override
  Widget build(BuildContext context) => GuidePage(
    onTour: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (c) => RiderTour(onDone: () => Navigator.of(c).pop()),
      ),
    ),
    contactPhone: shopPhone,
    appName: const Bi('How the Rider app works', 'رائیڈر ایپ کیسے کام کرتی ہے'),
    headline: const Bi(
      'Take orders, deliver, hand in the cash',
      'آرڈر لیں، ڈیلیوری کریں، رقم جمع کروائیں',
    ),
    intro: const Bi(
      'This guide covers your day: going online, taking orders, delivering safely and handing in the money.',
      'یہ رہنما آپ کے دن کے بارے میں ہے: آن لائن ہونا، آرڈر لینا، محفوظ طریقے سے ڈیلیوری کرنا اور رقم جمع کروانا۔',
    ),
    sections: const [
      GuideSection(
        icon: Icons.power_settings_new_rounded,
        title: Bi('Start your shift', 'ڈیوٹی شروع کریں'),
        steps: [
          Bi(
            'Turn the switch at the top to ONLINE. Only online riders receive orders.',
            'اوپر والا سوئچ "آن لائن" کریں۔ صرف آن لائن رائیڈرز کو آرڈر ملتے ہیں۔',
          ),
          Bi(
            'Allow location when the app asks. The shop and your customers need it to see where you are.',
            'ایپ کے پوچھنے پر لوکیشن کی اجازت دیں۔ دکان اور آپ کے کسٹمرز کو یہ دیکھنے کے لیے چاہیے کہ آپ کہاں ہیں۔',
          ),
          Bi(
            'You cannot go offline while you carry orders. Deliver them, or give back the ones you have not started.',
            'آرڈر ساتھ ہوں تو آپ آف لائن نہیں ہو سکتے۔ انہیں پہنچائیں، یا جو آرڈر شروع نہیں کیے وہ واپس کر دیں۔',
          ),
        ],
        tip: Bi(
          'Switch OFFLINE when you finish for the day, so the shop knows who is available.',
          'دن ختم ہونے پر "آف لائن" کر دیں تاکہ دکان کو پتا ہو کون دستیاب ہے۔',
        ),
      ),
      GuideSection(
        icon: Icons.notifications_active_rounded,
        title: Bi('Take orders', 'آرڈر لیں'),
        steps: [
          Bi(
            'The New tab shows orders nobody has taken. Tap Accept job: the first rider to tap gets it.',
            '"نیا" ٹیب میں وہ آرڈر ہیں جو کسی نے نہیں لیے۔ "کام قبول کریں" دبائیں: جو رائیڈر پہلے دبائے اسے آرڈر مل جاتا ہے۔',
          ),
          Bi(
            'The shop can also give you an order directly. It appears in My jobs.',
            'دکان آپ کو براہِ راست بھی آرڈر دے سکتی ہے۔ وہ "میرے کام" میں نظر آتا ہے۔',
          ),
          Bi(
            'An order the customer scheduled for another day shows in New only a few hours before its time.',
            'جو آرڈر کسٹمر نے کسی اور دن کے لیے طے کیا ہو وہ اپنے وقت سے چند گھنٹے پہلے ہی "نیا" میں آتا ہے۔',
          ),
          Bi(
            'If the shop set a cylinder limit for your vehicle, you cannot accept more than that at once.',
            'اگر دکان نے آپ کی گاڑی کے لیے سلنڈروں کی حد رکھی ہے تو آپ ایک وقت میں اس سے زیادہ قبول نہیں کر سکتے۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.route_rounded,
        title: Bi('Plan your round', 'اپنا راؤنڈ ترتیب دیں'),
        steps: [
          Bi(
            'With two or more orders, My jobs shows Next stop, Stop 2 and so on, starting with the nearest customer.',
            'دو یا زیادہ آرڈر ہوں تو "میرے کام" میں "اگلا اسٹاپ"، "اسٹاپ 2" وغیرہ نظر آتے ہیں، سب سے قریبی کسٹمر سے شروع کر کے۔',
          ),
          Bi(
            'It is only a suggestion. You can open and deliver any order you choose.',
            'یہ صرف ایک مشورہ ہے۔ آپ جو آرڈر چاہیں کھول کر پہنچا سکتے ہیں۔',
          ),
          Bi(
            'The arrow button on a job opens Google Maps to the customer.',
            'کام پر تیر والا بٹن گوگل میپس میں کسٹمر تک راستہ کھول دیتا ہے۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.two_wheeler_rounded,
        title: Bi('Start a delivery', 'ڈیلیوری شروع کریں'),
        steps: [
          Bi(
            'Tap Start delivery when you leave. Keep your location on: the customer follows you on the map.',
            'روانہ ہوتے وقت "ڈیلیوری شروع کریں" دبائیں۔ اپنی لوکیشن آن رکھیں: کسٹمر آپ کو نقشے پر دیکھتا ہے۔',
          ),
          Bi(
            'If you carry several orders, every customer sees you.',
            'اگر آپ کے پاس کئی آرڈر ہیں تو ہر کسٹمر آپ کو دیکھ سکتا ہے۔',
          ),
          Bi(
            'Call, WhatsApp or message the customer from the order if you cannot find the house.',
            'گھر نہ ملے تو آرڈر سے کسٹمر کو کال، واٹس ایپ یا پیغام کریں۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.door_front_door_rounded,
        title: Bi('At the door', 'دروازے پر'),
        steps: [
          Bi(
            'Tap I have arrived so the customer knows you are there.',
            '"میں پہنچ گیا ہوں" دبائیں تاکہ کسٹمر کو پتا چل جائے۔',
          ),
          Bi(
            'Hand over the full cylinder and take the empty one. Tick each empty cylinder you took.',
            'بھرا ہوا سلنڈر دیں اور خالی سلنڈر لیں۔ جتنے خالی سلنڈر آپ نے لیے ان پر نشان لگائیں۔',
          ),
          Bi(
            'Cash on delivery: take the amount shown on the screen. For JazzCash, Easypaisa or bank orders do not take cash: the customer has paid or the shop confirms it.',
            'کیش آن ڈیلیوری: اسکرین پر دکھائی گئی رقم لیں۔ جاز کیش، ایزی پیسہ یا بینک کے آرڈر میں نقد نہ لیں: کسٹمر ادائیگی کر چکا ہے یا دکان تصدیق کرے گی۔',
          ),
          Bi(
            'Take a photo of the delivered cylinders, then tap Mark as delivered.',
            'پہنچائے گئے سلنڈروں کی تصویر لیں، پھر "ڈیلیور ہو گیا" دبائیں۔',
          ),
        ],
        tip: Bi(
          'The photo protects you if a customer says the order did not arrive.',
          'اگر کسٹمر کہے کہ آرڈر نہیں پہنچا تو تصویر آپ کا تحفظ کرتی ہے۔',
        ),
      ),
      GuideSection(
        icon: Icons.account_balance_wallet_rounded,
        title: Bi('Cash and earnings', 'رقم اور کمائی'),
        steps: [
          Bi(
            '"Cash held" shows the money you collected and still have to hand in.',
            '"آپ کے پاس رقم" وہ پیسے ہیں جو آپ نے وصول کیے اور ابھی جمع کروانے ہیں۔',
          ),
          Bi(
            'Give it to Alpha LPG. The shop records it, and your balance goes down.',
            'یہ رقم الفا ایل پی جی کو دیں۔ دکان اسے درج کرتی ہے اور آپ کا بیلنس کم ہو جاتا ہے۔',
          ),
          Bi(
            'Me → My earnings and cash shows your deliveries, cash and ratings.',
            '"میں ← میری کمائی اور رقم" میں آپ کی ڈیلیوریاں، رقم اور ریٹنگز نظر آتی ہیں۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.report_problem_rounded,
        title: Bi('When there is a problem', 'جب کوئی مسئلہ ہو'),
        steps: [
          Bi(
            'Customer not answering, wrong address, or refuses the order: open the order and tap Report a problem. The shop sees it at once.',
            'کسٹمر جواب نہیں دے رہا، پتا غلط ہے، یا آرڈر لینے سے انکار کر رہا ہے: آرڈر کھولیں اور "مسئلہ بتائیں" دبائیں۔ دکان کو فوراً نظر آ جاتا ہے۔',
          ),
          Bi(
            'If you have not started an order yet, you can give it back to the shop so another rider takes it.',
            'اگر آپ نے آرڈر ابھی شروع نہیں کیا تو اسے دکان کو واپس کر سکتے ہیں تاکہ دوسرا رائیڈر لے لے۔',
          ),
          Bi(
            'Once an order is on the road it stays with you. Call the shop if you cannot finish it.',
            'جب آرڈر راستے میں ہو تو وہ آپ ہی کے پاس رہتا ہے۔ نہ پہنچا سکیں تو دکان کو کال کریں۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.battery_charging_full_rounded,
        title: Bi('Keep the app working', 'ایپ کو چلتا رکھیں'),
        steps: [
          Bi(
            'Keep GPS and mobile data on, and charge your phone.',
            'جی پی ایس اور موبائل ڈیٹا آن رکھیں اور فون چارج رکھیں۔',
          ),
          Bi(
            'Follow Me → Keep the app running once, so Android does not close the app in the background.',
            '"میں ← ایپ کو چلتا رکھیں" پر ایک بار عمل کریں تاکہ اینڈرائیڈ ایپ کو پس منظر میں بند نہ کرے۔',
          ),
          Bi(
            'If a red bar says your location is off, tap Settings and turn it on.',
            'اگر سرخ پٹی کہے کہ آپ کی لوکیشن بند ہے تو "سیٹنگز" دبا کر اسے آن کریں۔',
          ),
        ],
      ),
    ],
  );
}
