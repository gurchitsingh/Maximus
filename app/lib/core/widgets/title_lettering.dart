// Poster and sheet title lettering per topic kind (DESIGN_SPEC 2.4).
// The kind comes from the title payload (`lettering`, CONTRACTS 2.1).
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

enum MxLettering {
  roman,
  brush,
  stencil,
  carved;

  /// Parses the payload value; unknown values fall back to carved (Figtree).
  static MxLettering parse(String? v) => MxLettering.values.firstWhere(
    (e) => e.name == v,
    orElse: () => MxLettering.carved,
  );
}

/// Poster lettering: two centred lines sized from the poster width.
class PosterLettering extends StatelessWidget {
  const PosterLettering({
    super.key,
    required this.lines,
    required this.kind,
    required this.posterWidth,
  });

  final List<String> lines;
  final MxLettering kind;
  final double posterWidth;

  /// Font size from the 2.4 formulas. len = max(len(l1), len(l2), 4).
  static double fontSizeFor(MxLettering kind, List<String> lines, double w) {
    final len = math.max(
      4,
      lines.fold<int>(0, (m, l) => math.max(m, l.length)),
    );
    return switch (kind) {
      MxLettering.roman => math.min(0.115 * w, 0.9 * w / (len * 0.86)),
      MxLettering.brush => math.min(0.21 * w, 0.9 * w / (len * 0.5)),
      MxLettering.stencil => math.min(0.22 * w, 0.9 * w / (len * 0.45)),
      MxLettering.carved => math.min(0.085 * w, 0.9 * w / len),
    };
  }

  static TextStyle styleFor(MxLettering kind, double size) {
    TextStyle s(
      String family,
      FontWeight w,
      Color color,
      double trackingEm,
      List<Shadow> shadows,
    ) => TextStyle(
      fontFamily: family,
      fontWeight: w,
      fontSize: size,
      height: 1.08,
      letterSpacing: trackingEm * size,
      color: color,
      shadows: shadows,
    );
    return switch (kind) {
      MxLettering.roman => s(
        MxFonts.cinzel,
        FontWeight.w700,
        const Color(0xFFF7E6C4),
        0.12,
        const [Shadow(color: Color(0xFF000000), offset: Offset(0, 1))],
      ),
      MxLettering.brush => s(
        MxFonts.caveatBrush,
        FontWeight.w400,
        const Color(0xFFF7F0E0),
        0,
        const [
          Shadow(color: Color(0xB3000000), offset: Offset(0, 2), blurRadius: 4),
        ],
      ),
      MxLettering.stencil => s(
        MxFonts.bigShoulders,
        FontWeight.w900,
        const Color(0xFFECE9CC),
        0.04,
        const [],
      ),
      MxLettering.carved => s(
        MxFonts.figtree,
        FontWeight.w900,
        MxFixed.heroTitle,
        0.26,
        const [Shadow(color: MxFixed.heroShadow, offset: Offset(0, 2))],
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final style = styleFor(kind, fontSizeFor(kind, lines, posterWidth));
    Widget text = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final l in lines)
          if (l.trim().isNotEmpty)
            Text(
              l,
              style: style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling, // artwork, not reading text
            ),
      ],
    );
    if (kind == MxLettering.brush) {
      text = Transform.rotate(angle: -4 * math.pi / 180, child: text);
    }
    return ExcludeSemantics(child: text);
  }
}

/// Title sheet lettering: fixed sizes, colour = text role (2.4).
class SheetLettering extends StatelessWidget {
  const SheetLettering({super.key, required this.lines, required this.kind});

  final List<String> lines;
  final MxLettering kind;

  @override
  Widget build(BuildContext context) {
    final color = context.mx.text;
    final joined = lines.where((l) => l.trim().isNotEmpty).join('\n');
    final style = switch (kind) {
      MxLettering.roman => TextStyle(
        fontFamily: MxFonts.cinzel,
        fontWeight: FontWeight.w700,
        fontSize: 28,
        letterSpacing: 2.8,
        height: 1.05,
      ),
      MxLettering.brush => TextStyle(
        fontFamily: MxFonts.caveatBrush,
        fontSize: 40,
        height: 1.0,
      ),
      MxLettering.stencil => TextStyle(
        fontFamily: MxFonts.bigShoulders,
        fontWeight: FontWeight.w900,
        fontSize: 38,
        letterSpacing: 38 * 0.03,
        height: 1.05,
      ),
      MxLettering.carved => TextStyle(
        fontFamily: MxFonts.figtree,
        fontWeight: FontWeight.w900,
        fontSize: 22,
        letterSpacing: 22 * 0.22,
        height: 1.05,
      ),
    };
    final upper = kind == MxLettering.stencil || kind == MxLettering.carved;
    return Semantics(
      header: true,
      label: lines.join(' '),
      excludeSemantics: true,
      child: Text(
        upper ? joined.toUpperCase() : joined,
        style: style.copyWith(color: color),
      ),
    );
  }
}
