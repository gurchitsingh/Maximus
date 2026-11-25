// Forgot password (not drawn; DESIGN_SPEC 15.6, CONTRACTS 19): an email
// field, then "Check your email". The reset itself happens on the web page
// the email links to. The server answers the same whether or not the
// email has an account, and so does this screen.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import 'auth_controller.dart';
import 'auth_messages.dart';
import 'auth_redirect.dart';
import 'widgets/auth_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _back() =>
      context.canPop() ? context.pop() : context.go(AuthPaths.signIn);

  Future<void> _send() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your email address.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).forgotPassword(email);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = SizedBox(
      height: MxSpace.topBarHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Transform.translate(
          offset: const Offset(-12, 0),
          child: MxIconButton(
            icon: MxIcons.chevronLeft,
            label: 'Back to sign in',
            onPressed: _back,
          ),
        ),
      ),
    );
    if (_sent) {
      return AuthPage(
        top: top,
        content: [
          AuthHeading(
            title: 'Check your email',
            sub:
                'If there is an account for ${_email.text.trim()}, a link to '
                'set a new password is on its way. It works for one hour.',
          ),
        ],
        footer: [PrimaryButton(label: 'Back to sign in', onPressed: _back)],
      );
    }
    return AuthPage(
      top: top,
      content: [
        const AuthHeading(
          title: 'Reset your password',
          sub:
              'Enter the email you sign in with. We will send a link to set '
              'a new password.',
        ),
        AuthField(
          controller: _email,
          hint: 'Email',
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _send(),
          enabled: !_busy,
        ),
        if (_error != null) AuthMessage(_error!),
      ],
      footer: [
        BusyPrimaryButton(
          label: 'Send the link',
          busy: _busy,
          onPressed: _send,
        ),
      ],
    );
  }
}
