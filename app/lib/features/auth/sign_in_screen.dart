// Sign in and Create account (All Pages 1.2, 1.3; prototype `login` and
// `loginUp`). Google first, then email and password (D35). No Apple button
// (Android only). The router moves on once the session starts.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/widgets.dart';
import 'auth_controller.dart';
import 'auth_messages.dart';
import 'auth_redirect.dart';
import 'google_auth.dart';
import 'widgets/auth_widgets.dart';

enum AuthMode { signIn, signUp }

/// Sign-up password length (CONTRACTS 14.1).
const minPasswordLength = 10, maxPasswordLength = 128;

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.mode = AuthMode.signIn});

  final AuthMode mode;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _up => widget.mode == AuthMode.signUp;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _check() {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@') || email.endsWith('@')) {
      return 'Enter your email address.';
    }
    final p = _password.text;
    if (p.isEmpty) return 'Enter your password.';
    if (_up && (p.length < minPasswordLength || p.length > maxPasswordLength)) {
      return 'Use a password of 10 to 128 characters.';
    }
    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    if (_busy) return;
    final problem = _check();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final ctrl = ref.read(authControllerProvider.notifier);
    _run(
      () => _up
          ? ctrl.signUp(_email.text, _password.text, name: _name.text)
          : ctrl.signInWithEmail(_email.text, _password.text),
    );
  }

  void _google() {
    if (_busy) return;
    _run(() async {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final google = ref.watch(googleAuthProvider);
    return AutofillGroup(
      child: AuthPage(
        content: [
          AuthHeading(
            title: _up ? 'Create your account' : 'Welcome back',
            sub: _up
                ? 'Save your study list and pick up where you left off on '
                      'any device.'
                : 'Sign in to pick up where you left off.',
          ),
          GoogleButton(
            available: google.available,
            onPressed: _busy ? null : _google,
          ),
          const OrDivider(),
          if (_up) ...[
            AuthField(
              controller: _name,
              hint: 'Your name',
              keyboardType: TextInputType.name,
              autofillHints: const [AutofillHints.name],
              enabled: !_busy,
            ),
            const SizedBox(height: 12),
          ],
          AuthField(
            controller: _email,
            hint: 'Email',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            enabled: !_busy,
          ),
          const SizedBox(height: 12),
          AuthField(
            controller: _password,
            hint: 'Password',
            obscure: true,
            autofillHints: [
              _up ? AutofillHints.newPassword : AutofillHints.password,
            ],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            enabled: !_busy,
          ),
          if (_up)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'At least 10 characters.',
                style: MxText.sub.copyWith(color: context.mx.textMuted),
              ),
            ),
          if (!_up)
            Align(
              alignment: Alignment.centerLeft,
              // Flush with the fields (design: padding 0).
              child: Transform.translate(
                offset: const Offset(-12, 0),
                child: MxTextButton(
                  label: 'Forgot password?',
                  onPressed: _busy
                      ? null
                      : () => context.push(AuthPaths.forgotPassword),
                ),
              ),
            ),
          if (_error != null) AuthMessage(_error!),
        ],
        footer: [
          BusyPrimaryButton(
            label: _up ? 'Create account' : 'Sign in',
            busy: _busy,
            onPressed: _submit,
          ),
          AuthToggleRow(
            question: _up ? 'Already have an account?' : 'New to Maximus?',
            action: _up ? 'Sign in' : 'Create an account',
            onPressed: _busy
                ? null
                : () => context.go(_up ? AuthPaths.signIn : AuthPaths.signUp),
          ),
        ],
      ),
    );
  }
}
