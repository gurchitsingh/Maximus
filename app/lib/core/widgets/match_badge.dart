// Match % badge (DESIGN_SPEC 7.3) with the 700 ms count-up (6).
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

class MatchBadge extends StatelessWidget {
  const MatchBadge({
    super.key,
    required this.percent,
    this.posterWidth = 128,
    this.compact = false,
  });

  /// 40..99 per CONTRACTS 6. The caller hides the badge before any signal.
  final int percent;

  /// Badge height and font scale with the poster width.
  final double posterWidth;

  /// "96%" (first matches) instead of "96% match" (rows).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final h = math.max(24.0, 0.14 * posterWidth);
    final font = math.max(12.0, 0.08 * posterWidth);
    final reduced = MxMotion.reduced(context);
    String label(int v) => compact ? '$v%' : '$v% match';

    return Semantics(
      label: '$percent% match',
      excludeSemantics: true,
      child: Container(
        height: h,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: MxFixed.badgeBg,
          borderRadius: BorderRadius.circular(h / 2),
        ),
        // Center with widthFactor 1 hugs the text; Container.alignment would
        // stretch the badge to the full width when the parent is bounded.
        child: Center(
          widthFactor: 1,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percent.toDouble()),
            duration: reduced ? Duration.zero : MxMotion.matchCountUp,
            curve: Curves.easeOut,
            builder: (context, v, _) => Text(
              label(v.round()),
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: MxText.buttonS.copyWith(
                fontSize: font,
                color: MxFixed.accentBright,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
