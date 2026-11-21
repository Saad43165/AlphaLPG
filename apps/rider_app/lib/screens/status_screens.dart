import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/common.dart';

/// Signed in, but not (or no longer) a rider.
class NotRiderScreen extends StatelessWidget {
  const NotRiderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RiderSession>();
    final blocked = s.profile != null && !s.profile!.active;
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: blocked ? Icons.block_rounded : Icons.badge_outlined,
          title: blocked
              ? 'Your rider account is switched off'
              : 'This account is not set up as a rider',
          message: blocked
              ? 'Please contact Alpha LPG to get it switched back on.'
              : '${s.backend.auth.email ?? 'This account'} has not been added as a rider yet. Ask Alpha LPG to add it.',
          action: OutlinedButton(
            onPressed: s.signOut,
            child: const Text('Sign out'),
          ),
        ),
      ),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// Shown when the app has not been connected to Firebase yet.
class SetupNeededApp extends StatelessWidget {
  const SetupNeededApp({super.key, this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: Brand.theme(Brightness.light),
    home: Scaffold(
      body: SafeArea(
        child: Constrained(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 20),
              const Center(child: BrandLogo(height: 56)),
              const SizedBox(height: 28),
              Text(
                'Firebase is not set up yet',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              const Text(
                'This app has no demo mode: it only works with the real Alpha LPG database. '
                'The developer needs to connect it once:',
                style: TextStyle(height: 1.45),
              ),
              const SizedBox(height: 16),
              for (final (i, t) in const [
                'Create the Firebase project and turn on Email/Password sign-in and Firestore.',
                'Run `flutterfire configure` in apps/rider_app.',
                'Deploy firebase/firestore.rules.',
                'Add riders (see README → "Adding a rider").',
              ].indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Brand.navy,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(t, style: const TextStyle(height: 1.35)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
