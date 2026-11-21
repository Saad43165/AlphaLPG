import 'package:alpha_ui/alpha_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../services/demo.dart';
import '../services/rider_auth.dart';
import '../state/session.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(text: kDemo ? demoEmail : '');
  final _password = TextEditingController(text: kDemo ? 'demo1234' : '');
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<RiderSession>().backend.auth.signIn(
        _email.text,
        _password.text,
      );
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(
        () => _error =
            'Enter your email above first, then tap "Forgot password".',
      );
      return;
    }
    try {
      await context.read<RiderSession>().backend.auth.sendPasswordReset(email);
      if (mounted) showMessage(context, 'Password reset email sent to $email');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      body: SafeArea(
        child: Constrained(
          maxWidth: 440,
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/brand/rider_banner.jpg',
                    fit: BoxFit.cover,
                    semanticLabel: 'Alpha LPG Rider',
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Sign in',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Use the email and password Alpha LPG gave you.',
                  style: TextStyle(color: pal.muted),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: (v) =>
                      (v ?? '').contains('@') ? null : 'Enter your email',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _hide,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _signIn(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _hide ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _hide
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                  validator: (v) =>
                      (v ?? '').isEmpty ? 'Enter your password' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Brand.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _busy ? null : _signIn,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign in'),
                ),
                TextButton(
                  onPressed: _busy ? null : _forgot,
                  child: const Text('Forgot password'),
                ),
                const SizedBox(height: 24),
                Text(
                  'No account? Riders are added by Alpha LPG. Call the shop to get yours.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: pal.muted, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
