// Type styles from DESIGN_SPEC 2.3 (App values win over the Foundations scale).
// Styles carry no colour: widgets apply colour roles from MxColors.
import 'package:material_ui/material_ui.dart';

abstract final class MxFonts {
  static const figtree = 'Figtree';
  static const cinzel = 'Cinzel';
  static const caveatBrush = 'Caveat Brush';
  static const bigShoulders = 'Big Shoulders Stencil Display';
}

TextStyle _f(
  double size,
  FontWeight weight,
  double height, {
  double trackingEm = 0,
}) => TextStyle(
  fontFamily: MxFonts.figtree,
  fontSize: size,
  fontWeight: weight,
  height: height,
  letterSpacing: trackingEm * size,
  leadingDistribution: TextLeadingDistribution.even,
);

/// Named Figtree styles. Names follow the "Token suggestion" column of 2.3.
abstract final class MxText {
  static final scoreXL = _f(56, FontWeight.w900, 1.0);
  static final heroTitle = _f(40, FontWeight.w900, 0.95, trackingEm: 0.06);
  static final display = _f(34, FontWeight.w900, 1.05, trackingEm: -0.01);
  static final lessonTitle = _f(30, FontWeight.w900, 1.08);
  static final onboardTitle = _f(28, FontWeight.w900, 1.1);
  static final screenTitle = _f(26, FontWeight.w900, 1.0, trackingEm: -0.01);
  static final question = _f(26, FontWeight.w900, 1.15);
  static final emptyTitle = _f(24, FontWeight.w900, 1.15);
  static final cardTitle = _f(22, FontWeight.w900, 1.15);
  static final feedFact = _f(22, FontWeight.w800, 1.28);
  static final otdTitle = _f(20, FontWeight.w900, 1.2);
  static final readerHeading = _f(20, FontWeight.w800, 1.2);
  static final section = _f(19, FontWeight.w800, 1.0);
  static final factCard = _f(19, FontWeight.w800, 1.3);
  static final option = _f(18, FontWeight.w800, 1.25);
  static final groupTitle = _f(18, FontWeight.w800, 1.0);
  static final feedbackHead = _f(18, FontWeight.w900, 1.2);
  static final buttonL = _f(17, FontWeight.w800, 1.0);
  static final rowTitleL = _f(17, FontWeight.w800, 1.2);
  static final buttonM = _f(16, FontWeight.w800, 1.0);
  static final rowTitle = _f(16, FontWeight.w800, 1.2);
  static final listRow = _f(16, FontWeight.w700, 1.0);
  static final bodyL = _f(16, FontWeight.w500, 1.45);
  static final input = _f(16, FontWeight.w500, 1.0);
  static final segment = _f(15, FontWeight.w800, 1.0);
  static final body = _f(15, FontWeight.w500, 1.45);
  static final chatUser = _f(15, FontWeight.w500, 1.4);
  static final chatAi = _f(15, FontWeight.w500, 1.45);
  static final skip = _f(15, FontWeight.w700, 1.0);
  static final listValue = _f(15, FontWeight.w600, 1.0);
  static final buttonS = _f(14, FontWeight.w800, 1.0);
  static final chip = _f(14, FontWeight.w700, 1.0);
  static final hint = _f(14, FontWeight.w600, 1.3);
  static final labelCaps = _f(13, FontWeight.w800, 1.0, trackingEm: 0.12);
  static final meta = _f(13, FontWeight.w700, 1.0);
  static final sub = _f(13, FontWeight.w600, 1.3);
  static final feedback = _f(13, FontWeight.w800, 1.0);
  static final kicker = _f(12, FontWeight.w800, 1.0, trackingEm: 0.12);
  static final tileLabel = _f(12, FontWeight.w800, 1.15);
  static final caption = _f(12, FontWeight.w600, 1.3);
  static final navLabel = _f(12, FontWeight.w600, 1.0);
  static final navLabelActive = _f(12, FontWeight.w800, 1.0);
  static final tag = _f(12, FontWeight.w700, 1.0);
}

/// Reader text size setting (DESIGN_SPEC 2.3). The setting itself is built in
/// S9; S4 provides the hook (ThemeSettings.textSize → MxReading).
enum MxTextSize {
  small('Small', 16),
  medium('Medium', 18),
  large('Large', 20);

  const MxTextSize(this.label, this.readerSize);
  final String label;
  final double readerSize;
}

/// Reader paragraph style that follows the text size setting.
@immutable
class MxReading extends ThemeExtension<MxReading> {
  const MxReading({required this.size});

  final MxTextSize size;

  /// 500 weight, line height 1.6; paragraphs have a 10 dp bottom margin.
  TextStyle get paragraph => _f(size.readerSize, FontWeight.w500, 1.6);
  static const double paragraphGap = 10;

  @override
  MxReading copyWith({MxTextSize? size}) => MxReading(size: size ?? this.size);

  @override
  MxReading lerp(MxReading? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}
