import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart' hide Text;
import 'package:provider/provider.dart';

import '../../l10n/lang.dart';
import '../../state/app_state.dart';

/// "How to use the app", in English and Urdu.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) => GuidePage(
    startInUrdu: Lang.isUrdu,
    contactPhone: context.read<AppState>().settings.phone,
    appName: const Bi('How to use the app', 'ایپ استعمال کرنے کا طریقہ'),
    headline: const Bi(
      'Gas at your door, in a few taps',
      'گیس آپ کے دروازے تک، چند ٹیپ میں',
    ),
    intro: const Bi(
      'Alpha LPG delivers safe, full gas cylinders across Lahore. This guide shows how to order, pay and follow your delivery.',
      'الفا ایل پی جی لاہور بھر میں محفوظ اور بھرے ہوئے گیس سلنڈر پہنچاتی ہے۔ یہ رہنما بتاتا ہے کہ آرڈر کیسے کریں، ادائیگی کیسے کریں اور اپنی ڈیلیوری کو کیسے ٹریک کریں۔',
    ),
    sections: const [
      GuideSection(
        icon: Icons.shopping_cart_rounded,
        title: Bi('Place an order', 'آرڈر دینا'),
        steps: [
          Bi(
            'On the Order tab, tap Add on the cylinder you need. Choose Refill if you hand over your empty cylinder, or New cylinder if you do not have one.',
            'آرڈر ٹیب پر اپنی ضرورت کے سلنڈر پر "شامل کریں" دبائیں۔ اگر آپ خالی سلنڈر دیں گے تو "ریفل" چنیں، اور اگر آپ کے پاس خالی سلنڈر نہیں تو "نیا سلنڈر" چنیں۔',
          ),
          Bi(
            'Tap View cart, then Checkout.',
            '"کارٹ دیکھیں" دبائیں، پھر "چیک آؤٹ"۔',
          ),
          Bi(
            'Check your delivery address, choose when you want it (as soon as possible, or a day and time you pick) and how you will pay.',
            'اپنا ڈیلیوری کا پتا دیکھیں، وقت چنیں (جلد از جلد، یا اپنی پسند کا دن اور وقت) اور ادائیگی کا طریقہ چنیں۔',
          ),
          Bi(
            'Slide the bar at the bottom to place the order. Alpha LPG confirms it and sends a rider.',
            'آرڈر دینے کے لیے نیچے والی پٹی کو سلائیڈ کریں۔ الفا ایل پی جی اس کی تصدیق کر کے رائیڈر بھیجتی ہے۔',
          ),
        ],
        tip: Bi(
          'Ordering again? Tap Order again on the home screen or in My orders. You only slide to confirm.',
          'دوبارہ آرڈر کرنا ہے؟ ہوم اسکرین پر یا "میرے آرڈر" میں "دوبارہ آرڈر کریں" دبائیں۔ آپ کو صرف سلائیڈ کر کے تصدیق کرنی ہے۔',
        ),
      ),
      GuideSection(
        icon: Icons.location_on_rounded,
        title: Bi('Your delivery address', 'ڈیلیوری کا پتا'),
        steps: [
          Bi(
            'Tap Use my current location, or move the map pin to your door. Add a floor or a landmark so the rider finds you easily.',
            '"میری موجودہ لوکیشن استعمال کریں" دبائیں، یا نقشے کا پن اپنے دروازے پر لے جائیں۔ منزل یا کوئی نشانی لکھ دیں تاکہ رائیڈر آپ کو آسانی سے ڈھونڈ لے۔',
          ),
          Bi(
            'We deliver inside Lahore. You can save several addresses (home, shop) in Account.',
            'ہم لاہور کے اندر ڈیلیوری کرتے ہیں۔ آپ اکاؤنٹ میں کئی پتے (گھر، دکان) محفوظ کر سکتے ہیں۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.payments_rounded,
        title: Bi('Paying for your order', 'ادائیگی کا طریقہ'),
        steps: [
          Bi(
            'Cash on delivery: pay the rider at your door.',
            'کیش آن ڈیلیوری: دروازے پر رائیڈر کو نقد ادائیگی کریں۔',
          ),
          Bi(
            'JazzCash, Easypaisa or bank transfer: place the order first. Alpha LPG then sends you the account on your order screen, with a notification. Do not pay before that.',
            'جاز کیش، ایزی پیسہ یا بینک ٹرانسفر: پہلے آرڈر دیں۔ پھر الفا ایل پی جی آپ کی آرڈر اسکرین پر اکاؤنٹ بھیجتی ہے اور نوٹیفکیشن آتا ہے۔ اس سے پہلے ادائیگی نہ کریں۔',
          ),
          Bi(
            'Send the exact amount, then add the screenshot, the transaction ID and the amount you sent. Alpha LPG checks it and marks your order as paid.',
            'پوری رقم بھیجیں، پھر اسکرین شاٹ، ٹرانزیکشن آئی ڈی اور بھیجی گئی رقم شامل کریں۔ الفا ایل پی جی چیک کر کے آپ کے آرڈر کو "ادا شدہ" کر دیتی ہے۔',
          ),
        ],
        tip: Bi(
          'The screenshot, the ID and the amount are all required. This keeps your payment safe.',
          'اسکرین شاٹ، آئی ڈی اور رقم تینوں ضروری ہیں۔ اس سے آپ کی ادائیگی محفوظ رہتی ہے۔',
        ),
      ),
      GuideSection(
        icon: Icons.local_shipping_rounded,
        title: Bi('Follow your delivery', 'اپنی ڈیلیوری کو ٹریک کریں'),
        steps: [
          Bi(
            'The home screen shows your order and where it is: placed, confirmed, rider assigned, on the way, delivered.',
            'ہوم اسکرین پر آپ کا آرڈر اور اس کی حالت نظر آتی ہے: آرڈر دیا گیا، تصدیق، رائیڈر مقرر، راستے میں، پہنچا دیا گیا۔',
          ),
          Bi(
            'When the rider is on the way you can see them on the map, call them or send a message.',
            'رائیڈر راستے میں ہو تو آپ اسے نقشے پر دیکھ سکتے ہیں، کال کر سکتے ہیں یا پیغام بھیج سکتے ہیں۔',
          ),
          Bi(
            'Keep your empty cylinder ready for the swap.',
            'تبدیلی کے لیے اپنا خالی سلنڈر تیار رکھیں۔',
          ),
          Bi(
            'After delivery the chat closes. Please rate the delivery, and use Report if anything was wrong.',
            'ڈیلیوری کے بعد چیٹ بند ہو جاتی ہے۔ براہِ کرم ڈیلیوری کو ریٹنگ دیں، اور کوئی مسئلہ ہو تو "رپورٹ" استعمال کریں۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.event_rounded,
        title: Bi('Choose a day and time', 'دن اور وقت طے کریں'),
        steps: [
          Bi(
            'At checkout choose Schedule, then pick a day and a time slot (morning, afternoon or evening).',
            'چیک آؤٹ پر "وقت طے کریں" چنیں، پھر دن اور وقت (صبح، دوپہر یا شام) منتخب کریں۔',
          ),
          Bi(
            'Alpha LPG confirms your order now and sends the rider on your day.',
            'الفا ایل پی جی آپ کے آرڈر کی ابھی تصدیق کرتی ہے اور آپ کے دن رائیڈر بھیجتی ہے۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.card_giftcard_rounded,
        title: Bi('Offers and friends', 'آفرز اور دوست'),
        steps: [
          Bi(
            'Have a coupon? Type it in the code box at checkout and tap Apply.',
            'کوپن ہے؟ چیک آؤٹ پر کوڈ والے خانے میں لکھیں اور "لاگو کریں" دبائیں۔',
          ),
          Bi(
            'Account → Invite friends: share your own code. Your friend gets a discount on their first order.',
            'اکاؤنٹ ← دوستوں کو دعوت دیں: اپنا کوڈ شیئر کریں۔ آپ کے دوست کو پہلے آرڈر پر چھوٹ ملتی ہے۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.factory_rounded,
        title: Bi('Restaurants and big orders', 'ریسٹورنٹ اور بڑے آرڈر'),
        steps: [
          Bi(
            'Account → Bulk / business quote. Say how many cylinders you need and how often.',
            'اکاؤنٹ ← بڑا / کاروباری آرڈر۔ بتائیں کتنے سلنڈر چاہییں اور کتنے وقفے سے۔',
          ),
          Bi(
            'Alpha LPG sends you the rate in the app, or calls or messages you on WhatsApp.',
            'الفا ایل پی جی آپ کو ایپ میں ریٹ بھیجتی ہے، یا واٹس ایپ پر کال یا پیغام کرتی ہے۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.support_agent_rounded,
        title: Bi('If something goes wrong', 'اگر کوئی مسئلہ ہو جائے'),
        steps: [
          Bi(
            'You can cancel your order while it is still "placed". After that, please call us.',
            'جب تک آرڈر "دیا گیا" کی حالت میں ہو آپ اسے منسوخ کر سکتے ہیں۔ اس کے بعد براہِ کرم ہمیں کال کریں۔',
          ),
          Bi(
            'Account → Help center: report a problem or ask for a refund on any order, and see our answer there.',
            'اکاؤنٹ ← مدد کا مرکز: کسی بھی آرڈر کا مسئلہ بتائیں یا رقم کی واپسی مانگیں، اور ہمارا جواب وہیں دیکھیں۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.health_and_safety_rounded,
        title: Bi('Gas safety', 'گیس کی حفاظت'),
        intro: Bi('If you smell gas:', 'اگر آپ کو گیس کی بو آئے:'),
        steps: [
          Bi(
            'Do not switch anything on or off, and do not light a flame.',
            'کوئی سوئچ آن یا آف نہ کریں اور آگ نہ جلائیں۔',
          ),
          Bi(
            'Open doors and windows. If it is safe, close the cylinder valve.',
            'دروازے اور کھڑکیاں کھول دیں۔ اگر محفوظ ہو تو سلنڈر کا والو بند کر دیں۔',
          ),
          Bi(
            'Leave the area and call Alpha LPG or Rescue 1122.',
            'جگہ چھوڑ دیں اور الفا ایل پی جی یا ریسکیو 1122 کو کال کریں۔',
          ),
        ],
        tip: Bi(
          'Never check a leak with a flame. Use soapy water: bubbles mean a leak.',
          'لیک کی جانچ کبھی آگ سے نہ کریں۔ صابن والا پانی استعمال کریں: بلبلے بنیں تو لیک ہے۔',
        ),
      ),
      GuideSection(
        icon: Icons.translate_rounded,
        title: Bi('Language', 'زبان'),
        steps: [
          Bi(
            'Change between English and Urdu in Account → Settings. The whole app switches.',
            'اکاؤنٹ ← سیٹنگز میں انگریزی اور اردو کے درمیان بدلیں۔ پوری ایپ بدل جاتی ہے۔',
          ),
        ],
      ),
    ],
  );
}
