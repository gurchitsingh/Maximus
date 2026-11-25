// Verify email (not drawn; built from the sign-in pieces, DESIGN_SPEC 15.6).
// Shown once after an email sign-up. Nothing is blocked while unverified
// (CONTRACTS 14.5): Continue goes on, and Settings keeps a Resend banner.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/widgets.dart';
import 'auth_controller.dart';
import 'auth_messages.dart';
import 'widgets/auth_widgets.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _busy = false;
  String? _message;
  bool _ok = false;

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).resendVerification();
      if (mounted) {
        setState(() {
          _ok = true;
          _message = 'Sent. Check your inbox, and the spam folder too.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ok = false;
          _message = authErrorMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserProvider)?.email;
    return AuthPage(
      content: [
        AuthHeading(
          title: 'Check your email',
          sub:
              'We sent a link to ${email ?? 'your email address'}. Open it '
              'to confirm your address. You can use Maximus while you wait.',
        ),
        if (_message != null) AuthMessage(_message!, ok: _ok),
      ],
      footer: [
        PrimaryButton(
          label: 'Continue',
          onPressed: _busy
              ? null
              : ref.read(authControllerProvider.notifier).finishVerifyStep,
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: _busy ? 'Sending...' : 'Send the email again',
          onPressed: _busy ? null : _resend,
        ),
      ],
    );
  }
}
