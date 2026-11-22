import 'package:material_ui/material_ui.dart';

/// The WhatsApp logo, for every WhatsApp button and link.
class WhatsAppIcon extends StatelessWidget {
  const WhatsAppIcon({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/whatsapp.png',
    package: 'alpha_ui',
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    // Never a blank spot if the picture is missing.
    errorBuilder: (_, _, _) =>
        Icon(Icons.chat_rounded, size: size, color: const Color(0xFF25D366)),
  );
}
