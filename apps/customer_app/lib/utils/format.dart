import 'package:intl/intl.dart';

export 'package:alpha_core/alpha_core.dart' show formatRupees;

final _dateTime = DateFormat('d MMM, h:mm a');
final _date = DateFormat('EEE d MMM');
final _time = DateFormat('h:mm a');

String formatDateTime(DateTime d) => _dateTime.format(d);
String formatDay(DateTime d) => _date.format(d);
String formatTime(DateTime d) => _time.format(d);

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
