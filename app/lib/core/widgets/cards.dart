// Small shared building blocks: answer option (7.13), settings row (7.20),
// text input (7.19), score tiles (7.15), info card (7.16).
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'mx_icon.dart';
import 'section_header.dart';

enum AnswerState { idle, right, wrong }

/// Quiz / guess-the-year option. Never colour alone: icon + word (1.4).
class AnswerOption extends StatelessWidget {
  const AnswerOption({
    super.key,
    required this.label,
    this.state = AnswerState.idle,
    this.wrongWord = 'Not quite',
    this.onPressed,
  });

  final String label;
  final AnswerState state;

  /// "Not quite" (quiz) or "Not this one" (guess the year).
  final String wrongWord;

  /// Null after answering: further taps are ignored, but the option keeps
  /// full opacity (unlike a disabled button).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final (
      Color bg,
      Color border,
      Color? fg,
      MxIcons? icon,
      String? word,
    ) = switch (state) {
      AnswerState.idle => (c.surface, c.divider, null, null, null),
      AnswerState.right => (
        c.successContainer,
        c.success,
        c.success,
        MxIcons.check,
        'Right',
      ),
      AnswerState.wrong => (
        c.errorContainer,
        c.error,
        c.error,
        MxIcons.x,
        wrongWord,
      ),
    };
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(MxRadius.option),
      side: BorderSide(color: border, width: 2),
    );
    return Semantics(
      button: true,
      label: word == null ? label : '$label, $word',
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: shape,
          overlayColor: WidgetStatePropertyAll(c.text.withValues(alpha: 0.08)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: MxText.option.copyWith(color: c.text),
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 12),
                    MxIcon(icon, size: 20, color: fg),
                    const SizedBox(width: 6),
                    Text(word!, style: MxText.feedback.copyWith(color: fg)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Explanation box shown after answering.
class ExplanationBox extends StatelessWidget {
  const ExplanationBox(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(MxRadius.tile),
      ),
      child: Text(text, style: MxText.body.copyWith(color: c.text)),
    );
  }
}

/// Settings list row: min h60, top divider, label left, value or arrow right.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.value,
    this.showArrow = false,
    this.destructive = false,
    this.isLast = false,
    this.onTap,
  });

  final String label;
  final String? value;
  final bool showArrow;

  /// "Clear my data": label in error colour, 800 16; value as a 13 hint.
  final bool destructive;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final side = BorderSide(color: c.divider);
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        overlayColor: WidgetStatePropertyAll(c.text.withValues(alpha: 0.08)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          decoration: BoxDecoration(
            border: Border(top: side, bottom: isLast ? side : BorderSide.none),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: destructive
                      ? MxText.rowTitle.copyWith(color: c.error, height: 1.0)
                      : MxText.listRow.copyWith(color: c.text),
                ),
              ),
              if (value != null)
                Flexible(
                  child: Text(
                    value!,
                    textAlign: TextAlign.right,
                    style: destructive
                        ? MxText.sub.copyWith(color: c.textMuted)
                        : MxText.listValue.copyWith(color: c.textMuted),
                  ),
                ),
              if (showArrow)
                MxIcon(MxIcons.arrowRight, size: 20, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text input: h56, radius 16, 2 dp divider; focus ring accent (11.14).
class MxTextField extends StatelessWidget {
  const MxTextField({
    super.key,
    this.controller,
    this.hint,
    this.enabled = true,
    this.radius = MxRadius.tile,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? hint;
  final bool enabled;

  /// 16 for forms; 26 for the chat composer (h52 pill).
  final double radius;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    OutlineInputBorder b(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: color, width: 2),
    );
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: TextField(
        controller: controller,
        enabled: enabled,
        onSubmitted: onSubmitted,
        style: MxText.input.copyWith(color: c.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: MxText.input.copyWith(color: c.textMuted),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          enabledBorder: b(c.divider),
          disabledBorder: b(c.divider),
          focusedBorder: b(c.accent),
          errorBorder: b(c.error),
          focusedErrorBorder: b(c.error),
        ),
      ),
    );
  }
}

/// Home quiz score tile: "5/6" in success colour + topic name.
class ScoreTile extends StatelessWidget {
  const ScoreTile({super.key, required this.score, required this.topic});

  final String score;
  final String topic;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(MxRadius.option),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            score,
            style: MxText.scoreXL.copyWith(fontSize: 28, color: c.success),
          ),
          const SizedBox(height: 4),
          Text(topic, style: MxText.sub.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}

/// Empty scores: 2 dp dashed divider border, question icon 32 + copy.
class EmptyScores extends StatelessWidget {
  const EmptyScores({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return CustomPaint(
      painter: _DashedBorder(color: c.divider, radius: MxRadius.option),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            MxIcon(MxIcons.quiz, size: 32, color: c.textMuted),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'No quizzes yet. Finish a topic and your scores land here.',
                style: MxText.body.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: c.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(1),
      );
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

/// Info card (On this day): kicker, title, muted body.
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.kicker,
    required this.title,
    required this.body,
  });

  final String kicker;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(MxRadius.resume),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(kicker),
          const SizedBox(height: 10),
          Text(title, style: MxText.otdTitle.copyWith(color: c.text)),
          const SizedBox(height: 6),
          Text(body, style: MxText.body.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}
