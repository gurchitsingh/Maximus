// Poster card, 2:3 (DESIGN_SPEC 7.3). With no art (poster_image_id null,
// CONTRACTS 2.1) it draws a tinted gradient poster with lettering (12.4).
import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'buttons.dart';
import 'match_badge.dart';
import 'title_lettering.dart';

/// What a poster shows. Mirrors the title summary fields it needs.
@immutable
class PosterData {
  const PosterData({
    required this.lines,
    required this.lettering,
    required this.bg,
    required this.tint,
    this.imageUrl,
  });

  final List<String> lines;
  final MxLettering lettering;
  final Color bg;
  final Color tint;

  /// Resolved poster image URL, or null for the gradient fallback.
  final String? imageUrl;

  String get semanticLabel => lines.where((l) => l.trim().isNotEmpty).join(' ');
}

class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.data,
    this.width = 128,
    this.matchPercent,
    this.compactBadge = false,
    this.onTap,
  });

  final PosterData data;

  /// 128 Home "For you", 126 Library rows, 170 first matches, 112 alt.
  final double width;
  final int? matchPercent;
  final bool compactBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final w = width;
    final radius = BorderRadius.circular(MxRadius.poster(w));
    final card = SizedBox(
      width: w,
      height: w * 1.5,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PosterArt(data: data),
            // Bottom scrim with the title lettering.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  0.04 * w,
                  0.26 * w,
                  0.04 * w,
                  0.07 * w,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      MxFixed.scrimA(0.9),
                      MxFixed.scrimA(0.9),
                      MxFixed.scrimA(0),
                    ],
                    stops: const [0, 0.22, 1],
                  ),
                ),
                child: PosterLettering(
                  lines: data.lines,
                  kind: data.lettering,
                  posterWidth: w,
                ),
              ),
            ),
            if (matchPercent != null)
              Positioned(
                top: 8,
                left: 8,
                child: MatchBadge(
                  percent: matchPercent!,
                  posterWidth: w,
                  compact: compactBadge,
                ),
              ),
          ],
        ),
      ),
    );

    final label = matchPercent == null
        ? data.semanticLabel
        : '${data.semanticLabel}, $matchPercent% match';
    // Display-only posters must not take the disabled (0.4 opacity) path.
    if (onTap == null) {
      return Semantics(
        image: true,
        label: label,
        excludeSemantics: true,
        child: card,
      );
    }
    return MxPressable(
      onPressed: onTap,
      borderRadius: radius,
      semanticLabel: label,
      overlay: const Color(0x24000000),
      child: card,
    );
  }
}

/// Poster background: network art when present, else the tinted gradient.
/// Also used for the error fallback of a failed image load.
class PosterArt extends StatelessWidget {
  const PosterArt({super.key, required this.data});

  final PosterData data;

  @override
  Widget build(BuildContext context) {
    final fallback = TintedGradient(bg: data.bg, tint: data.tint);
    final url = data.imageUrl;
    if (url == null) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter, // xMidYMin slice
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
      fadeInDuration: MxMotion.fade,
    );
  }
}

/// Flat-art stand-in: topic bg with a soft tint "light source" near the top
/// (the focal circle in the 10.2 art brief) and a deeper base.
class TintedGradient extends StatelessWidget {
  const TintedGradient({super.key, required this.bg, required this.tint});

  final Color bg;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(bg, tint, 0.28)!,
            bg,
            Color.lerp(bg, Colors.black, 0.35)!,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.42),
            radius: 0.62,
            colors: [
              tint.withValues(alpha: 0.75),
              tint.withValues(alpha: 0.22),
              tint.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
      ),
    );
  }
}
