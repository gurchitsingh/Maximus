// Reader pieces: read-aloud bar (DESIGN_SPEC 7.22) and the finish
// celebration overlay with confetti (7.21, motion 6).
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'buttons.dart';
import 'mx_icon.dart';

/// Pinned under the lesson, above the topic bar. Playing shows pause (11.14).
class ReadAloudBar extends StatelessWidget {
  const ReadAloudBar({
    super.key,
    required this.playing,
    required this.meta,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    this.isLast = false,
  });

  final bool playing;

  /// "About 3 min · 1x speed".
  final String meta;
  final VoidCallback? onPlayPause;

  /// Null on the first lesson.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// The next button finishes the topic on the last lesson.
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          CircleIconButton(
            icon: playing ? MxIcons.pause : MxIcons.play,
            label: playing ? 'Pause reading' : 'Listen to this lesson',
            onPressed: onPlayPause,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playing ? 'Reading aloud' : 'Listen to this lesson',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MxText.chip.copyWith(height: 1.2, color: c.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MxText.caption.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
          ),
          MxIconButton(
            icon: MxIcons.chevronLeft,
            size: 22,
            label: 'Previous lesson',
            onPressed: onPrevious,
          ),
          MxIconButton(
            icon: MxIcons.chevronRight,
            size: 22,
            label: isLast ? 'Finish lesson' : 'Next lesson',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

/// Shows the celebration over everything. Resolves true for "Take the quiz".
Future<bool?> showCelebration({
  required BuildContext context,
  required String title,
  required String body,
  required Color tint,
  required bool offerQuiz,
}) {
  final reduced = MxMotion.reduced(context);
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: MxFixed.celebrationBackdrop,
    transitionDuration: reduced ? Duration.zero : MxMotion.fade,
    pageBuilder: (ctx, _, _) => CelebrationOverlay(
      title: title,
      body: body,
      tint: tint,
      offerQuiz: offerQuiz,
      onQuiz: () => Navigator.of(ctx).pop(true),
      onDismiss: () => Navigator.of(ctx).pop(false),
    ),
    transitionBuilder: (_, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  );
}

class CelebrationOverlay extends StatelessWidget {
  const CelebrationOverlay({
    super.key,
    required this.title,
    required this.body,
    required this.tint,
    required this.offerQuiz,
    required this.onQuiz,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final Color tint;
  final bool offerQuiz;
  final VoidCallback onQuiz;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The 0.78 backdrop alone lets lesson text show through the copy;
          // a light blur keeps the spec colour and makes it readable.
          IgnorePointer(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: const SizedBox.expand(),
            ),
          ),
          if (!MxMotion.reduced(context))
            IgnorePointer(child: Confetti(extra: tint)),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: MxText.display.copyWith(
                          color: MxFixed.textOnArt,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: MxText.bodyL.copyWith(
                        color: MxFixed.celebrationBody,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (offerQuiz) ...[
                      TintButton(
                        label: 'Take the quiz',
                        tint: tint,
                        icon: null,
                        onPressed: onQuiz,
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: MxPressable(
                        onPressed: onDismiss,
                        border: const BorderSide(
                          color: MxFixed.artOutline,
                          width: 2,
                        ),
                        overlay: MxFixed.textOnArt.withValues(alpha: 0.08),
                        child: Center(
                          child: Text(
                            offerQuiz ? 'Not now' : 'Done',
                            style: MxText.buttonM.copyWith(
                              color: MxFixed.textOnArt,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 36 pieces in bronze and poster tints drifting down for 1.6 s, then gone.
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.extra, this.seed = 7});

  /// The topic tint, mixed in with the fixed confetti colours.
  final Color? extra;
  final int seed;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: MxMotion.celebration,
  )..forward();

  late final List<_Piece> _pieces = () {
    final r = math.Random(widget.seed);
    final colors = [...MxFixed.confetti, ?widget.extra];
    return List.generate(
      36,
      (i) => _Piece(
        x: r.nextDouble(),
        delay: r.nextDouble() * 0.25,
        drift: (r.nextDouble() - 0.5) * 0.18,
        spin: (r.nextDouble() - 0.5) * 8,
        w: 6 + r.nextDouble() * 6,
        h: 10 + r.nextDouble() * 8,
        color: colors[i % colors.length],
      ),
    );
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => _c.isCompleted
          ? const SizedBox.expand()
          : CustomPaint(
              size: Size.infinite,
              painter: _ConfettiPainter(_pieces, _c.value),
            ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.drift,
    required this.spin,
    required this.w,
    required this.h,
    required this.color,
  });
  final double x, delay, drift, spin, w, h;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local == 0) continue;
      final y = -20 + Curves.easeIn.transform(local) * (size.height * 0.9);
      final x = (p.x + p.drift * local) * size.width;
      // Fade out over the last fifth.
      final alpha = local > 0.8 ? (1 - local) / 0.2 : 1.0;
      paint.color = p.color.withValues(alpha: alpha);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.spin * local)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h),
            const Radius.circular(2),
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
