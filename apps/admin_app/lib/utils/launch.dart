import 'package:url_launcher/url_launcher.dart';

abstract final class Launch {
  static Future<bool> call(String phone) =>
      launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));

  /// [number] in international form without "+", e.g. 923001234567.
  static Future<bool> whatsapp(String number, [String message = '']) =>
      launchUrl(
        Uri.https('wa.me', '/$number', {
          if (message.isNotEmpty) 'text': message,
        }),
        mode: LaunchMode.externalApplication,
      );

  /// Turn-by-turn navigation in Google Maps (free, no map key needed).
  static Future<bool> navigate({double? lat, double? lng, String? address}) {
    final dest = lat != null && lng != null ? '$lat,$lng' : (address ?? '');
    return launchUrl(
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': dest,
        'travelmode': 'driving',
      }),
      mode: LaunchMode.externalApplication,
    );
  }
}

/// "+923001234567" → "923001234567" (for wa.me); null if not a PK mobile.
String? whatsappNumber(String phone) {
  var d = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('0092')) d = d.substring(2);
  if (d.startsWith('0')) d = '92${d.substring(1)}';
  return d.startsWith('92') && d.length == 12 ? d : null;
}

String prettyPhone(String phone) {
  final d = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length == 12 && d.startsWith('92')) {
    return '0${d.substring(2, 5)} ${d.substring(5)}';
  }
  return phone;
}

String timeAgo(DateTime? t, [DateTime? now]) {
  if (t == null) {
    return '';
  }
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inSeconds < 60) {
    return 'just now';
  }
  if (d.inMinutes < 60) {
    return '${d.inMinutes} min ago';
  }
  if (d.inHours < 24) {
    return '${d.inHours} h ago';
  }
  return '${d.inDays} d ago';
}
