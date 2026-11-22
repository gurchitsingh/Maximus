// Design tokens from docs/DESIGN_SPEC.md sections 1 to 6.
// Tokens live only in lib/core/theme/ (CONTRACTS 8.1). Per-title colours
// (bg, tint) are content data and never appear here.
import 'package:material_ui/material_ui.dart';

/// The three app themes. Dark is the default (DESIGN_SPEC 1).
/// Sepia is an S4 addition derived from light (owner decision, 2026-11-22).
enum MxThemeVariant {
  dark('Dark'),
  light('Light'),
  sepia('Sepia');

  const MxThemeVariant(this.label);
  final String label;

  Brightness get brightness =>
      this == MxThemeVariant.dark ? Brightness.dark : Brightness.light;
}

/// Theme colour roles (DESIGN_SPEC 1.1). Read with `context.mx`.
@immutable
class MxColors extends ThemeExtension<MxColors> {
  const MxColors({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.accentText,
    required this.accentContainer,
    required this.onAccent,
    required this.success,
    required this.successContainer,
    required this.error,
    required this.errorContainer,
    required this.divider,
  });

  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color text;
  final Color textMuted;

  /// Accent as a fill (primary buttons, selected segments, user bubble).
  final Color accent;

  /// Accent as text or stroke (links, active nav, kickers, outline buttons).
  final Color accentText;

  /// Active nav pill background.
  final Color accentContainer;
  final Color onAccent;
  final Color success;
  final Color successContainer;
  final Color error;
  final Color errorContainer;
  final Color divider;

  static const dark = MxColors(
    bg: Color(0xFF0F0D0A),
    surface: Color(0xFF1A1611),
    surfaceRaised: Color(0xFF262017),
    text: Color(0xFFF4EDE0),
    textMuted: Color(0xFFB5A998),
    accent: Color(0xFFC8933A),
    accentText: Color(0xFFC8933A),
    accentContainer: Color(0x38C8933A), // rgba(200,147,58,0.22)
    onAccent: Color(0xFF1A1208),
    success: Color(0xFF6FCF8E),
    successContainer: Color(0x246FCF8E), // 0.14
    error: Color(0xFFFF8A7A),
    errorContainer: Color(0x24FF8A7A), // 0.14
    divider: Color(0x1FF4EDE0), // 12% of text
  );

  static const light = MxColors(
    bg: Color(0xFFF7F1E6),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFEFE6D6),
    text: Color(0xFF1C1710),
    textMuted: Color(0xFF5E5445),
    accent: Color(0xFFC8933A),
    accentText: Color(0xFF8A5A0C),
    accentContainer: Color(0x40C8933A), // 0.25
    onAccent: Color(0xFF1A1208),
    success: Color(0xFF1F7A45),
    successContainer: Color(0x1F1F7A45), // 0.12
    error: Color(0xFFB3392B),
    errorContainer: Color(0x1AB3392B), // 0.10
    divider: Color(0x241C1710), // 14% of text
  );

  /// Not in the design bundle. Same roles as light on a warmer, darker paper.
  /// Every text role keeps at least 4.5:1 on bg (see test/core/theme).
  static const sepia = MxColors(
    bg: Color(0xFFF1E4C9),
    surface: Color(0xFFF8EEDB),
    surfaceRaised: Color(0xFFE6D5B5),
    text: Color(0xFF2B2116),
    textMuted: Color(0xFF63523D),
    accent: Color(0xFFC8933A),
    accentText: Color(0xFF7E520B),
    accentContainer: Color(0x40C8933A),
    onAccent: Color(0xFF1A1208),
    success: Color(0xFF1D6B3E),
    successContainer: Color(0x1F1D6B3E),
    error: Color(0xFFA33427),
    errorContainer: Color(0x1AA33427),
    divider: Color(0x292B2116), // 16% of text
  );

  static MxColors of(MxThemeVariant v) => switch (v) {
    MxThemeVariant.dark => dark,
    MxThemeVariant.light => light,
    MxThemeVariant.sepia => sepia,
  };

  @override
  MxColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceRaised,
    Color? text,
    Color? textMuted,
    Color? accent,
    Color? accentText,
    Color? accentContainer,
    Color? onAccent,
    Color? success,
    Color? successContainer,
    Color? error,
    Color? errorContainer,
    Color? divider,
  }) {
    return MxColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentText: accentText ?? this.accentText,
      accentContainer: accentContainer ?? this.accentContainer,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      error: error ?? this.error,
      errorContainer: errorContainer ?? this.errorContainer,
      divider: divider ?? this.divider,
    );
  }

  @override
  MxColors lerp(MxColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return MxColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      accent: l(accent, other.accent),
      accentText: l(accentText, other.accentText),
      accentContainer: l(accentContainer, other.accentContainer),
      onAccent: l(onAccent, other.onAccent),
      success: l(success, other.success),
      successContainer: l(successContainer, other.successContainer),
      error: l(error, other.error),
      errorContainer: l(errorContainer, other.errorContainer),
      divider: l(divider, other.divider),
    );
  }
}

