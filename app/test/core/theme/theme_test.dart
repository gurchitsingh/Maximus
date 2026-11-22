import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:maximus/core/theme/app_theme.dart';
import 'package:maximus/core/theme/tokens.dart';
import 'package:maximus/core/theme/typography.dart';

double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

/// WCAG contrast ratio of two opaque colours.
double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('design tokens (DESIGN_SPEC 1.1)', () {
    test('dark matches the spec', () {
      const c = MxColors.dark;
      expect(c.bg, const Color(0xFF0F0D0A));
      expect(c.surface, const Color(0xFF1A1611));
      expect(c.text, const Color(0xFFF4EDE0));
      expect(c.accent, const Color(0xFFC8933A));
      expect(c.accentText, const Color(0xFFC8933A));
      expect(c.onAccent, const Color(0xFF1A1208));
      expect(c.divider.a, closeTo(0.12, 0.005));
    });

    test('light matches the spec; accent text is the darker bronze', () {
      const c = MxColors.light;
      expect(c.bg, const Color(0xFFF7F1E6));
      expect(c.surface, const Color(0xFFFFFFFF));
      expect(c.accent, const Color(0xFFC8933A));
      expect(c.accentText, const Color(0xFF8A5A0C));
      expect(c.accentContainer.a, closeTo(0.25, 0.005));
    });
  });

  group('readable text in every theme', () {
    for (final v in MxThemeVariant.values) {
      final c = MxColors.of(v);
      test('${v.name}: text roles reach 4.5:1 on bg and surface', () {
        for (final (name, fg) in [
          ('text', c.text),
          ('textMuted', c.textMuted),
          ('accentText', c.accentText),
          ('success', c.success),
          ('error', c.error),
        ]) {
          for (final bgc in [c.bg, c.surface]) {
            expect(
              contrast(fg, bgc),
              greaterThanOrEqualTo(4.5),
              reason: '$name on ${bgc.toARGB32().toRadixString(16)}',
            );
          }
        }
        expect(contrast(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('ThemeData', () {
    for (final v in MxThemeVariant.values) {
      test('${v.name} carries tokens, Figtree and the right brightness', () {
        final t = MxTheme.build(v);
        expect(t.extension<MxColors>(), MxColors.of(v));
        expect(t.brightness, v.brightness);
        expect(t.scaffoldBackgroundColor, MxColors.of(v).bg);
        expect(t.colorScheme.primary, MxColors.of(v).accent);
        expect(t.textTheme.bodyMedium!.fontFamily, MxFonts.figtree);
      });
    }

    test('sepia is a light theme distinct from light', () {
      expect(MxThemeVariant.sepia.brightness, Brightness.light);
      expect(MxColors.sepia.bg, isNot(MxColors.light.bg));
    });
  });

  group('type scale (DESIGN_SPEC 2.3)', () {
    test('named styles use App values', () {
      expect(MxText.buttonL.fontSize, 17);
      expect(MxText.buttonL.fontWeight, FontWeight.w800);
      expect(MxText.display.fontSize, 34);
      expect(MxText.display.fontWeight, FontWeight.w900);
      expect(MxText.body.height, 1.45);
    });

    test('tracking is converted from em to logical pixels', () {
      expect(MxText.kicker.letterSpacing, closeTo(12 * 0.12, 1e-9));
      expect(MxText.display.letterSpacing, closeTo(34 * -0.01, 1e-9));
    });

    test('text size hook drives the reader paragraph (16/18/20)', () {
      double sizeFor(MxTextSize s) => MxTheme.build(
        MxThemeVariant.dark,
        textSize: s,
      ).extension<MxReading>()!.paragraph.fontSize!;
      expect(sizeFor(MxTextSize.small), 16);
      expect(sizeFor(MxTextSize.medium), 18);
      expect(sizeFor(MxTextSize.large), 20);
    });
  });

  test('poster radius is max(10, 0.075w)', () {
    expect(MxRadius.poster(112), 10);
    expect(MxRadius.poster(170), closeTo(12.75, 1e-9));
  });
}
