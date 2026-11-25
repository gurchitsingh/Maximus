// Pieces shared by the sign-in screens (DESIGN_SPEC 15.1, App `login`):
// 72 dp logo row, 34/900 title, muted sub, 56 dp fields with a 2 dp
// divider border, inline error line.
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';

/// Scrollable page with the design's 0 24 20 padding. [footer] sits at the
/// bottom when the content is short, and scrolls with it when it is not.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.content,
    this.footer = const [],
    this.top,
  });

  final List<Widget> content;
  final List<Widget> footer;

  /// Replaces the logo row (Forgot password has a back bar instead).
  final Widget? top;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mx.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    top ??
                        const SizedBox(
                          height: 72,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _AccentLogo(),
                          ),
                        ),
                    ...content,
                    const Spacer(),
                    const SizedBox(height: 16),
                    ...footer,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentLogo extends StatelessWidget {
  const _AccentLogo();

  @override
  Widget build(BuildContext context) =>
      MxLogo(size: 40, color: context.mx.accent);
}

/// "Welcome back" / "Create your account" and the line under it.
class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key, required this.title, required this.sub});

  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(title, style: MxText.display.copyWith(color: c.text)),
        ),
        const SizedBox(height: 8),
        Text(sub, style: MxText.bodyL.copyWith(color: c.textMuted)),
        const SizedBox(height: 22),
      ],
    );
  }
}

/// 7.19 text input with what sign-in needs on top of MxTextField: hidden
/// text, keyboard type, autofill and a label for screen readers.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    OutlineInputBorder b(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(MxRadius.tile),
      borderSide: BorderSide(color: color, width: 2),
    );
    return SizedBox(
      height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        enabled: enabled,
        obscureText: obscure,
        enableSuggestions: !obscure,
        autocorrect: false,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        inputFormatters: [LengthLimitingTextInputFormatter(320)],
        style: MxText.input.copyWith(color: c.text),
        cursorColor: c.accent,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: MxText.input.copyWith(color: c.textMuted),
          // The hint is the label (design); keep it for TalkBack once typed.
          semanticCounterText: '',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          enabledBorder: b(c.divider),
          disabledBorder: b(c.divider),
          focusedBorder: b(c.accent),
        ),
      ),
    );
  }
}

/// "Continue with Google": 56 dp outline. Disabled with a note when the
/// build has no GOOGLE_CLIENT_ID.
class GoogleButton extends StatelessWidget {
  const GoogleButton({
    super.key,
    required this.available,
    required this.onPressed,
  });

  final bool available;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SecondaryButton(
          label: 'Continue with Google',
          height: 56,
          onPressed: available ? onPressed : null,
        ),
        if (!available) ...[
          const SizedBox(height: 8),
          Text(
            'Google sign-in is not set up in this build. Use email for now.',
            textAlign: TextAlign.center,
            style: MxText.sub.copyWith(color: c.textMuted),
          ),
        ],
      ],
    );
  }
}

/// The "or with email" rule.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    Widget line() => Expanded(child: Container(height: 1, color: c.divider));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          line(),
          const SizedBox(width: 12),
          Text(
            'or with email',
            style: MxText.meta.copyWith(color: c.textMuted),
          ),
          const SizedBox(width: 12),
          line(),
        ],
      ),
    );
  }
}

/// An error (or, with [ok], a confirmation) line, announced to TalkBack.
class AuthMessage extends StatelessWidget {
  const AuthMessage(this.text, {super.key, this.ok = false});

  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MxIcon(
              ok ? MxIcons.check : MxIcons.x,
              size: 18,
              color: ok ? c.success : c.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: MxText.hint.copyWith(color: ok ? c.success : c.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Primary button that shows a spinner and ignores taps while [busy].
class BusyPrimaryButton extends StatelessWidget {
  const BusyPrimaryButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (!busy) return PrimaryButton(label: label, onPressed: onPressed);
    final c = context.mx;
    return Semantics(
      label: '$label, working',
      child: Container(
        height: 56,
        decoration: ShapeDecoration(
          color: c.accent,
          shape: const StadiumBorder(),
        ),
        alignment: Alignment.center,
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: c.onAccent),
        ),
      ),
    );
  }
}

/// "New to Maximus? Create an account" and its sign-up twin.
class AuthToggleRow extends StatelessWidget {
  const AuthToggleRow({
    super.key,
    required this.question,
    required this.action,
    required this.onPressed,
  });

  final String question;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            question,
            style: MxText.body.copyWith(color: c.textMuted, height: 1),
          ),
          MxTextButton(
            label: action,
            style: MxTextButtonStyle.toggleLink,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}
