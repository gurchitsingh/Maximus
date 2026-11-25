// Sign in and Create account (All Pages 1.2, 1.3; prototype `login` and
// `loginUp`). Google first, then email and password (D35). No Apple button
// (Android only). No email verification (D48): sign-up signs the user in at
// once and the router moves on. The confirm-password check is app-only.
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

/// Shown for every failed email sign-in (D48): never says which half was
/// wrong.
const wrongCredentials = 'Wrong email or password';

const passwordsDontMatch = "Passwords don't match";

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String email) => _emailPattern.hasMatch(email.trim());

bool passwordRulesPass(String p) =>
    p.length >= minPasswordLength && p.length <= maxPasswordLength;

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.mode = AuthMode.signIn});

  final AuthMode mode;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _confirmFocus = FocusNode();
  bool _busy = false;
  bool _confirmLeft = false;
  String? _error;

  bool get _up => widget.mode == AuthMode.signUp;

  @override
  void initState() {
    super.initState();
    _confirmFocus.addListener(() {
      if (!_confirmFocus.hasFocus && !_confirmLeft) {
        setState(() => _confirmLeft = true);
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  bool get _matches => _password.text == _confirm.text;

  /// "Passwords don't match" shows once the confirm field has lost focus,
  /// or both fields are filled.
  bool get _showMismatch =>
      _up &&
      !_matches &&
      (_confirmLeft || (_password.text.isNotEmpty && _confirm.text.isNotEmpty));

  bool get _canSubmit =>
      !_up ||
      (isValidEmail(_email.text) &&
          passwordRulesPass(_password.text) &&
          _matches);

  Future<void> _run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = _up ? authErrorMessage(e) : signInErrorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    if (_busy || !_canSubmit) return;
    if (!_up && (_email.text.trim().isEmpty || _password.text.isEmpty)) {
      setState(() => _error = wrongCredentials);
      return;
    }
    final ctrl = ref.read(authControllerProvider.notifier);
    _run(
      () => _up
          ? ctrl.signUp(_email.text, _password.text)
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
          AuthField(
            controller: _email,
            hint: 'Email',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => setState(() {}),
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
            textInputAction: _up ? TextInputAction.next : TextInputAction.done,
            onSubmitted: _up ? null : (_) => _submit(),
            onChanged: (_) => setState(() {}),
            enabled: !_busy,
          ),
          if (_up) ...[
            const SizedBox(height: 12),
            AuthField(
              controller: _confirm,
              focusNode: _confirmFocus,
              hint: 'Confirm password',
              obscure: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => setState(() {}),
              enabled: !_busy,
            ),
            if (_showMismatch) const AuthMessage(passwordsDontMatch),
            _PasswordRules(_password.text),
          ],
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
            onPressed: _canSubmit ? _submit : null,
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

/// The password rules, ticked off as the user types.
class _PasswordRules extends StatelessWidget {
  const _PasswordRules(this.password);

  final String password;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final ok = passwordRulesPass(password);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        label: ok
            ? 'Password rule met: $minPasswordLength to $maxPasswordLength '
                  'characters'
            : 'Password rule: $minPasswordLength to $maxPasswordLength '
                  'characters',
        excludeSemantics: true,
        child: Row(
          children: [
            MxIcon(
              ok ? MxIcons.check : MxIcons.x,
              size: 16,
              color: ok ? c.success : c.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              '$minPasswordLength to $maxPasswordLength characters',
              style: MxText.sub.copyWith(color: ok ? c.success : c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
