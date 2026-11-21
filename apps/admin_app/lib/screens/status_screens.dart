import 'package:alpha_ui/alpha_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/common.dart';

/// Signed in, but this account is not listed in the `admins` collection.
class NotAdminScreen extends StatelessWidget {
  const NotAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminSession>();
    final uid = s.uid ?? '';
    return Scaffold(
      body: SafeArea(
        child: Constrained(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              const Center(child: BrandLogo(height: 56)),
              const SizedBox(height: 28),
              Text(
                'This account is not an admin yet',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'To make ${s.backend.auth.email ?? 'this account'} the owner, '
                'open the Firebase console → Firestore Database, create a collection '
                'called "admins", and add one document whose Document ID is the code below '
                '(leave the fields empty). Then sign in again.',
                style: TextStyle(color: context.pal.muted, height: 1.45),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: panel(context),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        uid,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: uid));
                        if (context.mounted) showMessage(context, 'Copied');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: s.signOut,
                child: const Text('Sign out'),
              ),
            ],
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

/// Shown when the app has not been connected to Firebase.
class SetupNeededApp extends StatelessWidget {
  const SetupNeededApp({super.key, this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: Brand.theme(Brightness.light),
    home: const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'Firebase is not connected to this build of the admin app.\n\n'
              'The developer must add this app\'s Firebase settings and rebuild.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5, fontSize: 16),
            ),
          ),
        ),
      ),
    ),
  );
}
