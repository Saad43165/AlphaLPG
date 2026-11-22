import 'package:alpha_core/alpha_core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

LpgOrder order(
  String uid, {
  int total = 6592,
  String coupon = '',
  int cd = 0,
  int pts = 0,
}) => LpgOrder(
  customerId: uid,
  customerName: 'Ali',
  customerPhone: '+923001234567',
  items: const [
    OrderItem(
      productId: 'cyl-11-8kg',
      name: '11.8kg Gas Cylinder',
      sizeKg: 11.8,
      type: PurchaseType.refill,
      unitPrice: 3296,
      quantity: 2,
    ),
  ],
  subtotal: 6592,
  deliveryFee: 0,
  total: total,
  address: const Address(label: 'Home', line1: '12-B', area: 'Gulberg'),
  couponCode: coupon,
  couponDiscount: cd,
  pointsUsed: pts,
  pointsDiscount: pts,
);

void main() {
  group('coupon maths', () {
    test('rupees off, percent with a cap, minimum order, expiry', () {
      const amount = Coupon(code: 'A', value: 200);
      expect(amount.discountFor(3000), 200);
      expect(amount.discountFor(100), 100, reason: 'never more than the order');
      const pct = Coupon(code: 'P', percent: true, value: 10, maxDiscount: 300);
      expect(pct.discountFor(1000), 100);
      expect(pct.discountFor(6592), 300, reason: 'capped');
      const min = Coupon(code: 'M', value: 100, minOrder: 5000);
      expect(min.discountFor(4000), 0);
      expect(min.problem(4000), contains('at least'));
      final old = Coupon(code: 'O', value: 100, expiresAt: DateTime(2020));
      expect(old.problem(5000), 'This code has expired.');
      expect(
        const Coupon(code: 'X', value: 5, active: false).problem(5000),
        isNotNull,
      );
      expect(Coupon.clean(' welcome 200 '), 'WELCOME200');
    });
    test('points: balance, shop percentage and the code come first', () {
      const s = AppSettings(maxPointsPercent: 30, pointValue: 1);
      expect(PriceBreakdown.maxPoints(6592, 0, 5000, s), 1977);
      expect(PriceBreakdown.maxPoints(6592, 0, 500, s), 500);
      expect(
        PriceBreakdown.maxPoints(1000, 900, 5000, s),
        100,
        reason: 'cannot go below the price left after a code',
      );
      expect(PriceBreakdown.maxPoints(1000, 0, 0, s), 0);
    });
    test('totals include discounts and never go below zero', () {
      final base = PriceBreakdown(
        subtotal: 3296,
        deliveryFee: 150,
        cylinders: 1,
      );
      final p = base.withDiscounts(
        couponDiscount: 200,
        pointsUsed: 100,
        pointValue: 1,
      );
      expect(p.total, 3146);
      expect(p.discount, 300);
    });
    test('an invite code is stable, readable and looks like a code', () {
      final a = referralCodeFor('uid-abc');
      expect(a, referralCodeFor('uid-abc'));
      expect(a, matches(RegExp(r'^REF-[A-Z2-9]{6}$')));
      expect(a, isNot(referralCodeFor('uid-abd')));
    });
  });

  for (final name in ['firestore', 'memory']) {
    group('promo repository ($name)', () {
      late PromoRepository promo;
      late OrderRepository orders;
      setUp(() {
        if (name == 'firestore') {
          final db = FakeFirebaseFirestore();
          promo = PromoRepository.firestore(db);
          orders = OrderRepository.firestore(db);
        } else {
          final s = MemoryStore();
          promo = PromoRepository.memory(s);
          orders = OrderRepository.memory(s);
        }
      });

      test(
        'a coupon is found by its code, and spent once per customer',
        () async {
          await promo.saveCoupon(const Coupon(code: 'WELCOME', value: 200));
          expect((await promo.findCoupon('WELCOME'))!.value, 200);
          expect(await promo.findCoupon('NOPE'), isNull);
          expect(await promo.alreadyUsed('WELCOME', 'u1'), isFalse);
          await orders.place(
            order('u1', total: 6392, coupon: 'WELCOME', cd: 200),
          );
          expect(await promo.alreadyUsed('WELCOME', 'u1'), isTrue);
          expect(await promo.alreadyUsed('WELCOME', 'u2'), isFalse);
        },
      );

      test('cancelling an order gives its code back', () async {
        await promo.saveCoupon(const Coupon(code: 'WELCOME', value: 200));
        final id = await orders.place(
          order('u1', total: 6392, coupon: 'WELCOME', cd: 200),
        );
        final o = (await orders.watchOrder(id).first)!;
        await orders.cancelByCustomer(o, 'Changed my mind');
        expect(await promo.alreadyUsed('WELCOME', 'u1'), isFalse);
      });

      test('invite codes belong to one customer and are used once', () async {
        final code = await promo.myReferralCode('u2');
        expect(code, referralCodeFor('u2'));
        expect(await promo.referralOwner(code), 'u2');
        expect(await promo.referralOwner('REF-ZZZZZZ'), isNull);
        await orders.place(order('u1', total: 6392, coupon: code, cd: 200));
        expect(await promo.alreadyUsed(code, 'u1'), isTrue);
      });

      test(
        'points: awarded once, spent once, given back after a cancel',
        () async {
          final id = await orders.place(order('u1', total: 5992, pts: 600));
          var o = (await orders.watchOrder(id).first)!;
          await promo.awardDelivery(
            o,
            points: 130,
            referrerUid: 'u9',
            referrerPoints: 200,
          );
          await promo.awardDelivery(
            o,
            points: 130,
            referrerUid: 'u9',
            referrerPoints: 200,
          );
          expect(
            (await promo.watchLoyalty('u1').first).points,
            130,
            reason: 'only once',
          );
          expect((await promo.watchLoyalty('u9').first).points, 200);
          expect((await promo.watchLoyaltyEntries('u1').first), hasLength(1));

          o = (await orders.watchOrder(id).first)!;
          await promo.settleSpent(o);
          await promo.settleSpent(o);
          var l = await promo.watchLoyalty('u1').first;
          expect(l.points, 0, reason: 'cannot go below zero');
          expect(l.lifetime, 130);

          await orders.cancelByCustomer(o, 'x');
          o = (await orders.watchOrder(id).first)!;
          await promo.refundSpent(o);
          await promo.refundSpent(o);
          l = await promo.watchLoyalty('u1').first;
          expect(l.points, 600);
          expect(l.lifetime, 130, reason: 'a refund is not new earnings');
        },
      );

      test('public stats and refill plans', () async {
        await promo.publishStats(
          const PublicStats(
            ratingAverage: 4.8,
            ratingCount: 20,
            deliveredCount: 300,
          ),
        );
        final s = await promo.watchStats().first;
        expect(s.ratingAverage, 4.8);
        expect(s.showable, isTrue);
        expect(
          const PublicStats(ratingAverage: 5, ratingCount: 2).showable,
          isFalse,
        );

        expect(await promo.watchPlan('u1').first, isNull);
        await promo.savePlan(
          'u1',
          RefillPlan(
            lines: const [
              {'productId': 'cyl-11-8kg', 'type': 'refill', 'quantity': 2},
            ],
            everyDays: 30,
            nextDue: DateTime.now().subtract(const Duration(days: 1)),
          ),
        );
        final p = (await promo.watchPlan('u1').first)!;
        expect(p.cylinders, 2);
        expect(p.isDue(), isTrue);
        expect(p.copyWith(active: false).isDue(), isFalse);
        await promo.deletePlan('u1');
        expect(await promo.watchPlan('u1').first, isNull);
      });
    });
  }

  test('the order keeps its discount fields', () {
    final o = order('u1', total: 6292, coupon: 'WELCOME', cd: 200, pts: 100);
    final back = LpgOrder.fromMap('x', o.toMap());
    expect(back.couponCode, 'WELCOME');
    expect(back.discount, 300);
    expect(
      order('u1').toMap().containsKey('couponCode'),
      isFalse,
      reason: 'no discount fields when none was used',
    );
  });

  for (final name in ['firestore', 'memory']) {
    test(
      'archiving removes old receipt and delivery photos only ($name)',
      () async {
        late OrderRepository orders;
        if (name == 'firestore') {
          orders = OrderRepository.firestore(FakeFirebaseFirestore());
        } else {
          orders = OrderRepository.memory(MemoryStore());
        }
        final id = await orders.place(order('u1'));
        await orders.addReceipt(id, uid: 'u1', data: 'x' * 200);
        await orders.updateStatus(id, OrderStatus.delivered, 'admin');
        // Nothing is removed from a fresh order, or before the cut-off.
        expect(
          await orders.archiveOldPhotos(
            DateTime.now().subtract(const Duration(days: 90)),
          ),
          0,
        );
        expect((await orders.watchReceipts(id).first), hasLength(1));
        // Once the order is older than the cut-off, the picture goes; the order stays.
        expect(
          await orders.archiveOldPhotos(
            DateTime.now().add(const Duration(days: 1)),
          ),
          1,
        );
        expect((await orders.watchReceipts(id).first), isEmpty);
        expect((await orders.watchOrder(id).first)!.total, 6592);
      },
    );
  }
}
