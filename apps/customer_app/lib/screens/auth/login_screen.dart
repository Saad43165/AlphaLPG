import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../config/env.dart';
import '../../services/auth_service.dart';
import '../../services/backend.dart';
import '../../theme/brand.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Two steps on one screen: mobile number, then the 6-digit SMS code.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.from});
  final String? from;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _sentTo;
  String? _error;
  bool _busy = false;

  AuthService get _auth => context.read<Backend>().auth;

  Future<void> _sendCode() async {
    final e164 = normalizePkMobile(_phone.text);
    if (e164 == null) {
      setState(() => _error = 'Enter a valid mobile number, e.g. 0308 5745740');
      return;
    }
    await _run(() async {
      final signedIn = await _auth.sendCode(e164);
      if (!signedIn) setState(() => _sentTo = e164);
    });
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    await _run(() => _auth.verifyCode(_code.text.trim()));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = context.read<Backend>().isDemo;
    final codeStep = _sentTo != null;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: Constrained(
        maxWidth: 460,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Center(child: BrandLogo(height: 72)),
            const SizedBox(height: 32),
            Text(
              codeStep ? 'Enter verification code' : 'Sign in with your mobile',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              codeStep
                  ? 'We sent a 6-digit code by SMS to ${prettyPkMobile(_sentTo!)}.'
                  : 'We will text you a one-time code. No password needed.',
            ),
            const SizedBox(height: 24),
            if (!codeStep)
              TextField(
                controller: _phone,
                autofocus: true,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  hintText: '0308 5745740',
                  prefixIcon: Icon(Icons.phone_iphone),
                ),
                onSubmitted: (_) => _sendCode(),
              )
            else
              TextField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 24, letterSpacing: 10),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(counterText: ''),
                onSubmitted: (_) => _verify(),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFB3261E))),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : (codeStep ? _verify : _sendCode),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(codeStep ? 'Verify & continue' : 'Send code'),
            ),
            if (codeStep)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _sentTo = null;
                        _code.clear();
                      }),
                child: const Text('Change number / resend code'),
              ),
            if (isDemo) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Brand.flame.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Demo mode: use any mobile number and code ${Env.demoOtp}.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
