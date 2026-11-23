// Pieces shared by the quiz question and result screens.
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/util/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/title.dart';
import '../../data/providers.dart';

/// Topic header with the subtitle "Quiz" (DESIGN_SPEC 7.9).
class QuizTopBar extends ConsumerWidget {
  const QuizTopBar({super.key, required this.titleId});

  final String titleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(catalogueProvider).value?.title(titleId);
    return MxPushedTopBar(
      kicker: t?.name ?? '',
      kickerColor: t == null
          ? null
          : readableTint(hexColor(t.tint), context.mx.bg),
      title: 'Quiz',
      onBack: () => context.pop(),
    );
  }
}

/// Answer bounce (DESIGN_SPEC 6): the picked option hops up when right and
/// nudges 6 dp sideways when wrong. Reduced motion fades instead.
class AnswerMotion extends StatefulWidget {
  const AnswerMotion({
    super.key,
    required this.state,
    required this.picked,
    required this.child,
  });

  final AnswerState state;

  /// Only the option the user tapped moves.
  final bool picked;
  final Widget child;

  @override
  State<AnswerMotion> createState() => _AnswerMotionState();
}

class _AnswerMotionState extends State<AnswerMotion>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void didUpdateWidget(AnswerMotion old) {
    super.didUpdateWidget(old);
    if (old.state == AnswerState.idle &&
        widget.state != AnswerState.idle &&
        widget.picked) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MxMotion.reduced(context);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        final moving = _c.isAnimating;
        final t = _c.value;
        final offset = !moving || reduced
            ? Offset.zero
            : widget.state == AnswerState.right
            ? Offset(0, -6 * math.sin(math.pi * t))
            : Offset(6 * math.sin(2 * math.pi * t) * (1 - t), 0);
        // One widget shape in every state, so the option keeps its ink.
        return Opacity(
          opacity: moving && reduced ? 0.5 + 0.5 * t : 1,
          child: Transform.translate(offset: offset, child: child),
        );
      },
    );
  }
}

/// Result row (DESIGN_SPEC 9.3.10): tick or cross, the question, and the
/// correct answer at the end for a missed one.
class QuizReviewRow extends StatelessWidget {
  const QuizReviewRow({
    super.key,
    required this.question,
    required this.missed,
  });

  final QuizQuestion question;
  final bool missed;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final answer = question.options[question.correctIndex];
    return Semantics(
      container: true,
      label: missed
          ? 'Missed: ${question.prompt} Answer: $answer'
          : 'Right: ${question.prompt}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(MxRadius.thumb),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MxIcon(
              missed ? MxIcons.x : MxIcons.check,
              size: 20,
              color: missed ? c.error : c.success,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: question.prompt,
                  children: [
                    if (missed)
                      TextSpan(
                        text: ' $answer',
                        style: TextStyle(
                          color: c.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                style: MxText.hint.copyWith(color: c.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
