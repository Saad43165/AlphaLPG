import 'package:flutter/services.dart';

import '../../l10n/lang.dart';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Text;

import '../../l10n/text.dart';

import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/backend.dart';
import '../../state/app_state.dart';
import '../../theme/brand.dart';
import '../../utils/format.dart';
import '../../utils/nav.dart';
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

  bool _left = false;

  // Kept as a field: `context` cannot be read while the screen is closing.
  late final AuthService _auth;

  @override
  void initState() {
    super.initState();
    _auth = context.read<Backend>().auth;
    _auth.addListener(_onAuthChanged);
  }

  /// Leaves the login screen once signed in, *replacing* it so the screens
  /// underneath (cart, home…) stay and Back keeps working.
  void _onAuthChanged() {
    if (!_auth.isSignedIn || _left) return;
    _left = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = widget.from ?? '/';
      final path = Uri.parse(target).path;
      if (const ['/', '/orders', '/account'].contains(path)) {
        context.go(target);
      } else {
        context.pushReplacement(target);
      }
    });
  }

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

  /// No SMS: take the number and sign in straight away.
  Future<void> _quick() async {
    final e164 = normalizePkMobile(_phone.text);
    if (e164 == null) {
      setState(() => _error = 'Enter a valid mobile number, e.g. 0308 5745740');
      return;
    }
    await _run(() => _auth.signInQuick(e164));
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
    _auth.removeListener(_onAuthChanged);
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quick = !context.select<AppState, bool>((s) => s.settings.smsLogin);
    final codeStep = _sentTo != null && !quick;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.backOrHome(),
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
              codeStep
                  ? 'Enter verification code'
                  : (quick ? 'Your mobile number' : 'Sign in with your mobile'),
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              codeStep
                  ? 'We sent a 6-digit code by SMS to ${prettyPkMobile(_sentTo!)}.'
                  : (quick
                        ? 'Our rider calls this number about your delivery. No password and no SMS code.'
                        : 'We will text you a one-time code. No password needed.'),
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
                decoration: InputDecoration(
                  labelText: tr('Mobile number'),
                  hintText: tr('0308 5745740'),
                  prefixIcon: Icon(Icons.phone_iphone),
                ),
                onSubmitted: (_) => quick ? _quick() : _sendCode(),
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
                decoration: InputDecoration(counterText: tr('')),
                onSubmitted: (_) => _verify(),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFB3261E))),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy
                  ? null
                  : (codeStep ? _verify : (quick ? _quick : _sendCode)),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(
                      codeStep
                          ? 'Verify & continue'
                          : (quick ? 'Continue' : 'Send code'),
                    ),
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
            if (quick) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alpha LPG may call to confirm your order. Your orders are saved on this phone.',
                      style: TextStyle(
                        color: context.pal.muted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
