// Settings > Account (CONTRACTS 14.5, 17, 19): the signed-in email, the
// verify banner, Sign out, Delete my account and links to the privacy
// policy and the account-deletion web page. Not drawn in the export: built
// from the list rows and the Clear my data dialog (DESIGN_SPEC 15.1).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/widgets.dart';
import '../../data/api/api_client.dart' show apiBaseUrl;
import '../../data/api/api_error.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_messages.dart';
import '../auth/auth_models.dart';
import '../auth/widgets/auth_widgets.dart';

/// Where the privacy policy and the account-deletion page live (the API
/// server renders them, CONTRACTS 17). `--dart-define=APP_BASE_URL=...`.
const appBaseUrl = String.fromEnvironment(
  'APP_BASE_URL',
  defaultValue: apiBaseUrl,
);

Uri privacyPolicyUri() => Uri.parse('$appBaseUrl/privacy');
Uri accountDeletionUri() => Uri.parse('$appBaseUrl/account/delete');

/// GET /v1/me when Settings opens: email_verified and the sign-in methods.
/// Offline it fails quietly and the stored email stays.
final accountRefreshProvider = FutureProvider.autoDispose<AuthUser?>(
  (ref) => ref.read(authControllerProvider.notifier).refreshUser(),
);

class AccountSection extends ConsumerStatefulWidget {
  const AccountSection({super.key});

  @override
  ConsumerState<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<AccountSection> {
  bool _bannerHidden = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(accountRefreshProvider);
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Account'),
          const SizedBox(height: 10),
          if (user.emailVerified == false && !_bannerHidden) ...[
            VerifyBanner(
              email: user.email,
              onDismiss: () => setState(() => _bannerHidden = true),
            ),
            const SizedBox(height: 12),
          ],
          SettingsRow(
            label: 'Email',
            value: user.email ?? user.displayName ?? 'Signed in',
          ),
          SettingsRow(
            label: 'Sign out',
            showArrow: true,
            onTap: () => signOutFlow(context, ref),
          ),
          SettingsRow(
            label: 'Delete my account',
            destructive: true,
            onTap: () => showDeleteAccountDialog(context),
          ),
          SettingsRow(
            label: 'Privacy policy',
            showArrow: true,
            onTap: () => _open(privacyPolicyUri()),
          ),
          SettingsRow(
            label: 'Delete account on the web',
            showArrow: true,
            isLast: true,
            onTap: () => _open(accountDeletionUri()),
          ),
        ],
      ),
    );
  }

  Future<void> _open(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${uri.toString()}')),
      );
    }
  }
}

/// "Confirm your email" with Resend (14.5). Dismissible; nothing is blocked
/// while unverified.
class VerifyBanner extends ConsumerStatefulWidget {
  const VerifyBanner({super.key, required this.email, required this.onDismiss});

  final String? email;
  final VoidCallback onDismiss;

  @override
  ConsumerState<VerifyBanner> createState() => _VerifyBannerState();
}

class _VerifyBannerState extends ConsumerState<VerifyBanner> {
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
          _message = 'Sent. Check your inbox.';
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
    final c = context.mx;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(MxRadius.tile),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Confirm your email',
                  style: MxText.rowTitle.copyWith(color: c.text),
                ),
                const SizedBox(height: 4),
                Text(
                  'Open the link we sent to '
                  '${widget.email ?? 'your email address'}.',
                  style: MxText.sub.copyWith(color: c.textMuted),
                ),
                Transform.translate(
                  offset: const Offset(-12, 0),
                  child: MxTextButton(
                    label: _busy ? 'Sending...' : 'Resend',
                    onPressed: _busy ? null : _resend,
                  ),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: AuthMessage(_message!, ok: _ok),
                  ),
              ],
            ),
          ),
          MxIconButton(
            icon: MxIcons.x,
            label: 'Hide',
            size: 20,
            onPressed: widget.onDismiss,
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String keep,
  required String go,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: MxFixed.sheetBackdrop,
    builder: (ctx) => _MxDialog(
      title: title,
      children: [
        Text(body, style: MxText.body.copyWith(color: ctx.mx.textMuted)),
        const SizedBox(height: 20),
        SecondaryButton(
          label: keep,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: PrimaryButton(
            label: go,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Confirms, then signs out (14.5). The router goes to Welcome.
Future<bool> signOutFlow(BuildContext context, WidgetRef ref) async {
  final ok = await _confirm(
    context,
    title: 'Sign out?',
    body:
        'Your study list, ratings, progress and quiz scores are removed '
        'from this phone. Lessons you have opened stay saved so the app '
        'still works offline.',
    keep: 'Stay signed in',
    go: 'Sign out',
  );
  if (!ok) return false;
  await ref.read(authControllerProvider.notifier).signOut();
  return true;
}

Future<void> showDeleteAccountDialog(BuildContext context) => showDialog<void>(
  context: context,
  barrierColor: MxFixed.sheetBackdrop,
  builder: (_) => const DeleteAccountDialog(),
);

/// Delete my account (17): states what is removed, asks email accounts for
/// their password, then DELETE /v1/me. On success the session ends, local
/// data and tokens are wiped, and the router goes to Welcome.
class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  ConsumerState<DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  bool _loadingUser = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // has_password is unknown after an offline cold start: ask /v1/me.
    if (ref.read(currentUserProvider)?.hasPassword == null) {
      _loadingUser = true;
      ref
          .read(authControllerProvider.notifier)
          .refreshUser()
          .then<void>(
            (_) {},
            onError: (Object e) {
              if (mounted) setState(() => _error = authErrorMessage(e));
            },
          )
          .whenComplete(() {
            if (mounted) setState(() => _loadingUser = false);
          });
    }
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  bool get _needsPassword =>
      ref.read(currentUserProvider)?.hasPassword ?? false;

  Future<void> _delete() async {
    final password = _needsPassword ? _password.text : null;
    if (password != null && password.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .deleteAccount(password: password);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e is ApiException && e.code == 'invalid_credentials'
            ? 'Wrong password. Try again.'
            : authErrorMessage(e),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final user = ref.watch(currentUserProvider);
    final needsPassword = user?.hasPassword ?? false;
    final ready = !_loadingUser && user?.hasPassword != null;
    return _MxDialog(
      title: 'Delete your account?',
      children: [
        Text(
          'This deletes your account and everything saved to it: study '
          'list, ratings, progress, quiz scores, feed saves, settings and '
          'chat history, on the server and on this phone. It cannot be '
          'undone.',
          style: MxText.body.copyWith(color: c.textMuted),
        ),
        if (needsPassword) ...[
          const SizedBox(height: 16),
          AuthField(
            controller: _password,
            hint: 'Password',
            obscure: true,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _delete(),
            enabled: !_busy,
          ),
        ],
        if (_error != null) AuthMessage(_error!),
        const SizedBox(height: 20),
        SecondaryButton(
          label: 'Keep my account',
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: MxPressable(
            onPressed: _busy || !ready ? null : _delete,
            fill: c.error,
            child: Center(
              child: _busy
                  ? SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: c.onAccent,
                      ),
                    )
                  : Text(
                      'Delete my account',
                      style: MxText.buttonL.copyWith(color: c.onAccent),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The Clear my data dialog frame (surface, sheet radius, divider edge).
class _MxDialog extends StatelessWidget {
  const _MxDialog({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Dialog(
      backgroundColor: c.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MxRadius.sheet),
        side: BorderSide(color: c.divider),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: MxText.emptyTitle.copyWith(color: c.text)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}
