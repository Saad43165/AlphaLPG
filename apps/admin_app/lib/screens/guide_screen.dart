import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';

/// "How the Admin app works", in English and Urdu.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key, this.shopPhone = ''});
  final String shopPhone;

  @override
  Widget build(BuildContext context) => GuidePage(
    contactPhone: shopPhone,
    appName: const Bi('How the Admin app works', 'ایڈمن ایپ کیسے کام کرتی ہے'),
    headline: const Bi(
      'Run the shop from one screen',
      'پوری دکان ایک ہی اسکرین سے چلائیں',
    ),
    intro: const Bi(
      'Every order, rider, payment and product is here. Read this once and your day will be simple. For you and for new staff.',
      'ہر آرڈر، رائیڈر، ادائیگی اور پروڈکٹ یہاں ہے۔ یہ ایک بار پڑھ لیں تو آپ کا دن آسان ہو جائے گا۔ آپ کے لیے اور نئے عملے کے لیے۔',
    ),
    sections: const [
      GuideSection(
        icon: Icons.storefront_rounded,
        title: Bi('1. Open the shop', '1۔ دکان کھولیں'),
        steps: [
          Bi(
            'On the Orders tab, the bar at the top shows if the shop is taking orders. Switch it on when you open. You can also set opening hours in Shop settings so it opens and closes by itself.',
            'آرڈرز ٹیب پر اوپر والی پٹی بتاتی ہے کہ دکان آرڈر لے رہی ہے یا نہیں۔ کھولتے وقت اسے آن کریں۔ آپ شاپ سیٹنگز میں اوقات بھی رکھ سکتے ہیں تاکہ دکان خود کھلے اور بند ہو۔',
          ),
          Bi(
            'Riders put themselves on shift in the Rider app. The row of riders under the numbers shows who is Free, busy or Offline.',
            'رائیڈرز رائیڈر ایپ میں خود ڈیوٹی آن کرتے ہیں۔ نمبروں کے نیچے رائیڈرز کی قطار دکھاتی ہے کون فارغ ہے، مصروف ہے یا آف لائن۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.dashboard_rounded,
        title: Bi(
          '2. Understand the Orders screen',
          '2۔ آرڈرز اسکرین کو سمجھیں',
        ),
        steps: [
          Bi(
            'New: orders waiting for you to confirm. Scheduled: orders the customer wants on another day. In progress: orders being delivered now, grouped as Waiting for a rider, Rider assigned and On the road.',
            'نیا: وہ آرڈر جن کی تصدیق آپ نے کرنی ہے۔ طے شدہ: وہ آرڈر جو کسٹمر نے کسی اور دن کے لیے رکھے ہیں۔ جاری: وہ آرڈر جو اس وقت پہنچائے جا رہے ہیں، یعنی رائیڈر کا انتظار، رائیڈر مقرر اور راستے میں۔',
          ),
          Bi(
            'Online payments: JazzCash, Easypaisa and bank orders waiting for you. Delivered and Cancelled are the finished orders.',
            'آن لائن ادائیگیاں: جاز کیش، ایزی پیسہ اور بینک کے آرڈر جو آپ کے منتظر ہیں۔ پہنچائے گئے اور منسوخ مکمل ہو چکے آرڈر ہیں۔',
          ),
          Bi(
            'The orange bars at the top tell you what needs you right now: an order waiting for a rider, a receipt to check, a customer who has not paid, a rider whose phone has gone quiet. Tap a bar to go straight to it.',
            'اوپر کی نارنجی پٹیاں بتاتی ہیں کہ ابھی کس چیز پر آپ کی توجہ چاہیے: رائیڈر کا منتظر آرڈر، چیک کرنے والی رسید، ادائیگی نہ کرنے والا کسٹمر، یا ایسا رائیڈر جس کا فون خاموش ہو گیا ہے۔ کسی پٹی پر ٹیپ کریں تو سیدھے وہیں پہنچ جائیں گے۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.check_circle_rounded,
        title: Bi('3. Confirm each new order', '3۔ ہر نئے آرڈر کی تصدیق کریں'),
        steps: [
          Bi(
            'A new order makes a sound and shows in New. Open it, check the items and the address, then tap Confirm order.',
            'نیا آرڈر آواز کے ساتھ آتا ہے اور "نیا" میں نظر آتا ہے۔ اسے کھولیں، اشیا اور پتا دیکھیں، پھر "آرڈر کی تصدیق" دبائیں۔',
          ),
          Bi(
            'A customer ordering for the first time is marked. Call them once to confirm the person and the address.',
            'پہلی بار آرڈر کرنے والے کسٹمر پر نشان ہوتا ہے۔ انہیں ایک بار کال کر کے شخص اور پتے کی تصدیق کر لیں۔',
          ),
          Bi(
            'A scheduled order shows a purple banner with the day and time. Confirm it now; give it to a rider on that day.',
            'طے شدہ آرڈر پر جامنی بینر میں دن اور وقت لکھا ہوتا ہے۔ اس کی ابھی تصدیق کریں؛ رائیڈر اسی دن دیں۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.two_wheeler_rounded,
        title: Bi('4. Give orders to riders', '4۔ آرڈر رائیڈرز کو دیں'),
        steps: [
          Bi(
            'Open a confirmed order and tap Assign rider. Choose someone who is Online. The list shows the nearest rider and how many cylinders each one already carries.',
            'تصدیق شدہ آرڈر کھولیں اور "رائیڈر مقرر کریں" دبائیں۔ کوئی آن لائن رائیڈر چنیں۔ فہرست میں سب سے قریبی رائیڈر اور ہر رائیڈر کے پاس موجود سلنڈروں کی تعداد نظر آتی ہے۔',
          ),
          Bi(
            'Several orders waiting? In In progress, tap Select several, tick the orders and give them to one rider together.',
            'کئی آرڈر منتظر ہیں؟ "جاری" میں "کئی چنیں" دبائیں، آرڈر منتخب کریں اور ایک ہی رائیڈر کو اکٹھے دے دیں۔',
          ),
          Bi(
            'In the Riders tab you can set the most cylinders a vehicle can carry. You are warned, not blocked, if you go over.',
            'رائیڈرز ٹیب میں آپ سلنڈروں کی وہ زیادہ سے زیادہ تعداد رکھ سکتے ہیں جو گاڑی اٹھا سکتی ہے۔ حد سے زیادہ دینے پر تنبیہ ملتی ہے، روک نہیں لگتی۔',
          ),
          Bi(
            'Until a rider leaves, you can take the order back. Once it is on the road it stays with the rider.',
            'رائیڈر کے روانہ ہونے تک آپ آرڈر واپس لے سکتے ہیں۔ راستے میں آنے کے بعد وہ رائیڈر ہی کے پاس رہتا ہے۔',
          ),
        ],
        tip: Bi(
          'A rider carrying an order cannot go offline, and you cannot switch them off either. Deliver or take back the order first.',
          'جس رائیڈر کے پاس آرڈر ہو وہ آف لائن نہیں ہو سکتا، اور آپ بھی اسے آف نہیں کر سکتے۔ پہلے آرڈر پہنچائیں یا واپس لیں۔',
        ),
      ),
      GuideSection(
        icon: Icons.payments_rounded,
        title: Bi('5. Check the payments', '5۔ ادائیگیاں چیک کریں'),
        steps: [
          Bi(
            'Cash on delivery: the rider collects it. The order is paid when the rider marks it delivered.',
            'کیش آن ڈیلیوری: رقم رائیڈر وصول کرتا ہے۔ رائیڈر کے "ڈیلیور" کرتے ہی آرڈر ادا شدہ ہو جاتا ہے۔',
          ),
          Bi(
            'JazzCash, Easypaisa or bank: open the order and tap Send payment details. The customer pays and sends a screenshot, the transaction ID and the amount.',
            'جاز کیش، ایزی پیسہ یا بینک: آرڈر کھولیں اور "ادائیگی کی تفصیل بھیجیں" دبائیں۔ کسٹمر ادائیگی کر کے اسکرین شاٹ، ٹرانزیکشن آئی ڈی اور رقم بھیجتا ہے۔',
          ),
          Bi(
            'Check the amount and the ID in your own JazzCash, Easypaisa or bank app. Only then tap Mark paid. If the receipt is wrong, tap Receipt problem and say why.',
            'رقم اور آئی ڈی اپنی جاز کیش، ایزی پیسہ یا بینک ایپ میں چیک کریں۔ اس کے بعد ہی "ادا شدہ" دبائیں۔ رسید غلط ہو تو "رسید میں مسئلہ" دبا کر وجہ بتائیں۔',
          ),
        ],
        tip: Bi(
          'The app warns you if the same transaction ID was used twice. Take that warning seriously.',
          'اگر ایک ہی ٹرانزیکشن آئی ڈی دو بار استعمال ہو تو ایپ آپ کو خبردار کرتی ہے۔ اس تنبیہ کو سنجیدگی سے لیں۔',
        ),
      ),
      GuideSection(
        icon: Icons.groups_rounded,
        title: Bi('6. Riders', '6۔ رائیڈرز'),
        steps: [
          Bi(
            'Riders tab → Add rider: name, phone, email and password. They sign in to the Rider app with that email and password.',
            'رائیڈرز ٹیب ← "رائیڈر شامل کریں": نام، فون، ای میل اور پاس ورڈ۔ وہ اسی ای میل اور پاس ورڈ سے رائیڈر ایپ میں سائن اِن کرتے ہیں۔',
          ),
          Bi(
            'Statuses: Free = on shift with no order. N jobs = on shift and busy. On the road = delivering now. No signal = the phone has not reported for a while. Offline = off shift.',
            'حالتیں: فارغ = ڈیوٹی پر اور کوئی آرڈر نہیں۔ N کام = ڈیوٹی پر اور مصروف۔ راستے میں = ابھی ڈیلیوری کر رہا ہے۔ سگنل نہیں = فون کچھ دیر سے رپورٹ نہیں کر رہا۔ آف لائن = ڈیوٹی ختم۔',
          ),
          Bi(
            'Tap a rider in the row on the Orders tab to see their orders and call them.',
            'آرڈرز ٹیب پر قطار میں کسی رائیڈر پر ٹیپ کر کے اس کے آرڈر دیکھیں اور اسے کال کریں۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.report_rounded,
        title: Bi('7. Customers and problems', '7۔ کسٹمرز اور مسائل'),
        steps: [
          Bi(
            'More → Reports and problems: complaints from customers and problems from riders. Answer each one; the customer sees your reply.',
            'مزید ← رپورٹس اور مسائل: کسٹمرز کی شکایات اور رائیڈرز کے مسائل۔ ہر ایک کا جواب دیں؛ کسٹمر آپ کا جواب دیکھتا ہے۔',
          ),
          Bi(
            'For a refund request choose Refunded or Declined when you answer. The customer sees the result.',
            'رقم کی واپسی کی درخواست پر جواب دیتے وقت "رقم واپس" یا "مسترد" چنیں۔ کسٹمر نتیجہ دیکھتا ہے۔',
          ),
          Bi(
            'More → Customers: orders, empty cylinders they owe, deposits. You can block a customer who misuses the app.',
            'مزید ← کسٹمرز: آرڈر، ان کے ذمے خالی سلنڈر اور ڈپازٹ۔ ایپ کا غلط استعمال کرنے والے کسٹمر کو آپ بلاک کر سکتے ہیں۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.inventory_2_rounded,
        title: Bi(
          '8. Products, prices and settings',
          '8۔ پروڈکٹس، قیمتیں اور سیٹنگز',
        ),
        steps: [
          Bi(
            'Shop tab: add or edit a cylinder, its price, its picture and how many are in stock. A product with no stock shows as out of stock to customers.',
            'شاپ ٹیب: سلنڈر، اس کی قیمت، تصویر اور اسٹاک میں موجود تعداد شامل یا تبدیل کریں۔ جس پروڈکٹ کا اسٹاک ختم ہو وہ کسٹمرز کو "اسٹاک ختم" دکھائی دیتی ہے۔',
          ),
          Bi(
            'Edit shop settings: delivery fee, free delivery above an amount, areas you serve, opening hours, and the bank, JazzCash and Easypaisa accounts customers pay to.',
            '"شاپ سیٹنگز": ڈیلیوری فیس، ایک رقم سے اوپر مفت ڈیلیوری، آپ کے علاقے، اوقات، اور بینک، جاز کیش اور ایزی پیسہ اکاؤنٹس جن میں کسٹمر ادائیگی کرتے ہیں۔',
          ),
          Bi(
            'Changes reach customers straight away.',
            'تبدیلیاں فوراً کسٹمرز تک پہنچ جاتی ہیں۔',
          ),
        ],
        tip: Bi(
          'Keep the account numbers correct. A wrong number sends your customers\' money to the wrong place.',
          'اکاؤنٹ نمبر درست رکھیں۔ غلط نمبر سے کسٹمرز کی رقم غلط جگہ چلی جاتی ہے۔',
        ),
      ),
      GuideSection(
        icon: Icons.local_offer_rounded,
        title: Bi('9. Offers', '9۔ آفرز'),
        steps: [
          Bi(
            'More → Coupons and rewards: make a code such as WELCOME200 for Rs. 200 off. Each customer can use a code once.',
            'مزید ← کوپن اور انعامات: WELCOME200 جیسا کوڈ بنائیں جو Rs. 200 کی چھوٹ دے۔ ہر کسٹمر ایک کوڈ ایک ہی بار استعمال کر سکتا ہے۔',
          ),
          Bi(
            'Every customer also has an invite code for friends. Reward points and the refill plan are off until you switch them on there.',
            'ہر کسٹمر کا دوستوں کے لیے اپنا دعوتی کوڈ بھی ہوتا ہے۔ انعامی پوائنٹس اور ریفل پلان اس وقت تک بند ہیں جب تک آپ وہیں انہیں آن نہ کریں۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.nightlight_round,
        title: Bi('10. Close the day', '10۔ دن بند کریں'),
        steps: [
          Bi(
            'More → Cash handover: receive the cash each rider hands in. It shows what each rider still owes.',
            'مزید ← رقم کی وصولی: ہر رائیڈر کی جمع کروائی ہوئی رقم وصول کریں۔ یہ دکھاتا ہے کہ ہر رائیڈر کے ذمے ابھی کتنی رقم ہے۔',
          ),
          Bi(
            'Look at the Sales and cash report for today, 7 days or 30 days.',
            'آج، 7 دن یا 30 دن کی سیلز اور کیش رپورٹ دیکھیں۔',
          ),
          Bi(
            'Answer open problems, then switch the shop off (or let the opening hours do it).',
            'کھلے مسائل کا جواب دیں، پھر دکان بند کریں (یا اوقات کو خود بند کرنے دیں)۔',
          ),
        ],
      ),
      GuideSection(
        icon: Icons.security_rounded,
        title: Bi('11. Keep your data safe', '11۔ اپنا ڈیٹا محفوظ رکھیں'),
        steps: [
          Bi(
            'More → Backup all data: save a copy of your orders, customers and products now and then.',
            'مزید ← تمام ڈیٹا کا بیک اپ: وقتاً فوقتاً اپنے آرڈر، کسٹمرز اور پروڈکٹس کی کاپی محفوظ کریں۔',
          ),
          Bi(
            'Free up space (owner only): deletes old receipt pictures and delivery photos of orders older than 90 days. The orders and amounts stay.',
            '"جگہ خالی کریں" (صرف مالک): 90 دن سے پرانے آرڈرز کی رسیدوں اور ڈیلیوری کی تصاویر ڈیلیٹ کرتا ہے۔ آرڈر اور رقوم محفوظ رہتی ہیں۔',
          ),
          Bi(
            'Owner and staff: staff can run orders, riders and payments. Only the owner can change shop settings, delete products and add staff.',
            'مالک اور عملہ: عملہ آرڈر، رائیڈرز اور ادائیگیاں چلا سکتا ہے۔ شاپ سیٹنگز بدلنا، پروڈکٹ ڈیلیٹ کرنا اور عملہ شامل کرنا صرف مالک کر سکتا ہے۔',
          ),
        ],
      ),
    ],
  );
}
