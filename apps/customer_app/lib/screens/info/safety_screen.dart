import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/brand.dart';
import '../../utils/launch.dart';
import '../../widgets/common.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  static const _emergency = [
    'Do not switch any lights or appliances on or off.',
    'Turn off the cylinder valve and the stove knobs.',
    'Open all doors and windows to let the gas escape.',
    'No flames, matches or smoking. Do not use your phone near the leak.',
    'Leave the area, then call Rescue 1122 and Alpha LPG.',
  ];

  static const _everyday = [
    'Keep cylinders upright, outdoors or in a well-ventilated place.',
    'Check the regulator and pipe every month — apply soapy water; bubbles mean a leak.',
    'Replace rubber pipes every 2 years or sooner if cracked.',
    'Close the regulator when you are not cooking, especially at night.',
    'Never heat a cylinder or keep it near a stove or heater.',
    'Only accept cylinders with an intact seal from an authorised supplier.',
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().settings;
    return Scaffold(
      appBar: AppBar(title: const Text('LPG safety')),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: const Color(0xFFFFEBE8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Brand.cylinderRed,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'If you smell gas',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final (i, t) in _emergency.indexed)
                      _numbered(i + 1, t),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Brand.cylinderRed,
                            ),
                            onPressed: () => Launch.call('1122'),
                            icon: const Icon(Icons.emergency),
                            label: const Text('Call 1122'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            onPressed: () => Launch.call(s.phone),
                            icon: const Icon(Icons.call),
                            label: const Text('Alpha LPG'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SectionTitle('Everyday safety'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final t in _everyday)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 20,
                              color: Brand.success,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(t)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numbered(int n, String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: Brand.cylinderRed,
          child: Text(
            '$n',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(t)),
      ],
    ),
  );
}
