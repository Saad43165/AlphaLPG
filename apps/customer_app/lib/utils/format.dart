import 'package:intl/intl.dart';

import '../l10n/lang.dart';

export 'package:alpha_core/alpha_core.dart' show formatRupees;

final _dateTime = DateFormat('d MMM, h:mm a');
final _date = DateFormat('EEE d MMM');
final _time = DateFormat('h:mm a');

const _urMonths = [
  'جنوری',
  'فروری',
  'مارچ',
  'اپریل',
  'مئی',
  'جون',
  'جولائی',
  'اگست',
  'ستمبر',
  'اکتوبر',
  'نومبر',
  'دسمبر',
];
const _urDays = ['پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار'];

String _urClock(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final part = d.hour < 12
      ? 'صبح'
      : d.hour < 16
      ? 'دوپہر'
      : d.hour < 20
      ? 'شام'
      : 'رات';
  return '$h:${d.minute.toString().padLeft(2, '0')} $part';
}

String formatDateTime(DateTime d) => Lang.isUrdu
    ? '${d.day} ${_urMonths[d.month - 1]}، ${_urClock(d)}'
    : _dateTime.format(d);
String formatDay(DateTime d) => Lang.isUrdu
    ? '${_urDays[d.weekday - 1]} ${d.day} ${_urMonths[d.month - 1]}'
    : _date.format(d);
String formatTime(DateTime d) => Lang.isUrdu ? _urClock(d) : _time.format(d);

/// Normalises Pakistani mobile input ("0308 5745740", "3085745740",
/// "+92 308 5745740") to E.164 ("+923085745740"). Returns null if invalid.
String? normalizePkMobile(String input) {
  var d = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('0092')) d = d.substring(4);
  if (d.startsWith('92')) d = d.substring(2);
  if (d.startsWith('0')) d = d.substring(1);
  if (d.length != 10 || !d.startsWith('3')) return null;
  return '+92$d';
}

/// "+923085745740" → "0308 5745740"
String prettyPkMobile(String e164) {
  final d = e164.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length == 12 && d.startsWith('92')) {
    return '0${d.substring(2, 5)} ${d.substring(5)}';
  }
  return e164;
}
