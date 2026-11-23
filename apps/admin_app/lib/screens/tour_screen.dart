import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';

/// The welcome tour the owner or staff see the first time the app opens.
class AdminTour extends StatelessWidget {
  const AdminTour({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => TourPage(
    appName: const Bi('Alpha LPG Admin', 'الفا ایل پی جی ایڈمن'),
    onDone: onDone,
    slides: [
      TourSlide(
        icon: Icons.storefront_rounded,
        title: const Bi('Your shop in your pocket', 'آپ کی دکان آپ کی جیب میں'),
        body: const Bi(
          'Open and close the shop with one switch. Try it.',
          'ایک سوئچ سے دکان کھولیں اور بند کریں۔ آزما کر دیکھیں۔',
        ),
        demo: (c, u) => TourToggleDemo(
          urdu: u,
          offTitle: const Bi('Orders paused', 'آرڈر بند ہیں'),
          onTitle: const Bi('Taking orders', 'آرڈر لے رہے ہیں'),
          offHint: const Bi(
            'Customers see your closed message',
            'کسٹمر کو بند ہونے کا پیغام نظر آتا ہے',
          ),
          onHint: const Bi(
            'Customers can order right now',
            'کسٹمر ابھی آرڈر کر سکتے ہیں',
          ),
        ),
      ),
      TourSlide(
        icon: Icons.dashboard_rounded,
        title: const Bi('Every order, one screen', 'ہر آرڈر، ایک اسکرین'),
        body: const Bi(
          'The Orders tab sorts everything for you. Tap a filter to see.',
          'آرڈرز ٹیب سب کچھ ترتیب سے دکھاتا ہے۔ فلٹر دبا کر دیکھیں۔',
        ),
        demo: (c, u) => TourTilesDemo(
          urdu: u,
          tiles: const [
            TourTile(
              Icons.fiber_new_rounded,
              Bi('New', 'نئے'),
              Bi(
                'Just arrived. Confirm them and pick a rider. New orders also ring on this phone.',
                'ابھی آئے ہیں۔ انہیں کنفرم کریں اور رائیڈر چنیں۔ نئے آرڈر اس فون پر بجتے بھی ہیں۔',
              ),
            ),
            TourTile(
              Icons.event_rounded,
              Bi('Scheduled', 'طے شدہ'),
              Bi(
                'Orders the customer booked for later. They wait here until their time.',
                'کسٹمر نے بعد کے وقت کے لیے بک کیے۔ وقت آنے تک یہاں رہتے ہیں۔',
              ),
            ),
            TourTile(
              Icons.local_shipping_rounded,
              Bi('In progress', 'جاری'),
              Bi(
                'A rider has them and is on the way. You can watch the rider live.',
                'رائیڈر کے پاس ہیں اور راستے میں ہیں۔ آپ رائیڈر کو لائیو دیکھ سکتے ہیں۔',
              ),
            ),
            TourTile(
              Icons.account_balance_rounded,
              Bi('Online payments', 'آن لائن ادائیگی'),
              Bi(
                'JazzCash, Easypaisa or bank orders. Check the money, then confirm it.',
                'جاز کیش، ایزی پیسہ یا بینک کے آرڈر۔ رقم دیکھیں، پھر تصدیق کریں۔',
              ),
            ),
            TourTile(
              Icons.check_circle_rounded,
              Bi('Delivered', 'مکمل'),
              Bi(
                'Finished orders, with the cash and empties the rider handed in.',
                'مکمل آرڈر، رائیڈر کی جمع کردہ رقم اور خالی سلنڈر کے ساتھ۔',
              ),
            ),
          ],
        ),
      ),
      TourSlide(
        icon: Icons.two_wheeler_rounded,
        title: const Bi('Send it with a rider', 'رائیڈر کے ساتھ بھیجیں'),
        body: const Bi(
          'Three taps from a new order to a rider on the way.',
          'نئے آرڈر سے رائیڈر کے روانہ ہونے تک صرف تین ٹیپ۔',
        ),
        demo: (c, u) => TourStepsDemo(
          urdu: u,
          steps: const [
            TourStep(
              Icons.notifications_active_rounded,
              Bi('New order from Gulberg', 'گلبرگ سے نیا آرڈر'),
              Bi('Confirm order', 'آرڈر کنفرم کریں'),
            ),
            TourStep(
              Icons.groups_rounded,
              Bi(
                'Pick a free rider. Busy ones show their load.',
                'فارغ رائیڈر چنیں۔ مصروف رائیڈر کا بوجھ دکھایا جاتا ہے۔',
              ),
              Bi('Assign rider', 'رائیڈر مقرر کریں'),
            ),
            TourStep(
              Icons.near_me_rounded,
              Bi(
                'The rider is on the way. The customer follows live.',
                'رائیڈر راستے میں ہے۔ کسٹمر لائیو دیکھتا ہے۔',
              ),
              Bi('Track on the map', 'نقشے پر دیکھیں'),
            ),
          ],
        ),
      ),
      TourSlide(
        icon: Icons.sell_rounded,
        title: const Bi('Prices and products', 'قیمتیں اور پروڈکٹس'),
        body: const Bi(
          'Everything customers see is edited in the Shop tab.',
          'کسٹمر جو کچھ دیکھتے ہیں اسے شاپ ٹیب میں بدلیں۔',
        ),
        demo: (c, u) => TourTilesDemo(
          urdu: u,
          tiles: const [
            TourTile(
              Icons.propane_tank_rounded,
              Bi('Cylinders', 'سلنڈر'),
              Bi(
                'Change refill and new-cylinder prices. Customers see the new price straight away.',
                'ری فل اور نئے سلنڈر کی قیمتیں بدلیں۔ کسٹمر کو نئی قیمت فوراً نظر آتی ہے۔',
              ),
            ),
            TourTile(
              Icons.soup_kitchen_rounded,
              Bi('Stoves', 'چولہے'),
              Bi(
                'Add stoves and regulators with one price and a photo. They are not counted as cylinders.',
                'چولہے اور ریگولیٹر ایک قیمت اور تصویر کے ساتھ شامل کریں۔ یہ سلنڈر میں شمار نہیں ہوتے۔',
              ),
            ),
            TourTile(
              Icons.inventory_2_rounded,
              Bi('Stock', 'اسٹاک'),
              Bi(
                'Type how many you have. At 0 the item shows "out of stock" by itself.',
                'جتنے ہیں وہ لکھ دیں۔ 0 ہونے پر آئٹم خود "اسٹاک ختم" دکھاتا ہے۔',
              ),
            ),
            TourTile(
              Icons.delivery_dining_rounded,
              Bi('Delivery', 'ڈیلیوری'),
              Bi(
                'Set delivery fees by area, opening hours and payment details in Shop settings.',
                'شاپ سیٹنگز میں علاقے کے حساب سے ڈیلیوری فیس، اوقات اور ادائیگی کی تفصیل رکھیں۔',
              ),
            ),
          ],
        ),
      ),
      TourSlide(
        icon: Icons.verified_rounded,
        title: const Bi('You are all set', 'آپ تیار ہیں'),
        body: const Bi(
          'Money, customers, offers and the full guide are under More. Replay this tour any time from there.',
          'رقم، کسٹمرز، آفرز اور مکمل رہنما "مزید" میں ہیں۔ یہ ٹور وہیں سے دوبارہ دیکھ سکتے ہیں۔',
        ),
        demo: (c, u) => TourTilesDemo(
          urdu: u,
          tiles: const [
            TourTile(
              Icons.inbox_rounded,
              Bi('Inbox', 'ان باکس'),
              Bi(
                'Customer chats, problems and bulk quotes in one place.',
                'کسٹمر چیٹ، شکایات اور بلک کوٹس ایک جگہ۔',
              ),
            ),
            TourTile(
              Icons.payments_rounded,
              Bi('Money', 'رقم'),
              Bi(
                'Sales, cash with riders and online payments to confirm.',
                'سیل، رائیڈرز کے پاس کیش اور تصدیق طلب آن لائن ادائیگیاں۔',
              ),
            ),
            TourTile(
              Icons.people_rounded,
              Bi('Customers', 'کسٹمرز'),
              Bi(
                'Who orders, how often, and their addresses.',
                'کون آرڈر کرتا ہے، کتنی بار، اور ان کے پتے۔',
              ),
            ),
            TourTile(
              Icons.menu_book_rounded,
              Bi('Guide', 'رہنما'),
              Bi(
                'The full guide in English and Urdu, for you and new staff.',
                'انگریزی اور اردو میں مکمل رہنما، آپ اور نئے عملے کے لیے۔',
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
