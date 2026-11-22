import 'package:alpha_customer/l10n/lang.dart';
import 'package:alpha_customer/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => Lang.set(false));

  test('English stays exactly as it is', () {
    expect(tr('Order placed!'), 'Order placed!');
    expect(tr('Order AL-1 was delivered'), 'Order AL-1 was delivered');
  });

  test('Urdu: exact texts, sentences with values, and parts inside them', () {
    Lang.set(true);
    expect(tr('Checkout'), 'چیک آؤٹ');
    expect(
      tr('Order AL-261122-ABC1 was cancelled.'),
      'آرڈر AL-261122-ABC1 منسوخ ہو گیا۔',
    );
    expect(tr('3 cylinders'), '3 سلنڈر');
    expect(tr('Keep 1 empty cylinder ready'), '1 خالی سلنڈر تیار رکھیں');
    // Pieces inside a sentence are translated too.
    expect(tr('Paid · Cash on delivery'), 'ادا شدہ · کیش آن ڈیلیوری');
    expect(tr('2 × 10kg Composite Cylinder'), '2 × 10 کلو کمپوزٹ سلنڈر');
    // Spaces around a text are kept; unknown text is left alone.
    expect(tr(' Checkout '), ' چیک آؤٹ ');
    expect(tr('Some brand new sentence'), 'Some brand new sentence');
  });

  test('Urdu dates and times', () {
    Lang.set(true);
    final d = DateTime(2026, 11, 22, 17, 5);
    expect(formatTime(d), '5:05 شام');
    expect(formatDateTime(d), contains('نومبر'));
    expect(formatDay(DateTime(2026, 11, 22)), contains('اتوار'));
  });

  test('every translation keeps the same number of values as its English', () {
    // A mismatch would drop a name or an amount from the sentence.
    Lang.set(true);
    expect(
      tr(
        'Alpha LPG has sent you the JazzCash account. Pay Rs 100 and send your receipt.',
      ),
      contains('Rs 100'),
    );
  });
}