/// Colours that are the same in every theme (DESIGN_SPEC 1.2).
abstract final class MxFixed {
  static const scrim = Color(0xFF0A0805); // rgba(10,8,5,α); α per component
  static const textOnArt = Color(0xFFF4EDE0);
  static const celebrationBody = Color(0xFFE3D9C6);
  static const badgeBg = Color(0xE60F0D0A); // rgba(15,13,10,0.9)
  static const accentBright = Color(0xFFE7B25A); // 11.18: on-image accent text
  static const feedActionBg = Color(0x9E0F0D0A); // 0.62
  static const topicTagBg = Color(0xCC0F0D0A); // 0.8
  static const sheetBackdrop = Color(0x9E000000); // 0.62
  static const celebrationBackdrop = Color(0xC70A0805); // 0.78
  static const ring = Color(0xFFC8933A);
  static const inkOnTint = Color(0xFF1A1208); // 11.17: one ink for all tint buttons
  static const splashBg = Color(0xFF0F0D0A);
  static const heroTitle = Color(0xFFFBE2AE);
  static const heroShadow = Color(0xFF1E0D05);
  static const artTrack = Color(0x40F4EDE0); // 0.25
  static const artOutline = Color(0x4DF4EDE0); // 0.3, "Not now"
  static const dragHandleOnArt = Color(0xB3F4EDE0); // 0.7
  static const confetti = [
    Color(0xFFE8553A),
    Color(0xFFC8933A),
    Color(0xFFF2C14E),
    Color(0xFF6C8CFF),
    Color(0xFF6FCF8E),
  ];

  /// Scrim with alpha [a] (0..1).
  static Color scrimA(double a) => scrim.withValues(alpha: a);
}

/// Spacing (DESIGN_SPEC 3). Scale plus the off-scale values the App uses.
abstract final class MxSpace {
  static const double s2 = 2, s4 = 4, s6 = 6, s8 = 8, s10 = 10, s12 = 12;
  static const double s14 = 14, s16 = 16, s18 = 18, s20 = 20, s22 = 22;
  static const double s24 = 24, s28 = 28, s32 = 32, s36 = 36, s48 = 48;

  static const double gutter = 20;
  static const double sectionGap = 22;
  static const double headingToContent = 12;
  static const double posterRowGap = 12;
  static const double topBarHeight = 64;
  static const double navBarHeight = 68;
  static const double minTouch = 48;
}

/// Radii (DESIGN_SPEC 4).
abstract final class MxRadius {
  static const double bar = 3; // 6 tall progress bars
  static const double quizBar = 4;
  static const double thumb = 14;
  static const double navPill = 15;
  static const double tile = 16;
  static const double option = 18;
  static const double card = 20;
  static const double resume = 22;
  static const double emptyArt = 24;
  static const double sheet = 28;

  /// Poster corner: max(10, 0.075·w).
  static double poster(double w) => w * 0.075 < 10 ? 10 : w * 0.075;
}

/// Elevation (DESIGN_SPEC 5). Depth comes from surface steps; only two shadows.
abstract final class MxElevation {
  static const l1 = [
    BoxShadow(color: Color(0x73000000), offset: Offset(0, 2), blurRadius: 8),
  ];
  static const l2 = [
    BoxShadow(color: Color(0x99000000), offset: Offset(0, 12), blurRadius: 32),
  ];
}

/// Motion (DESIGN_SPEC 6). Reduced motion swaps movement for a fade.
abstract final class MxMotion {
  static const splash = Duration(milliseconds: 1500);
  static const addedPop = Duration(milliseconds: 220);
  static const matchCountUp = Duration(milliseconds: 700);
  static const tilePop = Duration(milliseconds: 180);
  static const ratingSelect = Duration(milliseconds: 180);
  static const celebration = Duration(milliseconds: 1600);
  static const fade = Duration(milliseconds: 150);

  static const double tilePopScale = 1.04;
  static const double ratingScale = 1.08;
  static const double addedPopScale = 1.08;
  static const Curve standard = Curves.easeOut;

  /// True when the user asked the OS to reduce motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

extension MxThemeContext on BuildContext {
  /// Theme colour roles for the nearest theme.
  MxColors get mx => Theme.of(this).extension<MxColors>()!;
}
