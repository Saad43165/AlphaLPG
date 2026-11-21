import 'package:material_ui/material_ui.dart';

import '../theme/brand.dart';
import '../widgets/common.dart';

/// Shown by production builds when Firebase has not been connected.
class NotConfiguredApp extends StatelessWidget {
  const NotConfiguredApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: Brand.theme(Brightness.light),
    home: const Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Alpha LPG is not connected yet',
          message: 'This build has not been linked to the Alpha LPG database. Please install the latest version or contact the shop.',
        ),
      ),
    ),
  );
}
