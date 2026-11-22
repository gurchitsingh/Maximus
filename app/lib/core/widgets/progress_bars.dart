// Progress bars (DESIGN_SPEC 7.7).
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Thin bar h6 r3 (rows, resume card). [quiz] = h8 r4 accent fill.
class MxProgressBar extends StatelessWidget {
  const MxProgressBar({
    super.key,
    required this.value,
    this.fill,
    this.track,
    this.quiz = false,
  });

  /// 0..1.
  final double value;

  /// Defaults to accent. Topic rows pass the topic tint.
  final Color? fill;

  /// Defaults to surfaceRaised. On artwork pass MxFixed.artTrack.
  final Color? track;
  final bool quiz;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final h = quiz ? 8.0 : 6.0;
    final r = BorderRadius.circular(quiz ? MxRadius.quizBar : MxRadius.bar);
    return Semantics(
      value: '${(value.clamp(0, 1) * 100).round()}%',
      child: Container(
        height: h,
        decoration: BoxDecoration(color: track ?? c.surfaceRaised, borderRadius: r),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0, 1).toDouble(),
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(color: fill ?? c.accent, borderRadius: r),
          ),
        ),
      ),
    );
  }
}

/// Onboarding step bar: [count] equal segments, gap 6, filled up to [current].
class StepBar extends StatelessWidget {
  const StepBar({super.key, required this.current, this.count = 4});

  /// 1-based step.
  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Semantics(
      label: 'Step $current of $count',
      child: Row(
        children: [
          for (var i = 1; i <= count; i++) ...[
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: i <= current ? c.accent : c.surfaceRaised,
                  borderRadius: BorderRadius.circular(MxRadius.bar),
                ),
              ),
            ),
            if (i < count) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

/// Reader lesson bar: one segment per lesson. Done = tint, current = half
/// tint (hard stop), future = surfaceRaised.
class LessonSegments extends StatelessWidget {
  const LessonSegments({
    super.key,
    required this.count,
    required this.current,
    required this.tint,
  });

  final int count;

  /// 1-based current lesson.
  final int current;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final track = context.mx.surfaceRaised;
    return Semantics(
      label: 'Lesson $current of $count',
      child: Row(
        children: [
          for (var i = 1; i <= count; i++) ...[
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MxRadius.bar),
                  color: i < current ? tint : (i > current ? track : null),
                  gradient: i == current
                      ? LinearGradient(
                          colors: [tint, tint, track, track],
                          stops: const [0, 0.5, 0.5, 1],
                        )
                      : null,
                ),
              ),
            ),
            if (i < count) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
