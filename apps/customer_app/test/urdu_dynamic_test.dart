import 'package:alpha_customer/l10n/lang.dart';
import 'package:flutter_test/flutter_test.dart';

/// Texts the app builds at run time must still come out in Urdu.
void main() {
  test('dynamic sentences and counts are translated', () {
    Lang.set(true);
    addTearDown(() => Lang.set(false));
    final arabic = RegExp(r'[؀-ۿ]');
    for (final s in [
      '1 item',
      '3 items',
      '2 cylinders',
      '1 cylinder',
      '2 accessories',
      '1 accessory',
      '2 cylinders + 1 accessory',
      '3 items in your cart',
      '1 cylinder in your cart',
      'Order summary · 5 items',
      'Order summary · 2 cylinders',
      'Keep 2 empty cylinders ready',
      'Keep 1 empty cylinder ready',
      '4.8 · 12 ratings',
      '3 stars',
      'Delivery is Rs. 150, and free on orders over Rs. 6,000.',
      'Delivery is Rs. 150.',
      'Refill price: please keep 2 empty cylinders of the same size ready. Our rider will swap them for full ones.',
      'Only 3 left',
      'Accessory',
      'Stoves & accessories',
      'What do you need?',
    ]) {
      final u = Lang.translate(s);
      expect(arabic.hasMatch(u), isTrue, reason: '"$s" stayed English: $u');
    }
    expect(Lang.translate('3 items in your cart'), contains('3'));
  });
}
