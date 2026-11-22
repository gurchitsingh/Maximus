// ThemeData for dark, light and sepia, built only from tokens.
import 'package:material_ui/material_ui.dart';

import 'tokens.dart';
import 'typography.dart';

abstract final class MxTheme {
  static ThemeData build(
    MxThemeVariant variant, {
    MxTextSize textSize = MxTextSize.medium,
  }) {
    final c = MxColors.of(variant);
    final scheme = ColorScheme(
      brightness: variant.brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.accentText,
      onSecondary: c.onAccent,
      error: c.error,
      onError: c.bg,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.textMuted,
      surfaceContainerHighest: c.surfaceRaised,
      outline: c.divider,
      outlineVariant: c.divider,
    );

    // Material roles mapped to the closest App style, for incidental widgets.
    TextStyle t(TextStyle s, [Color? color]) => s.copyWith(color: color ?? c.text);
    final textTheme = TextTheme(
      displayLarge: t(MxText.scoreXL),
      displayMedium: t(MxText.display),
      displaySmall: t(MxText.lessonTitle),
      headlineLarge: t(MxText.onboardTitle),
      headlineMedium: t(MxText.screenTitle),
      headlineSmall: t(MxText.emptyTitle),
      titleLarge: t(MxText.cardTitle),
      titleMedium: t(MxText.rowTitleL),
      titleSmall: t(MxText.rowTitle),
      bodyLarge: t(MxText.bodyL),
      bodyMedium: t(MxText.body),
      bodySmall: t(MxText.sub, c.textMuted),
      labelLarge: t(MxText.buttonM),
      labelMedium: t(MxText.chip),
      labelSmall: t(MxText.caption, c.textMuted),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: variant.brightness,
      colorScheme: scheme,
      fontFamily: MxFonts.figtree,
      textTheme: textTheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      dividerColor: c.divider,
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      iconTheme: IconThemeData(color: c.text, size: 24),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accentText,
        selectionColor: c.accentContainer,
        selectionHandleColor: c.accent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surfaceRaised,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBarrierColor: MxFixed.sheetBackdrop,
        elevation: 0,
        modalElevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MxRadius.option),
          side: BorderSide(color: c.divider),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceRaised,
        contentTextStyle: MxText.body.copyWith(color: c.text),
        behavior: SnackBarBehavior.floating,
      ),
      extensions: [c, MxReading(size: textSize)],
    );
  }
}
