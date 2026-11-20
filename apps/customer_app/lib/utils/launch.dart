import 'package:url_launcher/url_launcher.dart';

abstract final class Launch {
  static Future<bool> call(String phone) =>
      launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));

  /// [number] in international format without "+", e.g. 923085745740.
  static Future<bool> whatsapp(String number, [String message = '']) =>
      launchUrl(
        Uri.https('wa.me', '/$number', {
          if (message.isNotEmpty) 'text': message,
        }),
        mode: LaunchMode.externalApplication,
      );

  static Future<bool> email(String to, {String subject = ''}) => launchUrl(
    Uri(
      scheme: 'mailto',
      path: to,
      query: subject.isEmpty ? null : 'subject=${Uri.encodeComponent(subject)}',
    ),
  );

  static Future<bool> maps({String? query, double? lat, double? lng}) =>
      launchUrl(
        Uri.https('www.google.com', '/maps/search/', {
          'api': '1',
          'query': lat != null && lng != null ? '$lat,$lng' : query ?? '',
        }),
        mode: LaunchMode.externalApplication,
      );
}
